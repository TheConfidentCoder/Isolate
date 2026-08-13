@preconcurrency import AVFoundation
import Observation
import SwiftUI
import SwiftData
import Accelerate
import AppKit

struct TrackData: Sendable {
    let id: String
    let title: String
    let originalURL: URL
    let vocalStemURL: URL
    let bassStemURL: URL
    let drumStemURL: URL
    let otherStemURL: URL
}

@Observable
final class AudioEngineManager: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let vocalPlayer = AVAudioPlayerNode()
    private let bassPlayer = AVAudioPlayerNode()
    private let drumPlayer = AVAudioPlayerNode()
    private let otherPlayer = AVAudioPlayerNode()
    private let originalPlayer = AVAudioPlayerNode()
    
    private let vocalMixer = AVAudioMixerNode()
    private let bassMixer = AVAudioMixerNode()
    private let drumMixer = AVAudioMixerNode()
    private let otherMixer = AVAudioMixerNode()
    
    var isPlaying = false
    var currentTrackName: String = "NO TRACK LOADED"
    var albumArt: NSImage?
    var playbackProgress: Double = 0.0
    var seekFrameOffset: AVAudioFramePosition = 0
    var currentTimeString: String = "00:00 / -00:00"
    var isBypassed: Bool = false { didSet { applyVolumes() } }
    
    private var playbackSessionID = UUID()
    
    // Performance throttling
    private var lastEQUIUpdateTime: TimeInterval = 0
    private var lastMasterUIUpdateTime: TimeInterval = 0
    private var lastVocalUIUpdateTime: TimeInterval = 0
    
    var isExporting: Bool = false
    var exportProgress: Double = 0.0
    
    var eqMagnitudes: [Float] = Array(repeating: 0, count: 32)
    private let fftAnalyzer = FFTAnalyzer()
    
    var vocalVolume: Double = 0.8 { didSet { applyVolumes() } }
    var bassVolume: Double = 0.8 { didSet { applyVolumes() } }
    var drumVolume: Double = 0.8 { didSet { applyVolumes() } }
    var otherVolume: Double = 0.8 { didSet { applyVolumes() } }
    
    var vocalMuted = false { didSet { applyVolumes() } }
    var bassMuted = false { didSet { applyVolumes() } }
    var drumMuted = false { didSet { applyVolumes() } }
    var otherMuted = false { didSet { applyVolumes() } }
    
    var vocalSolo = false { didSet { applyVolumes() } }
    var bassSolo = false { didSet { applyVolumes() } }
    var drumSolo = false { didSet { applyVolumes() } }
    var otherSolo = false { didSet { applyVolumes() } }
    
    private func applyVolumes() {
        if isBypassed {
            vocalMixer.outputVolume = 0
            bassMixer.outputVolume = 0
            drumMixer.outputVolume = 0
            otherMixer.outputVolume = 0
            originalPlayer.volume = 1.0
            return
        }
        
        originalPlayer.volume = 0.0
        
        let anySolo = vocalSolo || bassSolo || drumSolo || otherSolo
        
        let applyChannel = { (vol: Double, muted: Bool, soloed: Bool, mixer: AVAudioMixerNode) in
            if anySolo {
                mixer.outputVolume = soloed ? Float(vol) : 0.0
            } else {
                mixer.outputVolume = muted ? 0.0 : Float(vol)
            }
        }
        
        applyChannel(vocalVolume, vocalMuted, vocalSolo, vocalMixer)
        applyChannel(bassVolume, bassMuted, bassSolo, bassMixer)
        applyChannel(drumVolume, drumMuted, drumSolo, drumMixer)
        applyChannel(otherVolume, otherMuted, otherSolo, otherMixer)
    }
    
    var waveformAmplitudes: [Float] = Array(repeating: 0.05, count: 30)
    var originalWaveformAmplitudes: [Float] = Array(repeating: 0.05, count: 30)
    var isBypassEnabled = false
    
    private var audioFile: AVAudioFile?
    private var fileVocals: AVAudioFile?
    private var fileBass: AVAudioFile?
    private var fileDrums: AVAudioFile?
    private var fileOther: AVAudioFile?
    private var timer: Timer?
    var isSplitting = false
    var isCompilingModel = false
    var splitProgress = 0.0
    
    init() {
        setupEngine()
    }
    
    private func setupEngine() {
        engine.attach(vocalPlayer)
        engine.attach(bassPlayer)
        engine.attach(drumPlayer)
        engine.attach(otherPlayer)
        engine.attach(originalPlayer)
        
        engine.attach(vocalMixer)
        engine.attach(bassMixer)
        engine.attach(drumMixer)
        engine.attach(otherMixer)
        
        let mixer = engine.mainMixerNode
        engine.connect(vocalPlayer, to: vocalMixer, format: nil)
        engine.connect(bassPlayer, to: bassMixer, format: nil)
        engine.connect(drumPlayer, to: drumMixer, format: nil)
        engine.connect(otherPlayer, to: otherMixer, format: nil)
        engine.connect(originalPlayer, to: mixer, format: nil)
        
        engine.connect(vocalMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(bassMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(drumMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(otherMixer, to: engine.mainMixerNode, format: nil)
        
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self else { return }
            guard let channelData = buffer.floatChannelData?[0] else { return }
            
            // FFT calculation for EQ
            let magnitudes = self.fftAnalyzer.computeFFT(buffer: channelData)
            var bands = [Float](repeating: 0, count: 32)
            let binsPerBand = magnitudes.count / 32
            for i in 0..<32 {
                var sum: Float = 0
                for j in 0..<binsPerBand {
                    let idx = i * binsPerBand + j
                    if idx < magnitudes.count {
                        sum += magnitudes[idx]
                    }
                }
                bands[i] = sum / Float(binsPerBand)
            }
            
            let now = CACurrentMediaTime()
            if now - self.lastEQUIUpdateTime > 0.05 {
                self.lastEQUIUpdateTime = now
                DispatchQueue.main.async {
                    self.eqMagnitudes = bands
                }
            }
            
            // Waveform processing
            if self.isPlaying {
                self.processWaveform(buffer: buffer, isMaster: true)
            }
        }
        
        vocalPlayer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self, self.isPlaying else { return }
            self.processWaveform(buffer: buffer, isMaster: false)
        }
        
        applyVolumes()
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func processWaveform(buffer: AVAudioPCMBuffer, isMaster: Bool) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        let numBlocks = 30
        let blockSize = frameLength / numBlocks
        
        var newAmplitudes = [Float](repeating: 0, count: numBlocks)
        
        if blockSize > 0 {
            for i in 0..<numBlocks {
                let start = i * blockSize
                var rms: Float = 0.0
                vDSP_rmsqv(channelData.advanced(by: start), 1, &rms, vDSP_Length(blockSize))
                
                if rms.isNaN || rms.isInfinite {
                    rms = 0.0
                }
                
                newAmplitudes[i] = rms * 5.0
            }
        }
        
        let now = CACurrentMediaTime()
        if isMaster {
            if now - self.lastMasterUIUpdateTime > 0.05 {
                self.lastMasterUIUpdateTime = now
                DispatchQueue.main.async {
                    self.waveformAmplitudes = newAmplitudes.map { min(max($0, 0.05), 1.0) }
                }
            }
        } else {
            if now - self.lastVocalUIUpdateTime > 0.05 {
                self.lastVocalUIUpdateTime = now
                DispatchQueue.main.async {
                    self.originalWaveformAmplitudes = newAmplitudes.map { min(max($0, 0.05), 1.0) }
                }
            }
        }
    }
    
    private func clearWaveform() {
        DispatchQueue.main.async {
            self.waveformAmplitudes = Array(repeating: 0.05, count: 30)
            self.originalWaveformAmplitudes = Array(repeating: 0.05, count: 30)
        }
    }
    
    @MainActor
    func loadTrack(_ track: TrackModel) async {
        currentTrackName = track.title.uppercased()
        if isPlaying { togglePlayback() }
        
        extractMetadata(url: track.originalURL)
        
        do {
            let fDrums = try AVAudioFile(forReading: track.drumStemURL)
            let fBass = try AVAudioFile(forReading: track.bassStemURL)
            let fOther = try AVAudioFile(forReading: track.otherStemURL)
            let fVocals = try AVAudioFile(forReading: track.vocalStemURL)
            
            self.fileDrums = fDrums
            self.fileBass = fBass
            self.fileOther = fOther
            self.fileVocals = fVocals
            self.audioFile = try? AVAudioFile(forReading: track.originalURL)
            
            scheduleAllPlayers(at: nil)
            
            playSynced()
        } catch {
            print("Failed to load cached stems: \(error)")
        }
    }
    
    func loadAndSplitAudio(url: URL) async -> TrackData? {
        await MainActor.run {
            currentTrackName = url.lastPathComponent.uppercased()
            isSplitting = true
            isCompilingModel = true
            splitProgress = 0.0
            if isPlaying { togglePlayback() }
        }
        
        extractMetadata(url: url)
        
        do {
            let stemURLs = try await DemucsEngine.shared.splitAudio(url: url) { progress in
                Task { @MainActor in 
                    if self.isCompilingModel && progress > 0 {
                        self.isCompilingModel = false
                    }
                    self.splitProgress = progress 
                }
            }
            
            let fVocals = try AVAudioFile(forReading: stemURLs[0])
            let fDrums = try AVAudioFile(forReading: stemURLs[1])
            let fBass = try AVAudioFile(forReading: stemURLs[2])
            let fOther = try AVAudioFile(forReading: stemURLs[3])
            
            self.fileDrums = fDrums
            self.fileBass = fBass
            self.fileOther = fOther
            self.fileVocals = fVocals
            self.audioFile = try? AVAudioFile(forReading: url)
            
            scheduleAllPlayers(at: nil)
            
            let data = TrackData(
                id: url.path,
                title: url.lastPathComponent.replacingOccurrences(of: ".\(url.pathExtension)", with: ""),
                originalURL: url,
                vocalStemURL: stemURLs[0],
                bassStemURL: stemURLs[2],
                drumStemURL: stemURLs[1],
                otherStemURL: stemURLs[3]
            )
            
            await MainActor.run { 
                isSplitting = false 
            }
            playSynced()
            return data
        } catch {
            print("Failed to load or split audio: \(error)")
            await MainActor.run { isSplitting = false }
            return nil
        }
    }
    
    private func extractMetadata(url: URL) {
        let asset = AVAsset(url: url)
        Task {
            do {
                let metadata = try await asset.load(.commonMetadata)
                if let artworkItem = metadata.first(where: { $0.commonKey == .commonKeyArtwork }),
                   let data = try await artworkItem.load(.value) as? Data {
                    await MainActor.run { self.albumArt = NSImage(data: data) }
                } else {
                    await MainActor.run { self.albumArt = nil }
                }
            } catch {
                await MainActor.run { self.albumArt = nil }
            }
        }
    }
    
    @MainActor
    func exportStems() {
        guard let fVocals = fileVocals, let fBass = fileBass, let fDrums = fileDrums, let fOther = fileOther else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(currentTrackName)_Stems.zip"
        panel.allowedContentTypes = [UTType.zip]
        
        if panel.runModal() == .OK, let targetURL = panel.url {
            let trackName = currentTrackName
            let vocalsURL = fVocals.url
            let bassURL = fBass.url
            let drumsURL = fDrums.url
            let otherURL = fOther.url
            
            self.isExporting = true
            self.exportProgress = 0.0
            Task.detached {
                let progressTask = Task {
                    var p = 0.0
                    while p < 0.90 && !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        p += 0.05
                        let currentP = p
                        await MainActor.run { self.exportProgress = currentP }
                    }
                }
                
                defer {
                    Task { @MainActor in 
                        self.exportProgress = 1.0
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        self.isExporting = false 
                    }
                    progressTask.cancel()
                }
                
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                let vDest = tempDir.appendingPathComponent("\(trackName)_Vocals.wav")
                let bDest = tempDir.appendingPathComponent("\(trackName)_Bass.wav")
                let dDest = tempDir.appendingPathComponent("\(trackName)_Drums.wav")
                let oDest = tempDir.appendingPathComponent("\(trackName)_Other.wav")
                
                try? FileManager.default.copyItem(at: vocalsURL, to: vDest)
                try? FileManager.default.copyItem(at: bassURL, to: bDest)
                try? FileManager.default.copyItem(at: drumsURL, to: dDest)
                try? FileManager.default.copyItem(at: otherURL, to: oDest)
                
                let zipDest = tempDir.appendingPathComponent("out.zip")
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.currentDirectoryURL = tempDir
                process.arguments = ["-j", zipDest.path, vDest.path, bDest.path, dDest.path, oDest.path]
                try? process.run()
                process.waitUntilExit()
                
                if FileManager.default.fileExists(atPath: zipDest.path) {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try? FileManager.default.removeItem(at: targetURL)
                    }
                    try? FileManager.default.moveItem(at: zipDest, to: targetURL)
                }
                try? FileManager.default.removeItem(at: tempDir)
                progressTask.cancel()
            }
        }
    }
    
    private func scheduleAllPlayers(at time: AVAudioTime?) {
        guard let fVocals = fileVocals, let fBass = fileBass, let fDrums = fileDrums, let fOther = fileOther, let aFile = audioFile else { return }
        vocalPlayer.stop()
        bassPlayer.stop()
        drumPlayer.stop()
        otherPlayer.stop()
        originalPlayer.stop()
        
        seekFrameOffset = 0
        
        Task { @MainActor in
            self.playbackProgress = 0.0
            self.updateTimeString(for: 0.0)
        }
        
        let session = UUID()
        self.playbackSessionID = session
        
        vocalPlayer.scheduleFile(fVocals, at: time) { [weak self] in 
            Task { @MainActor in
                guard self?.playbackSessionID == session else { return }
                self?.onPlaybackEnded()
            }
        }
        bassPlayer.scheduleFile(fBass, at: time, completionHandler: nil)
        drumPlayer.scheduleFile(fDrums, at: time, completionHandler: nil)
        otherPlayer.scheduleFile(fOther, at: time, completionHandler: nil)
        originalPlayer.scheduleFile(aFile, at: time, completionHandler: nil)
    }
    
    private func onPlaybackEnded() {
        Task { @MainActor in
            scheduleAllPlayers(at: nil)
            if isPlaying {
                playSynced()
            }
        }
    }
    
    private func playSynced() {
        if !engine.isRunning {
            try? engine.start()
        }
        let nodeTime = vocalPlayer.lastRenderTime ?? AVAudioTime(hostTime: mach_absolute_time())
        let startTime = AVAudioTime(hostTime: nodeTime.hostTime + AVAudioTime.hostTime(forSeconds: 0.1))
        
        vocalPlayer.play(at: startTime)
        bassPlayer.play(at: startTime)
        drumPlayer.play(at: startTime)
        otherPlayer.play(at: startTime)
        originalPlayer.play(at: startTime)
        
        Task { @MainActor in
            isPlaying = true
            startTimer()
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            vocalPlayer.pause()
            bassPlayer.pause()
            drumPlayer.pause()
            otherPlayer.pause()
            originalPlayer.pause()
            timer?.invalidate()
            isPlaying = false
            clearWaveform()
        } else {
            playSynced()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let file = self.audioFile, let lastTime = self.vocalPlayer.lastRenderTime, let playerTime = self.vocalPlayer.playerTime(forNodeTime: lastTime) else { return }
            
            let elapsedFrames = Double(playerTime.sampleTime) + Double(self.seekFrameOffset)
            let elapsed = elapsedFrames / playerTime.sampleRate
            let duration = Double(file.length) / file.processingFormat.sampleRate
            
            Task { @MainActor in
                self.playbackProgress = max(0, min(1, elapsed / duration))
                self.updateTimeString(for: self.playbackProgress)
            }
        }
    }
    
    @MainActor
    func updateTimeString(for progress: Double) {
        guard let file = audioFile else { return }
        let duration = Double(file.length) / file.processingFormat.sampleRate
        let elapsed = duration * progress
        
        let mins = Int(elapsed) / 60
        let secs = Int(elapsed) % 60
        
        let rem = max(0, duration - elapsed)
        let rMins = Int(rem) / 60
        let rSecs = Int(rem) % 60
        currentTimeString = String(format: "%02d:%02d / -%02d:%02d", mins, secs, rMins, rSecs)
    }
    
    @MainActor
    func seek(toPercentage percentage: Double) {
        guard let fVocals = fileVocals, let fBass = fileBass, let fDrums = fileDrums, let fOther = fileOther, let aFile = audioFile else { return }
        
        let wasPlaying = isPlaying
        
        vocalPlayer.stop()
        bassPlayer.stop()
        drumPlayer.stop()
        otherPlayer.stop()
        originalPlayer.stop()
        
        let totalFrames = aFile.length
        let targetFrame = AVAudioFramePosition(Double(totalFrames) * percentage)
        let framesToPlay = AVAudioFrameCount(max(0, totalFrames - targetFrame))
        
        self.seekFrameOffset = targetFrame
        
        let session = UUID()
        self.playbackSessionID = session
        
        vocalPlayer.scheduleSegment(fVocals, startingFrame: targetFrame, frameCount: framesToPlay, at: nil) { [weak self] in 
            Task { @MainActor in
                guard self?.playbackSessionID == session else { return }
                self?.onPlaybackEnded()
            }
        }
        bassPlayer.scheduleSegment(fBass, startingFrame: targetFrame, frameCount: framesToPlay, at: nil, completionHandler: nil)
        drumPlayer.scheduleSegment(fDrums, startingFrame: targetFrame, frameCount: framesToPlay, at: nil, completionHandler: nil)
        otherPlayer.scheduleSegment(fOther, startingFrame: targetFrame, frameCount: framesToPlay, at: nil, completionHandler: nil)
        originalPlayer.scheduleSegment(aFile, startingFrame: targetFrame, frameCount: framesToPlay, at: nil, completionHandler: nil)
        
        self.playbackProgress = percentage
        self.updateTimeString(for: percentage)
        
        if wasPlaying {
            isPlaying = false
            playSynced()
        }
    }
}

import CoreML
import Accelerate

enum DemucsError: Error {
    case modelNotFound
    case compilationFailed
    case assetReaderFailed
    case conversionFailed
}

actor DemucsEngine {
    static let shared = DemucsEngine()
    
    private var models: [MLModel] = []
    private let concurrencyCount = 3
    private let chunkSize: Int = 441000 // 10 seconds at 44.1kHz
    
    private init() {}
    
    func initializeModel() async throws {
        if models.count == concurrencyCount { return }
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Isolate")
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        let compiledURL = appSupport.appendingPathComponent("HTDemucs.mlmodelc")
        
        if !FileManager.default.fileExists(atPath: compiledURL.path) {
            let sourceURL = appSupport.appendingPathComponent("HTDemucs_CoreML_FP16.mlpackage")
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                throw DemucsError.modelNotFound
            }
            let tempURL = try await Task.detached { try MLModel.compileModel(at: sourceURL) }.value
            try FileManager.default.moveItem(at: tempURL, to: compiledURL)
        }
        
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        let count = concurrencyCount
        models = try await Task.detached {
            var loaded: [MLModel] = []
            for _ in 0..<count {
                loaded.append(try MLModel(contentsOf: compiledURL, configuration: config))
            }
            return loaded
        }.value
    }
    
    func splitAudio(url: URL, progressCallback: @escaping @Sendable (Double) -> Void) async throws -> [URL] {
        try await initializeModel()
        guard models.count == concurrencyCount else { throw DemucsError.modelNotFound }
        
        let inFile = try AVAudioFile(forReading: url)
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)!
        
        guard let converter = AVAudioConverter(from: inFile.processingFormat, to: targetFormat) else {
            throw DemucsError.conversionFailed
        }
        
        let estimatedFrames = AVAudioFrameCount(Double(inFile.length) * (44100.0 / inFile.fileFormat.sampleRate)) + 44100
        let fullSongBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: estimatedFrames)!
        
        let inputBuffer = AVAudioPCMBuffer(pcmFormat: inFile.processingFormat, frameCapacity: AVAudioFrameCount(inFile.length))!
        try inFile.read(into: inputBuffer)
        
        var hasRead = false
        var error: NSError? = nil
        converter.convert(to: fullSongBuffer, error: &error) { inNumPackets, outStatus in
            if hasRead {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            hasRead = true
            return inputBuffer
        }
        
        if let err = error {
            print("Conversion error: \(err)")
            throw DemucsError.conversionFailed
        }
        
        let totalFrames = Int(fullSongBuffer.frameLength)
        guard totalFrames > 0, let inL = fullSongBuffer.floatChannelData?[0], let inR = fullSongBuffer.floatChannelData?[1] else {
            throw DemucsError.conversionFailed
        }
        
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        let stemNames = ["vocals", "drums", "bass", "other"]
        var writers: [AVAudioFile] = []
        var outputURLs: [URL] = []
        
        for i in 0..<4 {
            let stemURL = cacheDir.appendingPathComponent("\(stemNames[i]).wav")
            let writer = try AVAudioFile(forWriting: stemURL, settings: targetFormat.settings)
            writers.append(writer)
            outputURLs.append(stemURL)
        }
        
        let hopSize = chunkSize / 2
        var window = [Float](repeating: 0, count: chunkSize)
        vDSP_hann_window(&window, vDSP_Length(chunkSize), Int32(vDSP_HANN_NORM))
        
        // 8 arrays: [VocalsL, VocalsR, DrumsL, DrumsR, BassL, BassR, OtherL, OtherR]
        var accumulators = [[Float]](repeating: [Float](repeating: 0.0, count: totalFrames), count: 8)
        
        let numChunks = Int(ceil(Double(totalFrames) / Double(hopSize)))
        let localModels = models
        
        try await withThrowingTaskGroup(of: (Int, Int, Int, MLMultiArray).self) { group in
            var activeTasks = 0
            var completedChunks = 0
            
            for chunkIdx in 0..<numChunks {
                let currentFrame = chunkIdx * hopSize
                if currentFrame >= totalFrames { break }
                
                if activeTasks >= concurrencyCount {
                    if let result = try await group.next() {
                        activeTasks -= 1
                        completedChunks += 1
                        let (_, cFrame, rFrames, outArr) = result
                        self.applyOverlapAdd(outMultiArray: outArr, accumulators: &accumulators, currentFrame: cFrame, readFrames: rFrames, window: window)
                        progressCallback(min(1.0, Double(completedChunks) / Double(numChunks)))
                    }
                }
                
                let assignedModel = localModels[chunkIdx % concurrencyCount]
                let remain = totalFrames - currentFrame
                let readFrames = min(chunkSize, remain)
                
                let inShape: [NSNumber] = [1, 2, NSNumber(value: chunkSize)]
                let inputArray = try MLMultiArray(shape: inShape, dataType: .float32)
                
                let ptrL = inputArray.dataPointer.assumingMemoryBound(to: Float.self)
                let ptrR = ptrL.advanced(by: chunkSize)
                
                vDSP_vclr(ptrL, 1, vDSP_Length(chunkSize * 2))
                
                for i in 0..<readFrames {
                    ptrL[i] = inL[currentFrame + i]
                    ptrR[i] = inR[currentFrame + i]
                }
                
                group.addTask(priority: .userInitiated) {
                    let inputProvider = try MLDictionaryFeatureProvider(dictionary: ["audio": MLFeatureValue(multiArray: inputArray)])
                    let prediction = try assignedModel.prediction(from: inputProvider)
                    let resultMultiArray = prediction.featureValue(for: "sources")!.multiArrayValue!
                    return (chunkIdx, currentFrame, readFrames, resultMultiArray)
                }
                
                activeTasks += 1
            }
            
            while let result = try await group.next() {
                completedChunks += 1
                let (_, cFrame, rFrames, outArr) = result
                self.applyOverlapAdd(outMultiArray: outArr, accumulators: &accumulators, currentFrame: cFrame, readFrames: rFrames, window: window)
                progressCallback(min(1.0, Double(completedChunks) / Double(numChunks)))
            }
        }
        
        // Write the fully assembled accumulators to WAV files
        let outChunkBuffers = (0..<4).map { _ in
            AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(totalFrames))!
        }
        
        for stemIdx in 0..<4 {
            let buffer = outChunkBuffers[stemIdx]
            buffer.frameLength = AVAudioFrameCount(totalFrames)
            let destL = buffer.floatChannelData![0]
            let destR = buffer.floatChannelData![1]
            
            let srcL = accumulators[stemIdx * 2]
            let srcR = accumulators[stemIdx * 2 + 1]
            
            destL.update(from: srcL, count: totalFrames)
            destR.update(from: srcR, count: totalFrames)
            
            try writers[stemIdx].write(from: buffer)
        }
        
        return outputURLs
    }
    
    private nonisolated func applyOverlapAdd(outMultiArray: MLMultiArray, accumulators: inout [[Float]], currentFrame: Int, readFrames: Int, window: [Float]) {
        let isFloat32 = outMultiArray.dataType == .float32
        let strides = outMultiArray.strides
        let stemStride = strides[1].intValue
        let channelStride = strides[2].intValue
        
        for stemIdx in 0..<4 {
            let outStemOffset = stemIdx * stemStride
            if isFloat32 {
                let outPtr = outMultiArray.dataPointer.assumingMemoryBound(to: Float.self)
                let srcL = outPtr.advanced(by: outStemOffset)
                let srcR = outPtr.advanced(by: outStemOffset + channelStride)
                for i in 0..<readFrames {
                    let w = window[i]
                    accumulators[stemIdx * 2][currentFrame + i] += srcL[i] * w
                    accumulators[stemIdx * 2 + 1][currentFrame + i] += srcR[i] * w
                }
            } else {
                let outPtr = outMultiArray.dataPointer.assumingMemoryBound(to: Float16.self)
                let srcL = outPtr.advanced(by: outStemOffset)
                let srcR = outPtr.advanced(by: outStemOffset + channelStride)
                for i in 0..<readFrames {
                    let w = window[i]
                    accumulators[stemIdx * 2][currentFrame + i] += Float(srcL[i]) * w
                    accumulators[stemIdx * 2 + 1][currentFrame + i] += Float(srcR[i]) * w
                }
            }
        }
    }
}
