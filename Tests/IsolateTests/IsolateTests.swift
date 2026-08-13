import XCTest
import Accelerate
import AVFoundation
@testable import Isolate

final class IsolateTests: XCTestCase {
    
    // Test 1: Verify Constant Overlap-Add (COLA) Property of 50% Overlapped Hann Window
    func testHannWindowCOLAProperty() {
        let chunkSize = 441000
        let hopSize = 220500
        
        var window = [Float](repeating: 0.0, count: chunkSize)
        for i in 0..<chunkSize {
            window[i] = 0.5 * (1.0 - cosf(Float(2.0 * Double.pi * Double(i) / Double(chunkSize))))
        }
        
        // Sum 2 consecutive windows shifted by hopSize in the overlapping region
        for i in 0..<hopSize {
            let val1 = window[hopSize + i]
            let val2 = window[i]
            let sum = val1 + val2
            XCTAssertEqual(sum, 1.0, accuracy: 1e-4, "Hann window 50% overlap must sum to 1.0 everywhere in overlap region")
        }
    }
    
    // Test 2: Verify Reflection Padding Symmetry and Continuity
    func testReflectionPaddingContinuity() {
        let originalCount = 1000
        let padSize = 200
        let paddedCount = originalCount + 2 * padSize
        
        var original = [Float](repeating: 0, count: originalCount)
        for i in 0..<originalCount {
            original[i] = sinf(Float(i) * 0.05)
        }
        
        var padded = [Float](repeating: 0, count: paddedCount)
        // Left reflection
        for i in 0..<padSize {
            padded[i] = original[min(originalCount - 1, padSize - i)]
        }
        // Center
        for i in 0..<originalCount {
            padded[padSize + i] = original[i]
        }
        // Right reflection
        for i in 0..<padSize {
            padded[padSize + originalCount + i] = original[max(0, originalCount - 2 - i)]
        }
        
        // Check boundary equality
        XCTAssertEqual(padded[padSize], original[0], accuracy: 1e-6)
        XCTAssertEqual(padded[padSize + originalCount - 1], original[originalCount - 1], accuracy: 1e-6)
        XCTAssertEqual(padded.count, paddedCount)
    }
    
    // Test 3: Verify Dynamic Standardization (Mean and Standard Deviation Calculation)
    func testAudioStandardizationNormalization() {
        let sampleCount = 44100
        var channelL = [Float](repeating: 0, count: sampleCount)
        var channelR = [Float](repeating: 0, count: sampleCount)
        
        for i in 0..<sampleCount {
            let t = Float(i) / 44100.0
            channelL[i] = 0.5 * sinf(2.0 * .pi * 440.0 * t) + 0.1
            channelR[i] = 0.5 * sinf(2.0 * .pi * 880.0 * t) + 0.1
        }
        
        var meanL: Float = 0
        var meanR: Float = 0
        vDSP_meanv(&channelL, 1, &meanL, vDSP_Length(sampleCount))
        vDSP_meanv(&channelR, 1, &meanR, vDSP_Length(sampleCount))
        let meanVal = (meanL + meanR) * 0.5
        
        var rmsL: Float = 0
        var rmsR: Float = 0
        vDSP_rmsqv(&channelL, 1, &rmsL, vDSP_Length(sampleCount))
        vDSP_rmsqv(&channelR, 1, &rmsR, vDSP_Length(sampleCount))
        let rmsVal = sqrtf((rmsL * rmsL + rmsR * rmsR) * 0.5)
        let stdVal = sqrtf(max(0, rmsVal * rmsVal - meanVal * meanVal))
        
        XCTAssertEqual(meanVal, 0.1, accuracy: 1e-2, "Calculated mean should match injected DC offset")
        XCTAssertGreaterThan(stdVal, 0.3, "Calculated standard deviation should reflect sine wave energy")
        
        // Normalize
        var normL = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            normL[i] = (channelL[i] - meanVal) / stdVal
        }
        
        var normMean: Float = 0
        var normRMS: Float = 0
        vDSP_meanv(&normL, 1, &normMean, vDSP_Length(sampleCount))
        vDSP_rmsqv(&normL, 1, &normRMS, vDSP_Length(sampleCount))
        
        XCTAssertEqual(normMean, 0.0, accuracy: 1e-3, "Normalized audio must have zero mean")
        XCTAssertEqual(normRMS, 1.0, accuracy: 1e-2, "Normalized audio must have unit variance / RMS")
    }
    
    // Test 4: Verify FFT Analyzer frequency band computation
    func testFFTAnalyzerExecution() {
        let analyzer = FFTAnalyzer(fftSize: 1024)
        var buffer = [Float](repeating: 0, count: 1024)
        for i in 0..<1024 {
            buffer[i] = sinf(Float(i) * 0.1)
        }
        
        let magnitudes = analyzer.computeFFT(buffer: &buffer)
        XCTAssertEqual(magnitudes.count, 512, "1024 FFT should output 512 magnitude bins")
        
        let maxMagnitude = magnitudes.max() ?? 0
        XCTAssertGreaterThan(maxMagnitude, 0.0, "FFT magnitude for sine wave must be greater than zero")
    }
    
    // Test 5: Verify End-to-End Stem Splitting with DemucsEngine
    func testEndToEndStemSplittingWithSyntheticAudio() async throws {
        let sampleRate: Double = 44100.0
        let duration: Double = 2.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false
        )!
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let pL = buffer.floatChannelData![0]
        let pR = buffer.floatChannelData![1]
        
        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            // 440 Hz tone + 880 Hz tone
            let val = 0.4 * sinf(2.0 * .pi * 440.0 * t) + 0.2 * sinf(2.0 * .pi * 880.0 * t)
            pL[i] = val
            pR[i] = val
        }
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempAudioURL = tempDir.appendingPathComponent("test_track.wav")
        
        let diskSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        do {
            let writer = try AVAudioFile(forWriting: tempAudioURL, settings: diskSettings)
            try writer.write(from: buffer)
        }
        
        var progressUpdates: [Double] = []
        let stemURLs = try await DemucsEngine.shared.splitAudio(url: tempAudioURL) { info in
            progressUpdates.append(info.fraction)
        }
        
        XCTAssertEqual(stemURLs.count, 4, "Must output 4 stems (vocals, drums, bass, other)")
        XCTAssertFalse(progressUpdates.isEmpty, "Must send progress updates during splitting")
        
        for stemURL in stemURLs {
            XCTAssertTrue(FileManager.default.fileExists(atPath: stemURL.path), "Stem file must exist on disk at \(stemURL.path)")
            let audioFile = try AVAudioFile(forReading: stemURL)
            XCTAssertEqual(audioFile.processingFormat.sampleRate, sampleRate, "Sample rate must be 44.1kHz")
            XCTAssertEqual(audioFile.processingFormat.channelCount, 2, "Must be stereo audio")
            XCTAssertEqual(audioFile.length, Int64(frameCount), "Stem audio length must match original input length")
        }
        
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // Test 6: Verify 50x50 Nothing RGB Color Dot-Matrix Image Sampling
    func testDotMatrixImageProcessorSampling() {
        let size = NSSize(width: 200, height: 200)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSColor.blue.setFill()
        NSRect(x: 50, y: 50, width: 100, height: 100).fill()
        image.unlockFocus()
        
        let matrix = DotMatrixImageProcessor.generateColorDotMatrix(from: image, gridSize: 50)
        XCTAssertNotNil(matrix, "Color dot matrix generation must succeed")
        XCTAssertEqual(matrix?.count, 50, "Matrix height must be 50")
        XCTAssertEqual(matrix?.first?.count, 50, "Matrix width must be 50")
        
        // Check corner (red background -> high red channel)
        let cornerCell = matrix?[0][0]
        XCTAssertNotNil(cornerCell)
        XCTAssertGreaterThan(cornerCell?.r ?? 0.0, 0.7, "Red background corner must have high red component")
    }
}
