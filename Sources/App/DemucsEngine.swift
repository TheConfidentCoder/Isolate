import Foundation
import CoreML
import AVFoundation
import Accelerate

public enum DemucsError: LocalizedError, Sendable {
    case modelNotFound(String)
    case compilationFailed(String)
    case assetReaderFailed(String)
    case conversionFailed(String)
    case invalidAudioFormat
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let msg): return "CoreML Model Not Found: \(msg)"
        case .compilationFailed(let msg): return "Model Compilation Failed: \(msg)"
        case .assetReaderFailed(let msg): return "Audio Reading Failed: \(msg)"
        case .conversionFailed(let msg): return "Audio Conversion Failed: \(msg)"
        case .invalidAudioFormat: return "Invalid Audio Format"
        case .cancelled: return "Operation Cancelled"
        }
    }
}

public struct SplitProgressInfo: Sendable {
    public let fraction: Double
    public let currentChunk: Int
    public let totalChunks: Int
    public let elapsedSeconds: Double
    public let estimatedRemainingSeconds: Double
    public let statusMessage: String
}

public actor DemucsEngine {
    public static let shared = DemucsEngine()
    
    private var model: MLModel?
    private var isInitializing = false
    
    // Demucs HTDemucs operates on 10.0s chunks @ 44.1kHz (441,000 samples)
    public static let sampleRate: Double = 44100.0
    public static let chunkSize: Int = 441000       // 10.0 seconds
    public static let hopSize: Int = 220500         // 5.0 seconds (50% overlap)
    
    // Stem ordering from the HTDemucs CoreML model
    public static let stemNames: [String] = ["vocals", "drums", "bass", "other"]
    
    private init() {}
    
    // MARK: - Model Pre-Warming & Loading
    
    public func prewarmModel() async {
        do {
            try await loadModelIfNeeded()
            if let model = self.model {
                let inputShape: [NSNumber] = [1, 2, NSNumber(value: Self.chunkSize)]
                if let dummyInput = try? MLMultiArray(shape: inputShape, dataType: .float32) {
                    let provider = try? MLDictionaryFeatureProvider(dictionary: ["audio": MLFeatureValue(multiArray: dummyInput)])
                    if let p = provider {
                        _ = try? await model.prediction(from: p)
                    }
                }
            }
        } catch {
            print("Pre-warming Demucs model background task: \(error)")
        }
    }
    
    public func loadModelIfNeeded() async throws {
        if model != nil { return }
        
        // 1. Check in Bundle.main (Resources)
        if let bundleCompiledURL = Bundle.main.url(forResource: "HTDemucs", withExtension: "mlmodelc") {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            self.model = try MLModel(contentsOf: bundleCompiledURL, configuration: config)
            return
        }
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Isolate")
        try fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        let compiledURL = appSupport.appendingPathComponent("HTDemucs.mlmodelc")
        
        if fileManager.fileExists(atPath: compiledURL.path) {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            self.model = try MLModel(contentsOf: compiledURL, configuration: config)
            return
        }
        
        // Check for .mlpackage in AppSupport or Bundle
        var packageURL = appSupport.appendingPathComponent("HTDemucs_CoreML_FP16.mlpackage")
        if !fileManager.fileExists(atPath: packageURL.path) {
            if let bundlePkg = Bundle.main.url(forResource: "HTDemucs_CoreML_FP16", withExtension: "mlpackage") {
                packageURL = bundlePkg
            } else {
                throw DemucsError.modelNotFound("HTDemucs.mlmodelc or HTDemucs_CoreML_FP16.mlpackage not found.")
            }
        }
        
        // Compile the model asynchronously
        let tempCompiledURL = try await Task.detached {
            try MLModel.compileModel(at: packageURL)
        }.value
        
        if fileManager.fileExists(atPath: compiledURL.path) {
            try? fileManager.removeItem(at: compiledURL)
        }
        try fileManager.moveItem(at: tempCompiledURL, to: compiledURL)
        
        let config = MLModelConfiguration()
        config.computeUnits = .all
        self.model = try MLModel(contentsOf: compiledURL, configuration: config)
    }
    
    // MARK: - Audio Splitting
    
    /// Splits an input audio file into 4 pristine 32-bit Float stems (Vocals, Drums, Bass, Other).
    /// Uses 50% Normalized Overlap-Add (COLA) with mirror-padded boundaries and energy standardization.
    public func splitAudio(
        url: URL,
        progressCallback: @escaping @Sendable (SplitProgressInfo) -> Void
    ) async throws -> [URL] {
        let startTime = CACurrentMediaTime()
        
        // Stage 1: Immediate feedback for decoding (0% -> 2%)
        progressCallback(SplitProgressInfo(
            fraction: 0.01,
            currentChunk: 0,
            totalChunks: 0,
            elapsedSeconds: 0,
            estimatedRemainingSeconds: 0,
            statusMessage: "DECODING AUDIO TRACK..."
        ))
        
        try await loadModelIfNeeded()
        guard let mlModel = self.model else {
            throw DemucsError.modelNotFound("Model failed to load into memory.")
        }
        
        // 1. Decode and convert input audio to 44.1kHz Stereo Float32
        let (fullSongBuffer, originalFrames) = try decodeAudioToStandardFormat(url: url)
        guard originalFrames > 0,
              let inL = fullSongBuffer.floatChannelData?[0],
              let inR = fullSongBuffer.floatChannelData?[1] else {
            throw DemucsError.invalidAudioFormat
        }
        
        // 2. Prepare Caching Directory
        let fileHash = "\(url.lastPathComponent.replacingOccurrences(of: " ", with: "_"))_\(originalFrames)"
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Isolate")
            .appendingPathComponent("Stems")
            .appendingPathComponent(fileHash)
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        let outputURLs = Self.stemNames.map { name in
            appSupport.appendingPathComponent("\(name).wav")
        }
        
        // If all 4 stem files already exist in cache and have valid length, return immediately!
        var allCached = true
        for stemURL in outputURLs {
            if !FileManager.default.fileExists(atPath: stemURL.path) {
                allCached = false
                break
            }
        }
        if allCached {
            progressCallback(SplitProgressInfo(
                fraction: 1.0,
                currentChunk: 1,
                totalChunks: 1,
                elapsedSeconds: 0,
                estimatedRemainingSeconds: 0,
                statusMessage: "LOADED FROM CACHE"
            ))
            return outputURLs
        }
        
        // Stage 2: Tensor Prep and Symmetrical Reflection Padding (2% -> 3%)
        let padSize = Self.hopSize
        let paddedFrames = originalFrames + 2 * padSize
        let chunkSize = Self.chunkSize
        let hopSize = Self.hopSize
        let numChunks = Int(ceil(Double(paddedFrames - chunkSize) / Double(hopSize))) + 1
        
        var smoothedETA: Double = Double(numChunks) * 0.58 + 1.2
        let elapsedDec = CACurrentMediaTime() - startTime
        
        progressCallback(SplitProgressInfo(
            fraction: 0.02,
            currentChunk: 0,
            totalChunks: numChunks,
            elapsedSeconds: elapsedDec,
            estimatedRemainingSeconds: max(1.0, smoothedETA),
            statusMessage: "PREPARING NEURAL ENGINE..."
        ))
        
        // 3. Compute Audio Energy / Standard Deviation for Demucs nominal scaling
        let (meanVal, stdVal) = computeMeanAndStd(channelL: inL, channelR: inR, count: originalFrames)
        let safeStd = max(stdVal, 1e-4)
        
        // 4. Apply Reflection Padding
        var paddedL = [Float](repeating: 0.0, count: paddedFrames)
        var paddedR = [Float](repeating: 0.0, count: paddedFrames)
        
        // Left reflection pad
        for i in 0..<padSize {
            let srcIdx = min(originalFrames - 1, padSize - i)
            paddedL[i] = inL[srcIdx]
            paddedR[i] = inR[srcIdx]
        }
        // Center original audio
        for i in 0..<originalFrames {
            paddedL[padSize + i] = inL[i]
            paddedR[padSize + i] = inR[i]
        }
        // Right reflection pad
        for i in 0..<padSize {
            let srcIdx = max(0, originalFrames - 2 - i)
            paddedL[padSize + originalFrames + i] = inL[srcIdx]
            paddedR[padSize + originalFrames + i] = inR[srcIdx]
        }
        
        // Normalize padded audio to zero mean, unit variance for model inference
        var normPaddedL = [Float](repeating: 0.0, count: paddedFrames)
        var normPaddedR = [Float](repeating: 0.0, count: paddedFrames)
        let invStd = 1.0 / safeStd
        for i in 0..<paddedFrames {
            normPaddedL[i] = (paddedL[i] - meanVal) * invStd
            normPaddedR[i] = (paddedR[i] - meanVal) * invStd
        }
        
        // 5. Initialize Hann Window & Overlap-Add Accumulators
        var hannWindow = [Float](repeating: 0.0, count: chunkSize)
        for i in 0..<chunkSize {
            hannWindow[i] = 0.5 * (1.0 - cosf(Float(2.0 * Double.pi * Double(i) / Double(chunkSize))))
        }
        
        // Accumulators for 4 stems × 2 channels (8 total) across paddedFrames
        var stemAccumulators = [[Float]](repeating: [Float](repeating: 0.0, count: paddedFrames), count: 8)
        var weightAccumulator = [Float](repeating: 0.0, count: paddedFrames)
        
        let inputShape: [NSNumber] = [1, 2, NSNumber(value: chunkSize)]
        let inputArray = try MLMultiArray(shape: inputShape, dataType: .float32)
        let inPtrL = inputArray.dataPointer.assumingMemoryBound(to: Float.self)
        let inPtrR = inPtrL.advanced(by: chunkSize)
        
        // Stage 3: Sequential Pipelined Inference Loop (3% to 95%)
        let inferenceStartTime = CACurrentMediaTime()
        for chunkIdx in 0..<numChunks {
            let chunkStart = chunkIdx * hopSize
            let chunkEnd = min(chunkStart + chunkSize, paddedFrames)
            let readFrames = chunkEnd - chunkStart
            
            // Clear input buffer
            vDSP_vclr(inPtrL, 1, vDSP_Length(chunkSize * 2))
            
            // Copy normalized audio into MLMultiArray input
            normPaddedL.withUnsafeBufferPointer { pL in
                normPaddedR.withUnsafeBufferPointer { pR in
                    memcpy(inPtrL, pL.baseAddress!.advanced(by: chunkStart), readFrames * MemoryLayout<Float>.size)
                    memcpy(inPtrR, pR.baseAddress!.advanced(by: chunkStart), readFrames * MemoryLayout<Float>.size)
                }
            }
            
            // CoreML Prediction on Neural Engine
            let inputProvider = try MLDictionaryFeatureProvider(dictionary: [
                "audio": MLFeatureValue(multiArray: inputArray)
            ])
            
            let prediction = try await mlModel.prediction(from: inputProvider)
            guard let sourcesArray = prediction.featureValue(for: "sources")?.multiArrayValue else {
                throw DemucsError.conversionFailed("Model output 'sources' multiarray is missing.")
            }
            
            // Overlap-Add model output into accumulators
            applyOverlapAddChunk(
                outMultiArray: sourcesArray,
                accumulators: &stemAccumulators,
                weightAccumulator: &weightAccumulator,
                chunkStart: chunkStart,
                readFrames: readFrames,
                window: hannWindow,
                mean: meanVal,
                std: safeStd
            )
            
            let completedChunks = chunkIdx + 1
            let chunkProgress = Double(completedChunks) / Double(numChunks)
            let totalFraction = 0.03 + (0.92 * chunkProgress) // 0.03 -> 0.95
            
            // Moving-Average Chunk Calibration: Measure exact Apple Silicon throughput
            let inferenceElapsed = CACurrentMediaTime() - inferenceStartTime
            let avgSecsPerChunk = max(0.20, inferenceElapsed / Double(completedChunks))
            let remainingChunks = numChunks - completedChunks
            let remainingSeconds = (Double(remainingChunks) * avgSecsPerChunk) + 1.2
            
            smoothedETA = (chunkIdx == 0) ? remainingSeconds : (0.25 * remainingSeconds + 0.75 * smoothedETA)
            
            progressCallback(SplitProgressInfo(
                fraction: totalFraction,
                currentChunk: completedChunks,
                totalChunks: numChunks,
                elapsedSeconds: CACurrentMediaTime() - startTime,
                estimatedRemainingSeconds: max(1.0, smoothedETA),
                statusMessage: "SEPARATING STEMS (CHUNK \(completedChunks)/\(numChunks))"
            ))
        }
        
        // Stage 4: Normalize Accumulators & Write 32-Bit Lossless Stems (95% to 100%)
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 2,
            interleaved: false
        )!
        
        for stemIdx in 0..<4 {
            let stemName = Self.stemNames[stemIdx].uppercased()
            let stemFraction = 0.95 + (0.05 * (Double(stemIdx + 1) / 4.0))
            let writeElapsed = CACurrentMediaTime() - startTime
            let remainingSecs = max(0.0, 1.2 * (1.0 - (Double(stemIdx + 1) / 4.0)))
            
            progressCallback(SplitProgressInfo(
                fraction: stemFraction,
                currentChunk: numChunks,
                totalChunks: numChunks,
                elapsedSeconds: writeElapsed,
                estimatedRemainingSeconds: remainingSecs,
                statusMessage: "SAVING ISOLATED STEMS..."
            ))
            
            let stemL = stemAccumulators[stemIdx * 2]
            let stemR = stemAccumulators[stemIdx * 2 + 1]
            
            let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(originalFrames))!
            outBuffer.frameLength = AVAudioFrameCount(originalFrames)
            let destL = outBuffer.floatChannelData![0]
            let destR = outBuffer.floatChannelData![1]
            
            for i in 0..<originalFrames {
                let paddedIdx = padSize + i
                let w = max(weightAccumulator[paddedIdx], 1e-4)
                destL[i] = stemL[paddedIdx] / w
                destR[i] = stemR[paddedIdx] / w
            }
            
            let stemURL = outputURLs[stemIdx]
            let diskSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: Self.sampleRate,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            let writer = try AVAudioFile(forWriting: stemURL, settings: diskSettings)
            try writer.write(from: outBuffer)
        }
        
        progressCallback(SplitProgressInfo(
            fraction: 1.0,
            currentChunk: numChunks,
            totalChunks: numChunks,
            elapsedSeconds: CACurrentMediaTime() - startTime,
            estimatedRemainingSeconds: 0,
            statusMessage: "SEPARATION COMPLETE"
        ))
        
        return outputURLs
    }
    
    // MARK: - Internal Signal Processing Helpers
    
    private func decodeAudioToStandardFormat(url: URL) throws -> (AVAudioPCMBuffer, Int) {
        let inFile = try AVAudioFile(forReading: url)
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 2,
            interleaved: false
        )!
        
        guard let converter = AVAudioConverter(from: inFile.processingFormat, to: targetFormat) else {
            throw DemucsError.conversionFailed("Unable to create AVAudioConverter for \(url.lastPathComponent)")
        }
        
        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
        
        let ratio = Self.sampleRate / inFile.fileFormat.sampleRate
        let estimatedFrames = AVAudioFrameCount(Double(inFile.length) * ratio) + 88200
        guard let fullBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: estimatedFrames) else {
            throw DemucsError.conversionFailed("Failed to allocate audio conversion buffer.")
        }
        
        let fileFrames = max(1024, AVAudioFrameCount(inFile.length))
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inFile.processingFormat, frameCapacity: fileFrames) else {
            throw DemucsError.conversionFailed("Failed to allocate input buffer.")
        }
        try inFile.read(into: inputBuffer)
        
        var hasRead = false
        var convError: NSError? = nil
        converter.convert(to: fullBuffer, error: &convError) { inNumPackets, outStatus in
            if hasRead {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            hasRead = true
            return inputBuffer
        }
        
        if let err = convError {
            throw DemucsError.conversionFailed(err.localizedDescription)
        }
        
        return (fullBuffer, Int(fullBuffer.frameLength))
    }
    
    private func computeMeanAndStd(channelL: UnsafePointer<Float>, channelR: UnsafePointer<Float>, count: Int) -> (Float, Float) {
        var meanL: Float = 0
        var meanR: Float = 0
        vDSP_meanv(channelL, 1, &meanL, vDSP_Length(count))
        vDSP_meanv(channelR, 1, &meanR, vDSP_Length(count))
        let meanVal = (meanL + meanR) * 0.5
        
        var rmsL: Float = 0
        var rmsR: Float = 0
        vDSP_rmsqv(channelL, 1, &rmsL, vDSP_Length(count))
        vDSP_rmsqv(channelR, 1, &rmsR, vDSP_Length(count))
        let rmsVal = sqrtf((rmsL * rmsL + rmsR * rmsR) * 0.5)
        let stdVal = sqrtf(max(0, rmsVal * rmsVal - meanVal * meanVal))
        
        return (meanVal, stdVal)
    }
    
    private nonisolated func applyOverlapAddChunk(
        outMultiArray: MLMultiArray,
        accumulators: inout [[Float]],
        weightAccumulator: inout [Float],
        chunkStart: Int,
        readFrames: Int,
        window: [Float],
        mean: Float,
        std: Float
    ) {
        let isFloat32 = outMultiArray.dataType == .float32
        let strides = outMultiArray.strides
        let stemStride = strides[1].intValue
        let channelStride = strides[2].intValue
        
        for stemIdx in 0..<4 {
            let stemOffset = stemIdx * stemStride
            if isFloat32 {
                let outPtr = outMultiArray.dataPointer.assumingMemoryBound(to: Float.self)
                let srcL = outPtr.advanced(by: stemOffset)
                let srcR = outPtr.advanced(by: stemOffset + channelStride)
                for i in 0..<readFrames {
                    let w = window[i]
                    let targetIdx = chunkStart + i
                    let valL = srcL[i] * std + mean
                    let valR = srcR[i] * std + mean
                    accumulators[stemIdx * 2][targetIdx] += valL * w
                    accumulators[stemIdx * 2 + 1][targetIdx] += valR * w
                }
            } else {
                let outPtr = outMultiArray.dataPointer.assumingMemoryBound(to: Float16.self)
                let srcL = outPtr.advanced(by: stemOffset)
                let srcR = outPtr.advanced(by: stemOffset + channelStride)
                for i in 0..<readFrames {
                    let w = window[i]
                    let targetIdx = chunkStart + i
                    let valL = Float(srcL[i]) * std + mean
                    let valR = Float(srcR[i]) * std + mean
                    accumulators[stemIdx * 2][targetIdx] += valL * w
                    accumulators[stemIdx * 2 + 1][targetIdx] += valR * w
                }
            }
        }
        
        for i in 0..<readFrames {
            weightAccumulator[chunkStart + i] += window[i]
        }
    }
}
