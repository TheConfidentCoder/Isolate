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
    var isSidebarVisible: Binding<Bool>?

    public init(isSidebarVisible: Binding<Bool>? = nil) {
        self.isSidebarVisible = isSidebarVisible
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // Top Header: Sidebar Toggle, 100x100 Hero Artwork, Track Title, Master Waveform & Spectrum
                HStack(spacing: 18) {
                    if let isSidebarVisible = isSidebarVisible {
                        Button(action: {
                            Haptics.playClick()
                            withAnimation(nil) { // 0ms Instant Nothing Hardware Snap
                                isSidebarVisible.wrappedValue.toggle()
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(isSidebarVisible.wrappedValue ? Color.red : Color.gray.opacity(0.6), lineWidth: 1)
                                    .frame(width: 18, height: 14)
                                
                                HStack(spacing: 2) {
                                    Rectangle()
                                        .fill(isSidebarVisible.wrappedValue ? Color.red : Color.gray.opacity(0.6))
                                        .frame(width: 4, height: 10)
                                    Spacer()
                                }
                                .frame(width: 14, height: 10)
                            }
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                    
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
                .frame(maxHeight: .infinity)
            }
            .background(GridBackground())
            
            // Fixed Bottom Transport & Mixer Controls
            TransportBar()
        }
        .background {
            // Number Keyboard Shortcuts: 1-4 for Mute, Shift+1-4 for Solo
            Group {
                Button("") { toggleMute(0) }.keyboardShortcut("1", modifiers: []).hidden()
                Button("") { toggleMute(1) }.keyboardShortcut("2", modifiers: []).hidden()
                Button("") { toggleMute(2) }.keyboardShortcut("3", modifiers: []).hidden()
                Button("") { toggleMute(3) }.keyboardShortcut("4", modifiers: []).hidden()
                
                Button("") { toggleSolo(0) }.keyboardShortcut("1", modifiers: [.shift]).hidden()
                Button("") { toggleSolo(1) }.keyboardShortcut("2", modifiers: [.shift]).hidden()
                Button("") { toggleSolo(2) }.keyboardShortcut("3", modifiers: [.shift]).hidden()
                Button("") { toggleSolo(3) }.keyboardShortcut("4", modifiers: [.shift]).hidden()
            }
        }
    }
    
    private func toggleMute(_ index: Int) {
        Haptics.playClick()
        switch index {
        case 0:
            if engineManager.vocalMuted {
                engineManager.vocalMuted = false
            } else {
                engineManager.vocalMuted = true
                engineManager.vocalSolo = false
            }
        case 1:
            if engineManager.drumMuted {
                engineManager.drumMuted = false
            } else {
                engineManager.drumMuted = true
                engineManager.drumSolo = false
            }
        case 2:
            if engineManager.bassMuted {
                engineManager.bassMuted = false
            } else {
                engineManager.bassMuted = true
                engineManager.bassSolo = false
            }
        case 3:
            if engineManager.otherMuted {
                engineManager.otherMuted = false
            } else {
                engineManager.otherMuted = true
                engineManager.otherSolo = false
            }
        default: break
        }
    }
    
    private func toggleSolo(_ index: Int) {
        Haptics.playClick()
        switch index {
        case 0:
            if engineManager.vocalSolo {
                engineManager.vocalSolo = false
            } else {
                engineManager.vocalSolo = true
                engineManager.vocalMuted = false
            }
        case 1:
            if engineManager.drumSolo {
                engineManager.drumSolo = false
            } else {
                engineManager.drumSolo = true
                engineManager.drumMuted = false
            }
        case 2:
            if engineManager.bassSolo {
                engineManager.bassSolo = false
            } else {
                engineManager.bassSolo = true
                engineManager.bassMuted = false
            }
        case 3:
            if engineManager.otherSolo {
                engineManager.otherSolo = false
            } else {
                engineManager.otherSolo = true
                engineManager.otherMuted = false
            }
        default: break
        }
    }
}

struct StemChannelView: View {
    let title: String
    @Binding var volume: Double
    @Binding var isMuted: Bool
    @Binding var isSoloed: Bool
    let eqMagnitudes: [Float]
    
    @State private var isMutedHovered = false
    @State private var isSoloedHovered = false
    
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
                // MUTE BUTTON
                Button(action: {
                    Haptics.playClick()
                    if isMuted {
                        isMuted = false
                    } else {
                        isMuted = true
                        isSoloed = false // Mutual Exclusivity: disables Solo
                    }
                }) {
                    Text("M")
                        .font(.custom("DotGothic16-Regular", size: 13))
                        .fontWeight(.bold)
                        .frame(width: 34, height: 30)
                        .background(isMuted ? Color.red : (isMutedHovered ? Color.white.opacity(0.08) : Color.clear))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isMuted ? Color.red : (isMutedHovered ? Color.red.opacity(0.6) : Color.gray.opacity(0.5)), lineWidth: 1)
                        )
                        .foregroundColor(isMuted ? .black : .white)
                        .contentShape(Rectangle()) // Entire 34x30 area clickable!
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isMutedHovered = hovering
                }
                
                // SOLO BUTTON
                Button(action: {
                    Haptics.playClick()
                    if isSoloed {
                        isSoloed = false
                    } else {
                        isSoloed = true
                        isMuted = false // Mutual Exclusivity: disables Mute
                    }
                }) {
                    Text("S")
                        .font(.custom("DotGothic16-Regular", size: 13))
                        .fontWeight(.bold)
                        .frame(width: 34, height: 30)
                        .background(isSoloed ? Color.red : (isSoloedHovered ? Color.white.opacity(0.08) : Color.clear))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSoloed ? Color.red : (isSoloedHovered ? Color.red.opacity(0.6) : Color.gray.opacity(0.5)), lineWidth: 1)
                        )
                        .foregroundColor(isSoloed ? .black : .white)
                        .contentShape(Rectangle()) // Entire 34x30 area clickable!
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isSoloedHovered = hovering
                }
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

// MARK: - Nothing 50x50 Real-Time RGB Color Dot-Matrix Processor
public struct DotMatrixCell: Sendable {
    public let r: Float
    public let g: Float
    public let b: Float
    public let luminance: Float
}

public final class DotMatrixImageProcessor {
    public static func generateColorDotMatrix(from image: NSImage, gridSize: Int = 50) -> [[DotMatrixCell]]? {
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
        
        var matrix = [[DotMatrixCell]](
            repeating: [DotMatrixCell](repeating: DotMatrixCell(r: 0, g: 0, b: 0, luminance: 0), count: width),
            count: height
        )
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let rRaw = Float(rawData[offset]) / 255.0
                let gRaw = Float(rawData[offset + 1]) / 255.0
                let bRaw = Float(rawData[offset + 2]) / 255.0
                
                // 100% Perceptual Brightness Compensation:
                // Compensates for non-emissive aperture gaps between circular dots
                // so total luminous flux matches the original continuous-tone image 1:1
                let gain: Float = 1.25
                let rComp = min(1.0, powf(rRaw, 0.94) * gain)
                let gComp = min(1.0, powf(gRaw, 0.94) * gain)
                let bComp = min(1.0, powf(bRaw, 0.94) * gain)
                let lum = 0.2126 * rComp + 0.7152 * gComp + 0.0722 * bComp
                
                matrix[y][x] = DotMatrixCell(r: rComp, g: gComp, b: bComp, luminance: lum)
            }
        }
        return matrix
    }
}

// MARK: - Hero 100x100 Album Art View with Full-Color Nothing Dot-Matrix LED Screen
struct AlbumArtView: View {
    let image: NSImage?
    @Environment(AudioEngineManager.self) private var engineManager
    @State private var dotMatrix: [[DotMatrixCell]]? = nil
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            Color.black
            
            if let _ = image {
                ZStack {
                    // 1. Real-Time 50x50 Full-Color RGB Dot-Matrix LED Canvas (100% Brightness Matched)
                    if let matrix = dotMatrix {
                        Canvas { context, size in
                            let gridSize = 50
                            let cellWidth = size.width / CGFloat(gridSize)
                            let cellHeight = size.height / CGFloat(gridSize)
                            let audioEnergy = engineManager.isPlaying ? Double(engineManager.masterWaveformAmplitudes.reduce(0, +) / Float(max(1, engineManager.masterWaveformAmplitudes.count))) : 0.0
                            let pulse = 1.0 + (audioEnergy * 0.08)
                            let maxDotRadius = cellWidth * 0.46 // Micro-aperture 0.2px boundary
                            
                            for y in 0..<gridSize {
                                for x in 0..<gridSize {
                                    let cell = matrix[y][x]
                                    let lum = cell.luminance
                                    
                                    // Scale dot radius smoothly for full luminous coverage
                                    let normalizedScale = CGFloat(0.55 + 0.45 * sqrt(lum))
                                    let baseRadius = maxDotRadius * normalizedScale * CGFloat(pulse)
                                    let clampedRadius = min(maxDotRadius, max(0.40, baseRadius))
                                    
                                    let centerX = CGFloat(x) * cellWidth + (cellWidth * 0.5)
                                    let centerY = CGFloat(y) * cellHeight + (cellHeight * 0.5)
                                    let dotRect = CGRect(
                                        x: centerX - clampedRadius,
                                        y: centerY - clampedRadius,
                                        width: clampedRadius * 2,
                                        height: clampedRadius * 2
                                    )
                                    
                                    let dotColor = Color(
                                        red: Double(cell.r),
                                        green: Double(cell.g),
                                        blue: Double(cell.b)
                                    )
                                    context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
                                }
                            }
                        }
                        .frame(width: 100, height: 100)
                    }
                    
                    // 2. Subtle Micro-Bloom Glow on Hover
                    if isHovered, let matrix = dotMatrix {
                        Canvas { context, size in
                            let gridSize = 50
                            let cellWidth = size.width / CGFloat(gridSize)
                            let cellHeight = size.height / CGFloat(gridSize)
                            for y in 0..<gridSize {
                                for x in 0..<gridSize {
                                    let cell = matrix[y][x]
                                    guard cell.luminance > 0.10 else { continue }
                                    let centerX = CGFloat(x) * cellWidth + (cellWidth * 0.5)
                                    let centerY = CGFloat(y) * cellHeight + (cellHeight * 0.5)
                                    let bloomRect = CGRect(x: centerX - cellWidth * 0.55, y: centerY - cellHeight * 0.55, width: cellWidth * 1.1, height: cellHeight * 1.1)
                                    let dotColor = Color(red: Double(cell.r), green: Double(cell.g), blue: Double(cell.b)).opacity(0.35)
                                    context.fill(Path(ellipseIn: bloomRect), with: .color(dotColor))
                                }
                            }
                        }
                        .frame(width: 100, height: 100)
                        .blur(radius: 1.2)
                        .blendMode(.plusLighter)
                        .transition(.opacity)
                    }
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
        }
        .frame(width: 100, height: 100)
        .clipped()
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovered = hovering
            }
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
            let matrix = DotMatrixImageProcessor.generateColorDotMatrix(from: img, gridSize: 50)
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
    @State private var isBypassHovered = false
    @State private var isExportHovered = false
    
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
                    .contentShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            
            // Master Bypass A/B Comparison Toggle (Fixed 110x34pt Hardware Dimensions & Full-Surface Hit Box)
            Button(action: {
                Haptics.playClick()
                engineManager.isBypassed.toggle()
            }) {
                Text(engineManager.isBypassed ? "BYPASS: ON" : "BYPASS: OFF")
                    .font(.custom("DotGothic16-Regular", size: 13))
                    .fontWeight(.bold)
                    .frame(width: 110, height: 34)
                    .background(
                        engineManager.isBypassed
                            ? Color.red
                            : (isBypassHovered ? Color.white.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                engineManager.isBypassed
                                    ? Color.red
                                    : (isBypassHovered ? Color.white.opacity(0.8) : Color.red.opacity(0.8)),
                                lineWidth: 1
                            )
                    )
                    .foregroundColor(engineManager.isBypassed ? .black : .red)
                    .contentShape(Rectangle()) // Entire 110x34 area clickable!
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isBypassHovered = hovering
            }
            
            // Export Stems Button with Fixed 140x34pt Hardware Dimensions & Full-Surface Hit Box
            Button(action: {
                Haptics.playClick()
                engineManager.exportStems()
            }) {
                ZStack {
                    switch engineManager.exportState {
                    case .idle:
                        Text("EXPORT STEMS")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    case .exporting(let stage, let percent):
                        Text("\(stage) \(Int(percent * 100))%")
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    case .completed:
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("COMPLETED")
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    }
                }
                .font(.custom("DotGothic16-Regular", size: 13))
                .frame(width: 140, height: 34)
                .background(
                    engineManager.exportState == .completed
                        ? Color.red
                        : (engineManager.isExporting
                            ? Color.red.opacity(0.25)
                            : (isExportHovered ? Color.white.opacity(0.08) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            engineManager.exportState == .completed
                                ? Color.white
                                : (isExportHovered ? Color.white.opacity(0.8) : Color.red),
                            lineWidth: 1
                        )
                )
                .contentShape(Rectangle()) // Entire 140x34 area clickable!
            }
            .disabled(engineManager.isExporting || engineManager.exportState == .completed)
            .buttonStyle(.plain)
            .onHover { hovering in
                isExportHovered = hovering
            }
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
    @State private var animationTask: Task<Void, Never>? = nil
    
    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            let textWidth = measureTextWidth(text)
            
            Text(text)
                .font(font)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: offset)
                .frame(width: containerWidth, alignment: .leading)
                .clipped()
                .onAppear {
                    updateAnimation(containerWidth: containerWidth, textWidth: textWidth)
                }
                .onChange(of: text) { _, _ in
                    updateAnimation(containerWidth: containerWidth, textWidth: textWidth)
                }
                .onChange(of: containerWidth) { _, newWidth in
                    updateAnimation(containerWidth: newWidth, textWidth: textWidth)
                }
        }
        .frame(height: 32)
    }
    
    private func measureTextWidth(_ string: String) -> CGFloat {
        let font = NSFont(name: "DotGothic16-Regular", size: 26) ?? NSFont.monospacedSystemFont(ofSize: 26, weight: .regular)
        let attr: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((string as NSString).size(withAttributes: attr).width)
    }
    
    private func updateAnimation(containerWidth: CGFloat, textWidth: CGFloat) {
        animationTask?.cancel()
        animationTask = nil
        offset = 0
        
        let diff = textWidth - containerWidth
        guard diff > 8, containerWidth > 50 else {
            offset = 0
            return
        }
        
        animationTask = Task { @MainActor in
            let speed: CGFloat = 28.0 // px per second
            let totalTime = Double(diff / speed)
            let steps = max(1, Int(diff / 8))
            let timePerStep = totalTime / Double(steps)
            
            while !Task.isCancelled {
                // Settle at start
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { break }
                
                // Ping to end
                for step in 1...steps {
                    offset = -CGFloat(step) * (diff / CGFloat(steps))
                    try? await Task.sleep(nanoseconds: UInt64(timePerStep * 1_000_000_000))
                    guard !Task.isCancelled else { break }
                }
                offset = -diff
                
                // Settle at end
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { break }
                
                // Pong back to start
                for step in 1...steps {
                    offset = -diff + CGFloat(step) * (diff / CGFloat(steps))
                    try? await Task.sleep(nanoseconds: UInt64(timePerStep * 1_000_000_000))
                    guard !Task.isCancelled else { break }
                }
                offset = 0
            }
        }
    }
}
