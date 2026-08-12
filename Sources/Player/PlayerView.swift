import SwiftUI

struct GridBackground: View {
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            GeometryReader { geometry in
                Path { path in
                    let step: CGFloat = 20
                    for x in stride(from: 0, to: geometry.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    for y in stride(from: 0, to: geometry.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
        }
    }
}

struct PlayerView: View {
    @Environment(AudioEngineManager.self) private var engineManager

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                HStack(spacing: 20) {
                    AlbumArtView(image: engineManager.albumArt)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        MarqueeText(text: engineManager.currentTrackName, font: .custom("DotGothic16-Regular", size: 24))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Spacer(minLength: 20)
                    
                    RealWaveformView(amplitudes: engineManager.waveformAmplitudes, ghostAmplitudes: engineManager.originalWaveformAmplitudes)
                }
                .padding()
                
                HStack(spacing: 40) {
                    @Bindable var engine = engineManager
                    StemChannelView(title: "VOCALS", volume: $engine.vocalVolume, isMuted: $engine.vocalMuted, isSoloed: $engine.vocalSolo)
                    StemChannelView(title: "DRUMS", volume: $engine.drumVolume, isMuted: $engine.drumMuted, isSoloed: $engine.drumSolo)
                    StemChannelView(title: "BASS", volume: $engine.bassVolume, isMuted: $engine.bassMuted, isSoloed: $engine.bassSolo)
                    StemChannelView(title: "OTHER", volume: $engine.otherVolume, isMuted: $engine.otherMuted, isSoloed: $engine.otherSolo)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            TransportBar()
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(GridBackground())
    }
}

struct StemChannelView: View {
    let title: String
    @Binding var volume: Double
    @Binding var isMuted: Bool
    @Binding var isSoloed: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.custom("DotGothic16-Regular", size: 18))
                .foregroundColor(.white)
            
            Text("\(Int(volume * 100))")
                .font(.custom("DotGothic16-Regular", size: 16))
                .foregroundColor(.gray)
            
            CustomFader(value: $volume, label: title)
            
            HStack(spacing: 8) {
                Button("M") {
                    Haptics.playClick()
                    isMuted.toggle()
                }
                .font(.custom("DotGothic16-Regular", size: 14))
                .frame(width: 32, height: 32)
                .background(isMuted ? Color.red : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray, lineWidth: 1))
                .foregroundColor(isMuted ? .black : .white)
                
                Button("S") {
                    Haptics.playClick()
                    isSoloed.toggle()
                }
                .font(.custom("DotGothic16-Regular", size: 14))
                .frame(width: 32, height: 32)
                .background(isSoloed ? Color.red : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray, lineWidth: 1))
                .foregroundColor(isSoloed ? .black : .white)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
        .frame(width: 120)
        .background(Color.black.opacity(0.4))
        .border(Color.white.opacity(0.1), width: 1)
    }
}

struct AlbumArtView: View {
    let image: NSImage?
    
    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.black
                    Rectangle().stroke(Color.red, lineWidth: 2)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 64, y: 64))
                        path.move(to: CGPoint(x: 64, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: 64))
                    }
                    .stroke(Color.red, lineWidth: 1)
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipped()
    }
}

struct RealWaveformView: View {
    let amplitudes: [Float]
    let ghostAmplitudes: [Float]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<amplitudes.count, id: \.self) { i in
                let activeBlocks = max(1, Int(amplitudes[i] * 21))
                let ghostBlocks = max(1, Int(ghostAmplitudes[i] * 21))
                
                VStack(spacing: 1) {
                    ForEach(0..<21, id: \.self) { blockIndex in
                        let distance = abs(10 - blockIndex)
                        let activeThreshold = CGFloat(activeBlocks) / 2.0
                        let ghostThreshold = CGFloat(ghostBlocks) / 2.0
                        
                        let isSolid = CGFloat(distance) <= activeThreshold
                        let isGhost = CGFloat(distance) <= ghostThreshold
                        
                        Rectangle()
                            .fill(isSolid ? Color.red : (isGhost ? Color.red.opacity(0.2) : Color.clear))
                            .frame(width: 4, height: 2)
                    }
                }
                .animation(.linear(duration: 0.05), value: amplitudes)
            }
        }
        .frame(height: 64)
    }
}

struct EQSpectrumView: View {
    let magnitudes: [Float]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<magnitudes.count, id: \.self) { i in
                let heightValue = min(1.0, CGFloat(magnitudes[i]) * 10.0) 
                let blocks = max(1, Int(heightValue * 12))
                
                VStack(spacing: 1) {
                    Spacer(minLength: 0)
                    ForEach(0..<blocks, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 4, height: 2)
                    }
                }
                .animation(.linear(duration: 0.05), value: magnitudes)
            }
        }
        .frame(height: 36)
    }
}

struct TransportBar: View {
    @Environment(AudioEngineManager.self) private var engineManager
    @State private var wasPlayingBeforeDrag = false
    
    var body: some View {
        HStack {
            Text(engineManager.currentTimeString)
                .font(.custom("DotGothic16-Regular", size: 18))
                .foregroundColor(.red)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 2))
                        path.addLine(to: CGPoint(x: geo.size.width, y: 2))
                    }
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 4, dash: [4, 4]))
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 2))
                        path.addLine(to: CGPoint(x: max(0, geo.size.width * engineManager.playbackProgress), y: 2))
                    }
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 4, dash: [4, 4]))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !wasPlayingBeforeDrag && engineManager.isPlaying {
                                wasPlayingBeforeDrag = true
                            }
                            if engineManager.isPlaying {
                                engineManager.togglePlayback()
                            }
                            let percent = max(0, min(1, value.location.x / geo.size.width))
                            engineManager.playbackProgress = percent
                            engineManager.updateTimeString(for: percent)
                        }
                        .onEnded { value in
                            let percent = max(0, min(1, value.location.x / geo.size.width))
                            engineManager.seek(toPercentage: percent)
                            if wasPlayingBeforeDrag {
                                engineManager.togglePlayback()
                            }
                            wasPlayingBeforeDrag = false
                        }
                )
            }
            .frame(height: 40)
            
            Button(action: {
                Haptics.playClick()
                engineManager.togglePlayback()
            }) {
                Image(systemName: engineManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
                    .frame(width: 48, height: 48)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            
            Button(engineManager.isBypassed ? "BYPASS: ON" : "BYPASS: OFF") {
                Haptics.playClick()
                engineManager.isBypassed.toggle()
            }
            .font(.custom("DotGothic16-Regular", size: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(engineManager.isBypassed ? Color.red : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1))
            .foregroundColor(engineManager.isBypassed ? .black : .red)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .buttonStyle(.plain)
            
            Button(engineManager.isExporting ? String(format: "EXPORTING... %.0f%%", engineManager.exportProgress * 100) : "EXPORT STEMS") {
                Haptics.playClick()
                engineManager.exportStems()
            }
            .font(.custom("DotGothic16-Regular", size: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(engineManager.isExporting ? Color.red.opacity(0.3) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1))
            .foregroundColor(engineManager.isExporting ? .gray : .red)
            .disabled(engineManager.isExporting)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
        .background(Color.black)
        .border(Color.white.opacity(0.1), width: 1)
    }
}

struct MarqueeText: View {
    let text: String
    let font: Font
    
    @State private var offset: CGFloat = 0
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { textGeo in
                        Color.clear
                            .onAppear {
                                startAnimation(containerWidth: geo.size.width, textWidth: textGeo.size.width)
                            }
                            .onChange(of: text) { _, _ in
                                startAnimation(containerWidth: geo.size.width, textWidth: textGeo.size.width)
                            }
                    }
                )
                .offset(x: offset)
                .frame(width: geo.size.width, alignment: .leading)
                .clipped()
        }
        .frame(height: 30) // Fixed height to prevent GeometryReader from collapsing or expanding infinitely
    }
    
    private func startAnimation(containerWidth: CGFloat, textWidth: CGFloat) {
        offset = 0
        isAnimating = false
        
        let diff = textWidth - containerWidth
        if diff > 0 {
            isAnimating = true
            let speed: CGFloat = 30.0 // Points per second
            let totalTime = Double(diff / speed)
            let steps = Int(diff / 12)
            let timePerStep = steps > 0 ? totalTime / Double(steps) : 0
            
            Task { @MainActor in
                while isAnimating {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard isAnimating else { break }
                    
                    for _ in 0..<steps {
                        offset -= 12
                        try? await Task.sleep(nanoseconds: UInt64(timePerStep * 1_000_000_000))
                        guard isAnimating else { break }
                    }
                    offset = -diff
                    
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard isAnimating else { break }
                    
                    for _ in 0..<steps {
                        offset += 12
                        try? await Task.sleep(nanoseconds: UInt64(timePerStep * 1_000_000_000))
                        guard isAnimating else { break }
                    }
                    offset = 0
                }
            }
        }
    }
}
