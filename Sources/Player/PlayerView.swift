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
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
            }
        }
    }
}

public struct PlayerView: View {
    @Environment(AudioEngineManager.self) private var engineManager

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // Top Header: 100x100 Hero Artwork, Track Title, Master Waveform & Spectrum
                HStack(spacing: 24) {
                    AlbumArtView(image: engineManager.albumArt)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        MarqueeText(text: engineManager.currentTrackName, font: .custom("DotGothic16-Regular", size: 26))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            Text(engineManager.isBypassed ? "SOURCE: ORIGINAL MASTER" : "SOURCE: 4-STEM ISOLATION")
                                .font(.custom("DotGothic16-Regular", size: 12))
                                .foregroundColor(engineManager.isBypassed ? .yellow : .gray)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(engineManager.isPlaying ? Color.red : Color.gray)
                                    .frame(width: 6, height: 6)
                                
                                Text(engineManager.isPlaying ? "ACTIVE" : "STANDBY")
                                    .font(.custom("DotGothic16-Regular", size: 11))
                                    .foregroundColor(engineManager.isPlaying ? .red : .gray)
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        RealWaveformView(
                            amplitudes: engineManager.masterWaveformAmplitudes,
                            ghostAmplitudes: engineManager.originalWaveformAmplitudes
                        )
                        EQSpectrumView(magnitudes: engineManager.masterEQMagnitudes)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                // 4 Fluid Adaptive Stem Mixer Channels
                HStack(spacing: 18) {
                    @Bindable var engine = engineManager
                    StemChannelView(
                        title: "VOCALS",
                        volume: $engine.vocalVolume,
                        isMuted: $engine.vocalMuted,
                        isSoloed: $engine.vocalSolo,
                        eqMagnitudes: engine.vocalEQMagnitudes
                    )
                    StemChannelView(
                        title: "DRUMS",
                        volume: $engine.drumVolume,
                        isMuted: $engine.drumMuted,
                        isSoloed: $engine.drumSolo,
                        eqMagnitudes: engine.drumEQMagnitudes
                    )
                    StemChannelView(
                        title: "BASS",
                        volume: $engine.bassVolume,
                        isMuted: $engine.bassMuted,
                        isSoloed: $engine.bassSolo,
                        eqMagnitudes: engine.bassEQMagnitudes
                    )
                    StemChannelView(
                        title: "OTHER",
                        volume: $engine.otherVolume,
                        isMuted: $engine.otherMuted,
                        isSoloed: $engine.otherSolo,
                        eqMagnitudes: engine.otherEQMagnitudes
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            TransportBar()
        }
        .frame(minWidth: 700, minHeight: 520)
        .background(GridBackground())
    }
}

struct StemChannelView: View {
    let title: String
    @Binding var volume: Double
    @Binding var isMuted: Bool
    @Binding var isSoloed: Bool
    let eqMagnitudes: [Float]
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.custom("DotGothic16-Regular", size: 16))
                .foregroundColor(.white)
            
            // Mini Live EQ Visualizer per stem
            StemMiniEQView(magnitudes: eqMagnitudes)
                .frame(height: 24)
            
            Text("\(Int(volume * 100))")
                .font(.custom("DotGothic16-Regular", size: 14))
                .foregroundColor(.gray)
            
            CustomFader(value: $volume, label: title)
                .frame(maxHeight: .infinity)
            
            HStack(spacing: 8) {
                Button("M") {
                    Haptics.playClick()
                    isMuted.toggle()
                }
                .font(.custom("DotGothic16-Regular", size: 13))
                .frame(width: 34, height: 30)
                .background(isMuted ? Color.red : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .foregroundColor(isMuted ? .black : .white)
                .buttonStyle(.plain)
                
                Button("S") {
                    Haptics.playClick()
                    isSoloed.toggle()
                }
                .font(.custom("DotGothic16-Regular", size: 13))
                .frame(width: 34, height: 30)
                .background(isSoloed ? Color.red : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .foregroundColor(isSoloed ? .black : .white)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
        .border(Color.white.opacity(0.1), width: 1)
    }
}

struct StemMiniEQView: View {
    let magnitudes: [Float]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<magnitudes.count, id: \.self) { i in
                let heightValue = min(1.0, CGFloat(magnitudes[i]) * 8.0)
                let blocks = max(1, Int(heightValue * 6))
                
                VStack(spacing: 1) {
                    Spacer(minLength: 0)
                    ForEach(0..<blocks, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.red.opacity(0.85))
                            .frame(width: 3, height: 2)
                    }
                }
                .animation(.linear(duration: 0.04), value: magnitudes)
            }
        }
    }
}

// MARK: - Nothing 50x50 Real-Time Dot-Matrix Processor
public final class DotMatrixImageProcessor {
    public static func generateDotMatrix(from image: NSImage, gridSize: Int = 50) -> [[Float]]? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else { return nil }
        
        let width = gridSize
        let height = gridSize
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var matrix = [[Float]](repeating: [Float](repeating: 0, count: width), count: height)
        for y in 0..<height {
            for x in 0..<width {
                let imgY = (height - 1) - y
                let offset = (imgY * width + x) * 4
                let r = Float(rawData[offset]) / 255.0
                let g = Float(rawData[offset + 1]) / 255.0
                let b = Float(rawData[offset + 2]) / 255.0
                let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
                let contrastBoosted = powf(lum, 1.2)
                matrix[y][x] = min(max(contrastBoosted, 0.0), 1.0)
            }
        }
        return matrix
    }
}

// MARK: - Hero 100x100 Album Art View with Nothing Dot-Matrix LED Screen
struct AlbumArtView: View {
    let image: NSImage?
    @Environment(AudioEngineManager.self) private var engineManager
    @State private var dotMatrix: [[Float]]? = nil
    @State private var isHovered = false
    @State private var showColorOverride = false
    
    var body: some View {
        ZStack {
            Color.black
            
            if let img = image {
                ZStack {
                    // 1. Real-Time 50x50 Nothing Dot-Matrix LED Canvas
                    if let matrix = dotMatrix {
                        Canvas { context, size in
                            let gridSize = 50
                            let cellWidth = size.width / CGFloat(gridSize)
                            let cellHeight = size.height / CGFloat(gridSize)
                            let audioEnergy = engineManager.isPlaying ? Double(engineManager.masterWaveformAmplitudes.reduce(0, +) / Float(max(1, engineManager.masterWaveformAmplitudes.count))) : 0.0
                            let pulse = 1.0 + (audioEnergy * 0.12)
                            
                            for y in 0..<gridSize {
                                for x in 0..<gridSize {
                                    let lum = matrix[y][x]
                                    guard lum > 0.02 else {
                                        // Draw faint unlit LED cell for authentic hardware display depth
                                        let dotRect = CGRect(
                                            x: CGFloat(x) * cellWidth + cellWidth * 0.35,
                                            y: CGFloat(y) * cellHeight + cellHeight * 0.35,
                                            width: cellWidth * 0.3,
                                            height: cellHeight * 0.3
                                        )
                                        context.fill(Path(ellipseIn: dotRect), with: .color(Color.white.opacity(0.04)))
                                        continue
                                    }
                                    
                                    let baseRadius = (cellWidth * 0.46) * CGFloat(lum) * CGFloat(pulse)
                                    let clampedRadius = min(cellWidth * 0.48, max(0.35, baseRadius))
                                    
                                    let centerX = CGFloat(x) * cellWidth + (cellWidth * 0.5)
                                    let centerY = CGFloat(y) * cellHeight + (cellHeight * 0.5)
                                    let dotRect = CGRect(
                                        x: centerX - clampedRadius,
                                        y: centerY - clampedRadius,
                                        width: clampedRadius * 2,
                                        height: clampedRadius * 2
                                    )
                                    
                                    let opacity = min(1.0, 0.22 + Double(lum) * 0.78)
                                    context.fill(Path(ellipseIn: dotRect), with: .color(Color.white.opacity(opacity)))
                                }
                            }
                        }
                        .frame(width: 100, height: 100)
                    }
                    
                    // 2. High-Res Original Color Image on Hover or Click
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipped()
                        .opacity(isHovered || showColorOverride ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.25), value: isHovered || showColorOverride)
                }
            } else {
                // Standby diagnostic crosslines
                ZStack {
                    Color.black
                    Rectangle()
                        .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 100, y: 100))
                        path.move(to: CGPoint(x: 100, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: 100))
                    }
                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    
                    Text("NO ARTWORK")
                        .font(.custom("DotGothic16-Regular", size: 10))
                        .foregroundColor(.red.opacity(0.85))
                        .padding(4)
                        .background(Color.black)
                }
            }
            
            // Outer Hardware Border
            Rectangle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
            
            // Red Corner Accents (Nothing Hardware Style)
            CornerBrackets()
            
            // Glyph status badge in bottom-right
            if image != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(isHovered || showColorOverride ? "NATURAL" : "DOT MATRIX")
                            .font(.custom("DotGothic16-Regular", size: 8))
                            .foregroundColor(isHovered || showColorOverride ? .black : .red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(isHovered || showColorOverride ? Color.white.opacity(0.9) : Color.black.opacity(0.8))
                            .border(isHovered || showColorOverride ? Color.white : Color.red.opacity(0.6), width: 0.5)
                            .padding(4)
                    }
                }
            }
        }
        .frame(width: 100, height: 100)
        .clipped()
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            showColorOverride.toggle()
        }
        .onChange(of: image) { _, newImage in
            updateMatrix(for: newImage)
        }
        .onAppear {
            updateMatrix(for: image)
        }
    }
    
    private func updateMatrix(for img: NSImage?) {
        guard let img = img else {
            dotMatrix = nil
            return
        }
        Task.detached(priority: .userInitiated) {
            let matrix = DotMatrixImageProcessor.generateDotMatrix(from: img, gridSize: 50)
            await MainActor.run {
                self.dotMatrix = matrix
            }
        }
    }
}

struct CornerBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let len: CGFloat = 8.0
            
            Path { p in
                // Top-Left
                p.move(to: CGPoint(x: 0, y: len))
                p.addLine(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: len, y: 0))
                
                // Top-Right
                p.move(to: CGPoint(x: w - len, y: 0))
                p.addLine(to: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: w, y: len))
                
                // Bottom-Left
                p.move(to: CGPoint(x: 0, y: h - len))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: len, y: h))
                
                // Bottom-Right
                p.move(to: CGPoint(x: w - len, y: h))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: w, y: h - len))
            }
            .stroke(Color.red, lineWidth: 2)
        }
    }
}

struct RealWaveformView: View {
    let amplitudes: [Float]
    let ghostAmplitudes: [Float]
    
    var body: some View {
        HStack(spacing: 3) {
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
                            .fill(isSolid ? Color.red : (isGhost ? Color.red.opacity(0.25) : Color.clear))
                            .frame(width: 3, height: 2)
                    }
                }
                .animation(.linear(duration: 0.04), value: amplitudes)
            }
        }
        .frame(height: 52)
    }
}

struct EQSpectrumView: View {
    let magnitudes: [Float]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<magnitudes.count, id: \.self) { i in
                let heightValue = min(1.0, CGFloat(magnitudes[i]) * 8.0)
                let blocks = max(1, Int(heightValue * 8))
                
                VStack(spacing: 1) {
                    Spacer(minLength: 0)
                    ForEach(0..<blocks, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 3, height: 2)
                    }
                }
                .animation(.linear(duration: 0.04), value: magnitudes)
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Discrete LED Dot-Matrix Progress Bar
struct DotMatrixProgressBar: View {
    let progress: Double
    let onSeek: (Double) -> Void
    let onSeekingChanged: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let blockWidth: CGFloat = 5.0
            let blockSpacing: CGFloat = 3.0
            let totalUnitWidth = blockWidth + blockSpacing
            let blockCount = max(1, Int(geo.size.width / totalUnitWidth))
            let activeCount = Int(round(Double(blockCount) * max(0, min(1, progress))))
            
            HStack(spacing: blockSpacing) {
                ForEach(0..<blockCount, id: \.self) { i in
                    Rectangle()
                        .fill(i < activeCount ? Color.red : Color.white.opacity(0.12))
                        .frame(width: blockWidth, height: 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onSeekingChanged(true)
                        let percent = max(0, min(1, value.location.x / geo.size.width))
                        onSeek(percent)
                    }
                    .onEnded { value in
                        let percent = max(0, min(1, value.location.x / geo.size.width))
                        onSeek(percent)
                        onSeekingChanged(false)
                    }
            )
        }
        .frame(height: 36)
    }
}

struct TransportBar: View {
    @Environment(AudioEngineManager.self) private var engineManager
    @State private var wasPlayingBeforeDrag = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Synchronized Single-Clock Time String (0ms offset)
            Text(engineManager.currentTimeString)
                .font(.custom("DotGothic16-Regular", size: 16))
                .foregroundColor(.red)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            // Discrete LED Hardware Dot-Matrix Progress Bar (0ms snap)
            DotMatrixProgressBar(
                progress: engineManager.playbackProgress,
                onSeek: { percent in
                    engineManager.playbackProgress = percent
                    engineManager.updateTimeString(for: percent)
                },
                onSeekingChanged: { isSeeking in
                    if isSeeking {
                        if !wasPlayingBeforeDrag && engineManager.isPlaying {
                            wasPlayingBeforeDrag = true
                            engineManager.togglePlayback()
                        }
                    } else {
                        engineManager.seek(toPercentage: engineManager.playbackProgress)
                        if wasPlayingBeforeDrag {
                            engineManager.togglePlayback()
                        }
                        wasPlayingBeforeDrag = false
                    }
                }
            )
            
            // Play / Pause Transport Button
            Button(action: {
                Haptics.playClick()
                engineManager.togglePlayback()
            }) {
                Image(systemName: engineManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            
            // Master Bypass A/B Comparison Toggle
            Button(engineManager.isBypassed ? "BYPASS: ON" : "BYPASS: OFF") {
                Haptics.playClick()
                engineManager.isBypassed.toggle()
            }
            .font(.custom("DotGothic16-Regular", size: 13))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(engineManager.isBypassed ? Color.red : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1))
            .foregroundColor(engineManager.isBypassed ? .black : .red)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .buttonStyle(.plain)
            
            // Export Stems Button with Fixed 140x34pt Hardware Dimensions & Centered Layout
            Button(action: {
                Haptics.playClick()
                engineManager.exportStems()
            }) {
                ZStack {
                    switch engineManager.exportState {
                    case .idle:
                        Text("EXPORT STEMS")
                            .foregroundColor(.red)
                    case .exporting(let stage, let percent):
                        Text("\(stage) \(Int(percent * 100))%")
                            .foregroundColor(.yellow)
                    case .completed:
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("COMPLETED")
                        }
                        .foregroundColor(.white)
                    }
                }
                .font(.custom("DotGothic16-Regular", size: 13))
                .frame(width: 140, height: 34)
                .background(
                    engineManager.exportState == .completed
                        ? Color.red
                        : (engineManager.isExporting ? Color.red.opacity(0.25) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(engineManager.exportState == .completed ? Color.white : Color.red, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .disabled(engineManager.isExporting || engineManager.exportState == .completed)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
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
        .frame(height: 30)
    }
    
    private func startAnimation(containerWidth: CGFloat, textWidth: CGFloat) {
        offset = 0
        isAnimating = false
        
        let diff = textWidth - containerWidth
        if diff > 0 {
            isAnimating = true
            let speed: CGFloat = 30.0
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
