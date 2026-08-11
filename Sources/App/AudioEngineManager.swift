import AVFoundation
import Observation
import SwiftUI

@Observable
final class AudioEngineManager {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    // Master routing for Phase 1
    var isPlaying = false
    var masterVolume: Double = 0.8 {
        didSet {
            engine.mainMixerNode.outputVolume = Float(masterVolume)
        }
    }
    
    var currentTrackName: String = "NO TRACK LOADED"
    var playbackProgress: Double = 0.0
    
    init() {
        setupEngine()
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func loadAudio(url: URL) {
        currentTrackName = url.lastPathComponent.uppercased()
        
        do {
            let file = try AVAudioFile(forReading: url)
            playerNode.stop()
            playerNode.scheduleFile(file, at: nil) {
                // Handle completion
                Task { @MainActor in
                    self.isPlaying = false
                }
            }
            if isPlaying {
                playerNode.play()
            }
        } catch {
            print("Failed to load audio file: \(error)")
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            playerNode.pause()
        } else {
            playerNode.play()
        }
        isPlaying.toggle()
    }
}
