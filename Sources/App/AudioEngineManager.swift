@preconcurrency import AVFoundation
import Observation
import SwiftUI
import SwiftData
import Accelerate
import AppKit
import UniformTypeIdentifiers

public struct TrackData: Sendable {
    public let id: String
    public let title: String
    public let originalURL: URL
    public let vocalStemURL: URL
    public let bassStemURL: URL
    public let drumStemURL: URL
    public let otherStemURL: URL
}

public enum ExportState: Equatable, Sendable {
    case idle
    case exporting(stage: String, percent: Double)
    case completed
}

@Observable
public final class AudioEngineManager: @unchecked Sendable {
    // MARK: - Audio Engine Nodes
    private let engine = AVAudioEngine()
    
    private let vocalPlayer = AVAudioPlayerNode()
    private let drumPlayer = AVAudioPlayerNode()
    private let bassPlayer = AVAudioPlayerNode()
    private let otherPlayer = AVAudioPlayerNode()
    private let originalPlayer = AVAudioPlayerNode()
    
    private let vocalMixer = AVAudioMixerNode()
    private let drumMixer = AVAudioMixerNode()
    private let bassMixer = AVAudioMixerNode()
    private let otherMixer = AVAudioMixerNode()
    private let stemsSumMixer = AVAudioMixerNode()
    
    // MARK: - Playback State
    public var isPlaying = false
    public var currentTrackName: String = "NO TRACK LOADED"
    public var albumArt: NSImage?
    public var playbackProgress: Double = 0.0
    public var seekFrameOffset: AVAudioFramePosition = 0
    public var currentTimeString: String = "00:00 / -00:00"
    public var isBypassed: Bool = false { didSet { applyVolumes() } }
    
    private var playbackSessionID = UUID()
    
    // MARK: - Stem Volumes, Mute, Solo (Default 1.0 = Unity Gain / 0 dB)
    public var vocalVolume: Double = 1.0 { didSet { applyVolumes() } }
    public var drumVolume: Double = 1.0 { didSet { applyVolumes() } }
    public var bassVolume: Double = 1.0 { didSet { applyVolumes() } }
    public var otherVolume: Double = 1.0 { didSet { applyVolumes() } }
    
    public var vocalMuted = false { didSet { applyVolumes() } }
    public var drumMuted = false { didSet { applyVolumes() } }
    public var bassMuted = false { didSet { applyVolumes() } }
    public var otherMuted = false { didSet { applyVolumes() } }
    
    public var vocalSolo = false { didSet { applyVolumes() } }
    public var drumSolo = false { didSet { applyVolumes() } }
    public var bassSolo = false { didSet { applyVolumes() } }
    public var otherSolo = false { didSet { applyVolumes() } }
    
    // MARK: - Live Visualizers (Waveform & Per-Stem EQ)
    public var masterWaveformAmplitudes: [Float] = Array(repeating: 0.05, count: 30)
    public var originalWaveformAmplitudes: [Float] = Array(repeating: 0.05, count: 30)
    
    public var masterEQMagnitudes: [Float] = Array(repeating: 0, count: 32)
    public var vocalEQMagnitudes: [Float] = Array(repeating: 0, count: 16)
    public var drumEQMagnitudes: [Float] = Array(repeating: 0, count: 16)
    public var bassEQMagnitudes: [Float] = Array(repeating: 0, count: 16)
    public var otherEQMagnitudes: [Float] = Array(repeating: 0, count: 16)
    
    private let fftAnalyzer = FFTAnalyzer(fftSize: 1024)
    
    // Throttling timers for smooth 30fps visualizer animations
    private var lastMasterUIUpdateTime: TimeInterval = 0
    private var lastStemUIUpdateTime: TimeInterval = 0
    
    // MARK: - Splitting & Progress State
    public var isSplitting = false
    public var isCompilingModel = false
    public var splitProgress = 0.0
    public var currentChunkNumber = 0
    public var totalChunkCount = 0
    public var etaRemainingString = "00:05"
    public var splitStatusMessage = "ANALYZING STEMS..."
    private var etaTimer: Timer?
    private var targetEtaSeconds: Int = 0
    
    // MARK: - Export State
    public var exportState: ExportState = .idle
    public var isExporting: Bool { exportState != .idle }
    public var exportProgress: Double = 0.0
    
    // MARK: - Audio File Handles
    private var audioFile: AVAudioFile?
    private var fileVocals: AVAudioFile?
    private var fileDrums: AVAudioFile?
    private var fileBass: AVAudioFile?
    private var fileOther: AVAudioFile?
    private var timer: Timer?
    
    // MARK: - Initialization
    public init() {
        setupAudioGraph()
    }
    
    private func setupAudioGraph() {
        engine.attach(vocalPlayer)
        engine.attach(drumPlayer)
        engine.attach(bassPlayer)
        engine.attach(otherPlayer)
        engine.attach(originalPlayer)
        
        engine.attach(vocalMixer)
        engine.attach(drumMixer)
        engine.attach(bassMixer)
        engine.attach(otherMixer)
        engine.attach(stemsSumMixer)
        
        // Connect players to channel mixers
        engine.connect(vocalPlayer, to: vocalMixer, format: nil)
        engine.connect(drumPlayer, to: drumMixer, format: nil)
        engine.connect(bassPlayer, to: bassMixer, format: nil)
        engine.connect(otherPlayer, to: otherMixer, format: nil)
        
        // Connect channel mixers into the stems sum mixer
        engine.connect(vocalMixer, to: stemsSumMixer, format: nil)
        engine.connect(drumMixer, to: stemsSumMixer, format: nil)
        engine.connect(bassMixer, to: stemsSumMixer, format: nil)
        engine.connect(otherMixer, to: stemsSumMixer, format: nil)
        
        // Connect stemsSumMixer and originalPlayer directly to the main mixer
        engine.connect(stemsSumMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(originalPlayer, to: engine.mainMixerNode, format: nil)
        
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        
        // Master Output Tap: Waveform and Master 32-Band FFT
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self, self.isPlaying else { return }
            guard let channelData = buffer.floatChannelData?[0] else { return }
            
            let magnitudes = self.fftAnalyzer.computeFFT(buffer: channelData)
            var bands = [Float](repeating: 0, count: 32)
            let binsPerBand = max(1, magnitudes.count / 32)
            for i in 0..<32 {
                var sum: Float = 0
                for j in 0..<binsPerBand {
                    let idx = i * binsPerBand + j
                    if idx < magnitudes.count { sum += magnitudes[idx] }
                }
                bands[i] = sum / Float(binsPerBand)
            }
            
            let now = CACurrentMediaTime()
            if now - self.lastMasterUIUpdateTime > 0.033 {
                self.lastMasterUIUpdateTime = now
                DispatchQueue.main.async {
                    self.masterEQMagnitudes = bands
                }
            }
            
            self.processWaveform(buffer: buffer, isMaster: true)
        }
        
        // Stems Tap for Ghost Waveform & Individual EQs
        vocalPlayer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self, self.isPlaying else { return }
            self.processWaveform(buffer: buffer, isMaster: false)
            self.computeStemFFT(buffer: buffer, stem: 0)
        }
        drumPlayer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self, self.isPlaying else { return }
            self.computeStemFFT(buffer: buffer, stem: 1)
        }
        bassPlayer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self, self.isPlaying else { return }
            self.computeStemFFT(buffer: buffer, stem: 2)
        }
        otherPlayer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self, self.isPlaying else { return }
            self.computeStemFFT(buffer: buffer, stem: 3)
        }
        
        applyVolumes()
        
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func computeStemFFT(buffer: AVAudioPCMBuffer, stem: Int) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let magnitudes = self.fftAnalyzer.computeFFT(buffer: channelData)
        var bands = [Float](repeating: 0, count: 16)
        let binsPerBand = max(1, magnitudes.count / 16)
        for i in 0..<16 {
            var sum: Float = 0
            for j in 0..<binsPerBand {
                let idx = i * binsPerBand + j
                if idx < magnitudes.count { sum += magnitudes[idx] }
            }
            bands[i] = sum / Float(binsPerBand)
        }
        
        let now = CACurrentMediaTime()
        if now - self.lastStemUIUpdateTime > 0.033 {
            self.lastStemUIUpdateTime = now
            DispatchQueue.main.async {
                switch stem {
                case 0: self.vocalEQMagnitudes = bands
                case 1: self.drumEQMagnitudes = bands
                case 2: self.bassEQMagnitudes = bands
                case 3: self.otherEQMagnitudes = bands
                default: break
                }
            }
        }
    }
    
    private func applyVolumes() {
        if isBypassed {
            stemsSumMixer.outputVolume = 0.0
            originalPlayer.volume = 1.0
            return
        }
        
        originalPlayer.volume = 0.0
        stemsSumMixer.outputVolume = 1.0
        
        let anySolo = vocalSolo || drumSolo || bassSolo || otherSolo
        
        let applyChannel = { (vol: Double, muted: Bool, soloed: Bool, mixer: AVAudioMixerNode) in
            if anySolo {
                mixer.outputVolume = soloed ? Float(vol) : 0.0
            } else {
                mixer.outputVolume = muted ? 0.0 : Float(vol)
            }
        }
        
        applyChannel(vocalVolume, vocalMuted, vocalSolo, vocalMixer)
        applyChannel(drumVolume, drumMuted, drumSolo, drumMixer)
        applyChannel(bassVolume, bassMuted, bassSolo, bassMixer)
        applyChannel(otherVolume, otherMuted, otherSolo, otherMixer)
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
                if rms.isNaN || rms.isInfinite { rms = 0.0 }
                newAmplitudes[i] = rms * 5.0
            }
        }
        
        let now = CACurrentMediaTime()
        if isMaster {
            if now - self.lastMasterUIUpdateTime > 0.033 {
                self.lastMasterUIUpdateTime = now
                DispatchQueue.main.async {
                    self.masterWaveformAmplitudes = newAmplitudes.map { min(max($0, 0.05), 1.0) }
                }
            }
        } else {
            if now - self.lastStemUIUpdateTime > 0.033 {
                self.lastStemUIUpdateTime = now
                DispatchQueue.main.async {
                    self.originalWaveformAmplitudes = newAmplitudes.map { min(max($0, 0.05), 1.0) }
                }
            }
        }
    }
    
    private func clearVisualizers() {
        DispatchQueue.main.async {
            self.masterWaveformAmplitudes = Array(repeating: 0.05, count: 30)
            self.originalWaveformAmplitudes = Array(repeating: 0.05, count: 30)
            self.masterEQMagnitudes = Array(repeating: 0, count: 32)
            self.vocalEQMagnitudes = Array(repeating: 0, count: 16)
            self.drumEQMagnitudes = Array(repeating: 0, count: 16)
            self.bassEQMagnitudes = Array(repeating: 0, count: 16)
            self.otherEQMagnitudes = Array(repeating: 0, count: 16)
        }
    }
    
    // MARK: - Loading & Splitting Audio
    
    @MainActor
    public func loadTrack(_ track: TrackModel) async {
        currentTrackName = track.title.uppercased()
        if isPlaying { togglePlayback() }
        
        extractMetadata(url: track.originalURL)
        
        do {
            let fVocals = try AVAudioFile(forReading: track.vocalStemURL)
            let fDrums = try AVAudioFile(forReading: track.drumStemURL)
            let fBass = try AVAudioFile(forReading: track.bassStemURL)
            let fOther = try AVAudioFile(forReading: track.otherStemURL)
            
            self.fileVocals = fVocals
            self.fileDrums = fDrums
            self.fileBass = fBass
            self.fileOther = fOther
            self.audioFile = try? AVAudioFile(forReading: track.originalURL)
            
            scheduleAllPlayers(at: nil)
            playSynced()
        } catch {
            print("Failed to load cached stems: \(error)")
        }
    }
    
    // MARK: - Active Async Tasks
    private var activeSplitTask: Task<TrackData?, Error>?
    
    @MainActor
    public func cancelSplitAudio() {
        guard isSplitting else { return }
        activeSplitTask?.cancel()
        activeSplitTask = nil
        etaTimer?.invalidate()
        etaTimer = nil
        isSplitting = false
        splitProgress = 0.0
        splitStatusMessage = ""
        currentChunkNumber = 0
        totalChunkCount = 0
        targetEtaSeconds = 0
        etaRemainingString = "00:00"
        Haptics.playClick()
    }
    
    public func loadAndSplitAudio(url: URL) async -> TrackData? {
        let task = Task<TrackData?, Error> {
            let asset = AVURLAsset(url: url)
            let durationSecs = (try? await asset.load(.duration).seconds) ?? 180.0
            let estimatedChunks = max(1, Int(ceil((durationSecs * 44100.0) / 220500.0)))
            let initialEtaSeconds = max(3, Int(round(Double(estimatedChunks) * 0.58 + 1.2)))
            
            await MainActor.run {
                self.currentTrackName = url.lastPathComponent.uppercased()
                self.isSplitting = true
                self.isCompilingModel = false
                self.splitProgress = 0.0 // Pure 0% Start
                self.currentChunkNumber = 0
                self.totalChunkCount = estimatedChunks
                self.targetEtaSeconds = initialEtaSeconds
                self.etaRemainingString = String(format: "%02d:%02d", initialEtaSeconds / 60, initialEtaSeconds % 60)
                self.splitStatusMessage = "DECODING AUDIO TRACK..."
                if self.isPlaying { self.togglePlayback() }
                self.startEtaCountdownTimer()
            }
            
            extractMetadata(url: url)
            
            let stemURLs = try await DemucsEngine.shared.splitAudio(url: url) { [weak self] progressInfo in
                Task { @MainActor in
                    guard let self = self, self.isSplitting else { return }
                    self.splitProgress = progressInfo.fraction
                    self.currentChunkNumber = progressInfo.currentChunk
                    self.totalChunkCount = progressInfo.totalChunks
                    self.splitStatusMessage = progressInfo.statusMessage
                    
                    let newEta = Int(round(progressInfo.estimatedRemainingSeconds))
                    // Nudge target smoothly to prevent jumping
                    if abs(newEta - self.targetEtaSeconds) > 3 {
                        self.targetEtaSeconds = Int(round(0.35 * Double(newEta) + 0.65 * Double(self.targetEtaSeconds)))
                    } else {
                        self.targetEtaSeconds = newEta
                    }
                    let etaMins = self.targetEtaSeconds / 60
                    let etaSecs = self.targetEtaSeconds % 60
                    self.etaRemainingString = String(format: "%02d:%02d", etaMins, etaSecs)
                }
            }
            
            try Task.checkCancellation()
            
            let fVocals = try AVAudioFile(forReading: stemURLs[0])
            let fDrums = try AVAudioFile(forReading: stemURLs[1])
            let fBass = try AVAudioFile(forReading: stemURLs[2])
            let fOther = try AVAudioFile(forReading: stemURLs[3])
            
            self.fileVocals = fVocals
            self.fileDrums = fDrums
            self.fileBass = fBass
            self.fileOther = fOther
            self.audioFile = try? AVAudioFile(forReading: url)
            
            scheduleAllPlayers(at: nil)
            
            let cleanTitle = url.deletingPathExtension().lastPathComponent
            let data = TrackData(
                id: url.path,
                title: cleanTitle,
                originalURL: url,
                vocalStemURL: stemURLs[0],
                bassStemURL: stemURLs[2],
                drumStemURL: stemURLs[1],
                otherStemURL: stemURLs[3]
            )
            
            await MainActor.run {
                self.etaTimer?.invalidate()
                self.etaTimer = nil
                self.isSplitting = false
                self.splitProgress = 1.0
            }
            // Auto-Play Isolated Stems on Completion (User Requirement A10)
            playSynced()
            return data
        }
        
        await MainActor.run {
            self.activeSplitTask = task
        }
        
        do {
            let result = try await task.value
            await MainActor.run {
                self.activeSplitTask = nil
            }
            return result
        } catch {
            await MainActor.run {
                self.activeSplitTask = nil
                self.etaTimer?.invalidate()
                self.etaTimer = nil
                self.isSplitting = false
                self.splitProgress = 0.0
            }
            return nil
        }
    }
    
    @MainActor
    private func startEtaCountdownTimer() {
        etaTimer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isSplitting else { return }
                if self.targetEtaSeconds > 1 {
                    self.targetEtaSeconds -= 1
                    let mins = self.targetEtaSeconds / 60
                    let secs = self.targetEtaSeconds % 60
                    self.etaRemainingString = String(format: "%02d:%02d", mins, secs)
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.etaTimer = t
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
    
    // MARK: - Exporting Stems with Multi-Stage Progression and Completion
    
    @MainActor
    public func exportStems() {
        guard let fVocals = fileVocals, let fDrums = fileDrums, let fBass = fileBass, let fOther = fileOther else { return }
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(currentTrackName)_Stems.zip"
        panel.allowedContentTypes = [UTType.zip]
        
        if panel.runModal() == .OK, let targetURL = panel.url {
            let trackName = currentTrackName
            let vocalsURL = fVocals.url
            let drumsURL = fDrums.url
            let bassURL = fBass.url
            let otherURL = fOther.url
            
            self.exportState = .exporting(stage: "PREPARING", percent: 0.05)
            self.exportProgress = 0.05
            
            Task.detached {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                let vDest = tempDir.appendingPathComponent("\(trackName)_Vocals.wav")
                let dDest = tempDir.appendingPathComponent("\(trackName)_Drums.wav")
                let bDest = tempDir.appendingPathComponent("\(trackName)_Bass.wav")
                let oDest = tempDir.appendingPathComponent("\(trackName)_Other.wav")
                
                // Stage 1: Copy Stems (5% to 30%)
                try? FileManager.default.copyItem(at: vocalsURL, to: vDest)
                await MainActor.run {
                    self.exportState = .exporting(stage: "COPYING", percent: 0.12)
                    self.exportProgress = 0.12
                }
                
                try? FileManager.default.copyItem(at: drumsURL, to: dDest)
                await MainActor.run {
                    self.exportState = .exporting(stage: "COPYING", percent: 0.18)
                    self.exportProgress = 0.18
                }
                
                try? FileManager.default.copyItem(at: bassURL, to: bDest)
                await MainActor.run {
                    self.exportState = .exporting(stage: "COPYING", percent: 0.24)
                    self.exportProgress = 0.24
                }
                
                try? FileManager.default.copyItem(at: otherURL, to: oDest)
                await MainActor.run {
                    self.exportState = .exporting(stage: "COPYING", percent: 0.30)
                    self.exportProgress = 0.30
                }
                
                // Stage 2: Compressing ZIP Archive (30% to 96% with Dynamic Byte Pacing)
                let zipDest = tempDir.appendingPathComponent("stems.zip")
                
                let vSize = (try? FileManager.default.attributesOfItem(atPath: vDest.path)[.size] as? Int64) ?? 40_000_000
                let dSize = (try? FileManager.default.attributesOfItem(atPath: dDest.path)[.size] as? Int64) ?? 40_000_000
                let bSize = (try? FileManager.default.attributesOfItem(atPath: bDest.path)[.size] as? Int64) ?? 40_000_000
                let oSize = (try? FileManager.default.attributesOfItem(atPath: oDest.path)[.size] as? Int64) ?? 40_000_000
                let totalExpectedZipBytes = max(10_000_000, Double(vSize + dSize + bSize + oSize) * 0.70)
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.currentDirectoryURL = tempDir
                process.arguments = ["-j", "-q", zipDest.path, vDest.path, dDest.path, bDest.path, oDest.path]
                
                try? process.run()
                
                var currentZipP = 0.30
                while process.isRunning {
                    let zipCurrentBytes = Double((try? FileManager.default.attributesOfItem(atPath: zipDest.path)[.size] as? Int64) ?? 0)
                    let ratio = min(1.0, zipCurrentBytes / totalExpectedZipBytes)
                    let targetP = 0.30 + (0.66 * ratio)
                    currentZipP = max(currentZipP + 0.015, 0.35 * targetP + 0.65 * currentZipP)
                    currentZipP = min(0.96, currentZipP)
                    
                    let reportP = currentZipP
                    await MainActor.run {
                        self.exportState = .exporting(stage: "ZIPPING", percent: reportP)
                        self.exportProgress = reportP
                    }
                    try? await Task.sleep(nanoseconds: 80_000_000)
                }
                process.waitUntilExit()
                
                // Stage 3: Finalizing (96% to 100%)
                await MainActor.run {
                    self.exportState = .exporting(stage: "SAVING", percent: 0.98)
                    self.exportProgress = 0.98
                }
                
                if FileManager.default.fileExists(atPath: zipDest.path) {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try? FileManager.default.removeItem(at: targetURL)
                    }
                    try? FileManager.default.moveItem(at: zipDest, to: targetURL)
                }
                try? FileManager.default.removeItem(at: tempDir)
                
                // Stage 4: Completed Banner (2.0s)
                await MainActor.run {
                    self.exportState = .completed
                    self.exportProgress = 1.0
                }
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                await MainActor.run {
                    self.exportState = .idle
                    self.exportProgress = 0.0
                }
            }
        }
    }
    
    // MARK: - Synchronized Playback Graph Scheduling
    
    private func scheduleAllPlayers(at time: AVAudioTime?) {
        guard let fVocals = fileVocals,
              let fDrums = fileDrums,
              let fBass = fileBass,
              let fOther = fileOther,
              let aFile = audioFile else { return }
        
        vocalPlayer.stop()
        drumPlayer.stop()
        bassPlayer.stop()
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
        drumPlayer.scheduleFile(fDrums, at: time, completionHandler: nil)
        bassPlayer.scheduleFile(fBass, at: time, completionHandler: nil)
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
        let startTime = AVAudioTime(hostTime: nodeTime.hostTime + AVAudioTime.hostTime(forSeconds: 0.05))
        
        vocalPlayer.play(at: startTime)
        drumPlayer.play(at: startTime)
        bassPlayer.play(at: startTime)
        otherPlayer.play(at: startTime)
        originalPlayer.play(at: startTime)
        
        Task { @MainActor in
            self.isPlaying = true
            self.startPlaybackTimer()
        }
    }
    
    public func togglePlayback() {
        if isPlaying {
            vocalPlayer.pause()
            drumPlayer.pause()
            bassPlayer.pause()
            otherPlayer.pause()
            originalPlayer.pause()
            timer?.invalidate()
            isPlaying = false
            clearVisualizers()
        } else {
            playSynced()
        }
    }
    
    // High-precision 60Hz Playback Timer (16.6ms) for Instantaneous Time & Progress Sync (Active in Common RunLoop Modes)
    private func startPlaybackTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let file = self.audioFile,
                  let lastTime = self.vocalPlayer.lastRenderTime,
                  let playerTime = self.vocalPlayer.playerTime(forNodeTime: lastTime) else { return }
            
            let elapsedFrames = Double(playerTime.sampleTime) + Double(self.seekFrameOffset)
            let elapsed = max(0, elapsedFrames / playerTime.sampleRate)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            guard duration > 0 else { return }
            
            let progress = max(0, min(1, elapsed / duration))
            
            Task { @MainActor in
                self.playbackProgress = progress
                
                let totalDurationSecs = Int(round(duration))
                let elapsedSecs = min(totalDurationSecs, Int(floor(elapsed)))
                let remainingSecs = max(0, totalDurationSecs - elapsedSecs)
                
                let mins = elapsedSecs / 60
                let secs = elapsedSecs % 60
                let rMins = remainingSecs / 60
                let rSecs = remainingSecs % 60
                self.currentTimeString = String(format: "%02d:%02d / -%02d:%02d", mins, secs, rMins, rSecs)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }
    
    @MainActor
    public func updateTimeString(for progress: Double) {
        guard let file = audioFile else { return }
        let duration = Double(file.length) / file.processingFormat.sampleRate
        guard duration > 0 else { return }
        let totalDurationSecs = Int(round(duration))
        let elapsedSecs = min(totalDurationSecs, Int(floor(duration * progress)))
        let remainingSecs = max(0, totalDurationSecs - elapsedSecs)
        
        let mins = elapsedSecs / 60
        let secs = elapsedSecs % 60
        let rMins = remainingSecs / 60
        let rSecs = remainingSecs % 60
        currentTimeString = String(format: "%02d:%02d / -%02d:%02d", mins, secs, rMins, rSecs)
    }
    
    @MainActor
    public func seek(toPercentage percentage: Double) {
        guard let fVocals = fileVocals,
              let fDrums = fileDrums,
              let fBass = fileBass,
              let fOther = fileOther,
              let aFile = audioFile else { return }
        
        let wasPlaying = isPlaying
        
        vocalPlayer.stop()
        drumPlayer.stop()
        bassPlayer.stop()
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
        drumPlayer.scheduleSegment(fDrums, startingFrame: targetFrame, frameCount: framesToPlay, at: nil, completionHandler: nil)
        bassPlayer.scheduleSegment(fBass, startingFrame: targetFrame, frameCount: framesToPlay, at: nil, completionHandler: nil)
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
