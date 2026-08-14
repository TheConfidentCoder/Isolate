import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import AVFoundation

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngineManager.self) private var engineManager
    @Query(sort: \TrackModel.dateAdded, order: .reverse) private var tracks: [TrackModel]
    
    @Binding var activeMenuTrackID: String?
    var onRenameTrack: ((TrackModel) -> Void)? = nil
    var onDeleteTrack: ((TrackModel) -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil
    
    @State private var isSettingsHovered = false
    
    // Custom Nothing Scrollbar State
    @State private var containerHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolling = false
    @State private var isScrollbarHovered = false
    @State private var isDraggingScrollbar = false
    @State private var scrollFadeTimer: Timer? = nil
    
    // Telemetry Duration State
    @State private var totalDurationSeconds: Double = 0.0
    
    public init(
        activeMenuTrackID: Binding<String?> = .constant(nil),
        onRenameTrack: ((TrackModel) -> Void)? = nil,
        onDeleteTrack: ((TrackModel) -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil
    ) {
        self._activeMenuTrackID = activeMenuTrackID
        self.onRenameTrack = onRenameTrack
        self.onDeleteTrack = onDeleteTrack
        self.onOpenSettings = onOpenSettings
    }
    
    var totalOriginalBytes: Int64 {
        tracks.reduce(0) { total, track in
            let size = (try? FileManager.default.attributesOfItem(atPath: track.originalURL.path)[.size] as? Int64) ?? 0
            return total + size
        }
    }
    
    var formattedTotalSize: String {
        let bytes = totalOriginalBytes
        let mb = Double(bytes) / 1_000_000.0
        if mb >= 1000.0 {
            let gb = Double(bytes) / 1_000_000_000.0
            return String(format: "%.2f GB", gb)
        } else {
            return String(format: "%.1f MB", mb)
        }
    }
    
    var formattedTotalDuration: String {
        let totalMins = Int(round(totalDurationSeconds / 60.0))
        if totalMins < 60 {
            return "\(max(1, totalMins)) MIN"
        } else {
            let hours = totalMins / 60
            let mins = totalMins % 60
            return "\(hours)H \(mins)M"
        }
    }
    
    private func triggerScrollActivity() {
        isScrolling = true
        scrollFadeTimer?.invalidate()
        scrollFadeTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { _ in
            Task { @MainActor in
                isScrolling = false
            }
        }
    }
    
    private func recalculateTotalDuration() {
        let urlPairs: [(vocal: URL, original: URL)] = tracks.map { ($0.vocalStemURL, $0.originalURL) }
        Task.detached(priority: .userInitiated) {
            var totalSecs: Double = 0.0
            for pair in urlPairs {
                if let file = try? AVAudioFile(forReading: pair.vocal) {
                    totalSecs += Double(file.length) / file.processingFormat.sampleRate
                } else if let file = try? AVAudioFile(forReading: pair.original) {
                    totalSecs += Double(file.length) / file.processingFormat.sampleRate
                }
            }
            let finalSecs = totalSecs
            await MainActor.run {
                self.totalDurationSeconds = finalSecs
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header: Title & Quick Import Track Button
                HStack {
                    Text("LIBRARY")
                        .font(.custom("DotGothic16-Regular", size: 14))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button(action: {
                        Haptics.playClick()
                        importTrack()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("IMPORT TRACK")
                        }
                        .font(.custom("DotGothic16-Regular", size: 14))
                        .foregroundColor(.red)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Track List with Custom Nothing Hardware Scrollbar
                if tracks.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("NO TRACKS IMPORTED")
                            .font(.custom("DotGothic16-Regular", size: 13))
                            .foregroundColor(.gray)
                        Text("Drag & drop audio files here")
                            .font(.custom("DotGothic16-Regular", size: 11))
                            .foregroundColor(.gray.opacity(0.7))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    GeometryReader { containerGeo in
                        ZStack(alignment: .trailing) {
                            ScrollView {
                                VStack(spacing: 6) {
                                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                        let isCurrentMenuOpen = activeMenuTrackID == track.id
                                        let zIndexValue: Double = isCurrentMenuOpen ? 1000.0 : Double(tracks.count - index)
                                        TrackRowView(
                                            track: track,
                                            isActive: engineManager.currentTrackID == track.id || engineManager.currentTrackName == track.title.uppercased(),
                                            isMenuOpen: isCurrentMenuOpen,
                                            onToggleMenu: {
                                                if activeMenuTrackID == track.id {
                                                    activeMenuTrackID = nil
                                                } else {
                                                    activeMenuTrackID = track.id
                                                }
                                            },
                                            onSelect: {
                                                activeMenuTrackID = nil
                                                Task {
                                                    await engineManager.loadTrack(track)
                                                }
                                            },
                                            onRename: {
                                                activeMenuTrackID = nil
                                                onRenameTrack?(track)
                                            },
                                            onDelete: {
                                                activeMenuTrackID = nil
                                                onDeleteTrack?(track)
                                            }
                                        )
                                        .zIndex(zIndexValue)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    GeometryReader { contentGeo in
                                        Color.clear
                                            .preference(key: ContentHeightPreferenceKey.self, value: contentGeo.size.height)
                                            .preference(key: ScrollOffsetPreferenceKey.self, value: contentGeo.frame(in: .named("LibraryScroll")).minY)
                                    }
                                )
                            }
                            .coordinateSpace(name: "LibraryScroll")
                            .scrollIndicators(.hidden) // Replaces default macOS scrollbar!
                            
                            // Custom Nothing Hardware Red LED Scrollbar (2.5pt wide, dark track, rounded micro-pill)
                            if contentHeight > containerHeight && containerHeight > 0 {
                                let trackHeight = max(10, containerHeight - 12)
                                let thumbRatio = min(1.0, containerHeight / max(1, contentHeight))
                                let thumbHeight = max(24.0, trackHeight * thumbRatio)
                                let maxScroll = max(1.0, contentHeight - containerHeight)
                                let currentProgress = max(0.0, min(1.0, -scrollOffset / maxScroll))
                                let thumbOffset = currentProgress * (trackHeight - thumbHeight)
                                
                                ZStack(alignment: .top) {
                                    // Dark track rail along the right edge
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(width: 2.5, height: trackHeight)
                                    
                                    // Discrete Nothing Red LED Thumb
                                    RoundedRectangle(cornerRadius: 1.25)
                                        .fill(Color.red)
                                        .frame(width: 2.5, height: thumbHeight)
                                        .offset(y: thumbOffset)
                                        .shadow(color: Color.red.opacity(isScrolling || isScrollbarHovered || isDraggingScrollbar ? 0.6 : 0.0), radius: 4, x: 0, y: 0)
                                }
                                .frame(width: 8, height: trackHeight)
                                .contentShape(Rectangle())
                                .padding(.trailing, 3)
                                .opacity((isScrolling || isScrollbarHovered || isDraggingScrollbar) ? 1.0 : 0.35)
                                .animation(.easeInOut(duration: 0.2), value: isScrolling)
                                .animation(.easeInOut(duration: 0.2), value: isScrollbarHovered)
                                .onHover { hovering in
                                    isScrollbarHovered = hovering
                                }
                            }
                        }
                        .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                            contentHeight = height
                        }
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                            scrollOffset = offset
                            triggerScrollActivity()
                        }
                        .onAppear {
                            containerHeight = containerGeo.size.height
                            recalculateTotalDuration()
                        }
                        .onChange(of: containerGeo.size.height) { _, newHeight in
                            containerHeight = newHeight
                        }
                        .onChange(of: tracks.count) { _, _ in
                            recalculateTotalDuration()
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if activeMenuTrackID != nil {
                            activeMenuTrackID = nil
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.12))
                
                // Bottom Footer: Telemetry (Tracks • Total Size • Total Duration) & Nothing Settings Button
                HStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(tracks.count) \(tracks.count == 1 ? "TRACK" : "TRACKS")")
                            .font(.custom("DotGothic16-Regular", size: 10.5))
                            .foregroundColor(.gray.opacity(0.8))
                        
                        if totalOriginalBytes > 0 {
                            Text("•")
                                .font(.custom("DotGothic16-Regular", size: 9))
                                .foregroundColor(.red)
                            
                            Text(formattedTotalSize)
                                .font(.custom("DotGothic16-Regular", size: 10.5))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        
                        if totalDurationSeconds > 0 {
                            Text("•")
                                .font(.custom("DotGothic16-Regular", size: 9))
                                .foregroundColor(.red)
                            
                            Text(formattedTotalDuration)
                                .font(.custom("DotGothic16-Regular", size: 10.5))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    
                    Spacer(minLength: 4)
                    
                    Button(action: {
                        Haptics.playClick()
                        onOpenSettings?()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10, weight: .bold))
                            Text("SETTINGS")
                                .font(.custom("DotGothic16-Regular", size: 11))
                                .fontWeight(.bold)
                        }
                        .foregroundColor(isSettingsHovered ? .white : .gray)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(isSettingsHovered ? Color.white.opacity(0.08) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(isSettingsHovered ? Color.white.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering && !isSettingsHovered { Haptics.playClick() }
                        isSettingsHovered = hovering
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.95))
            }
            .background(Color.black.opacity(0.85))
            .contentShape(Rectangle())
            .onTapGesture {
                if activeMenuTrackID != nil {
                    activeMenuTrackID = nil
                }
            }
        }
    }
    
    private func importTrack() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .audio,
            .mp3,
            .mpeg4Audio,
            .wav,
            .aiff,
            UTType(filenameExtension: "flac") ?? .audio,
            UTType(filenameExtension: "alac") ?? .audio,
            UTType(filenameExtension: "aac") ?? .audio,
            UTType(filenameExtension: "caf") ?? .audio
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                let path = url.path
                let descriptor = FetchDescriptor<TrackModel>(predicate: #Predicate { $0.id == path })
                if let existing = try? modelContext.fetch(descriptor).first {
                    await engineManager.loadTrack(existing)
                } else {
                    if let data = await engineManager.loadAndSplitAudio(url: url) {
                        await MainActor.run {
                            let newTrack = TrackModel(
                                id: data.id,
                                title: data.title,
                                originalURL: data.originalURL,
                                vocalStemURL: data.vocalStemURL,
                                bassStemURL: data.bassStemURL,
                                drumStemURL: data.drumStemURL,
                                otherStemURL: data.otherStemURL
                            )
                            modelContext.insert(newTrack)
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
    }
}

struct TrackRowView: View {
    let track: TrackModel
    let isActive: Bool
    let isMenuOpen: Bool
    let onToggleMenu: () -> Void
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var isRenameHovered = false
    @State private var isDeleteHovered = false
    
    private var dotColor: Color {
        if isMenuOpen {
            return Color.red
        } else if isHovered {
            return Color.white
        } else {
            return Color.gray.opacity(0.7)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Main Track Click Area
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.custom("DotGothic16-Regular", size: 15))
                        .foregroundColor(isActive ? .red : .white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(track.dateAdded, style: .date)
                            .font(.custom("DotGothic16-Regular", size: 11))
                            .foregroundColor(.gray)
                        
                        if isActive {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Nothing Hardware 3-Dots Action Button
            Button(action: {
                Haptics.playClick()
                onToggleMenu()
            }) {
                HStack(spacing: 2.5) {
                    Circle().fill(dotColor).frame(width: 3, height: 3)
                    Circle().fill(dotColor).frame(width: 3, height: 3)
                    Circle().fill(dotColor).frame(width: 3, height: 3)
                }
                .frame(width: 24, height: 24)
                .background(isMenuOpen ? Color.red.opacity(0.18) : (isHovered ? Color.white.opacity(0.08) : Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isMenuOpen ? Color.red : (isHovered ? Color.white.opacity(0.25) : Color.clear), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                if isMenuOpen {
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            Haptics.playClick()
                            onRename()
                        }) {
                            HStack(spacing: 6) {
                                Text("[ RENAME ]")
                                    .font(.custom("DotGothic16-Regular", size: 12))
                                    .fontWeight(.bold)
                                    .foregroundColor(isRenameHovered ? .black : .white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(isRenameHovered ? Color.red : Color.black)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering && !isRenameHovered { Haptics.playClick() }
                            isRenameHovered = hovering
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.18))
                        
                        Button(action: {
                            Haptics.playClick()
                            onDelete()
                        }) {
                            HStack(spacing: 6) {
                                Text("[ DELETE ]")
                                    .font(.custom("DotGothic16-Regular", size: 12))
                                    .fontWeight(.bold)
                                    .foregroundColor(isDeleteHovered ? .black : .red)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(isDeleteHovered ? Color.red : Color.black)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering && !isDeleteHovered { Haptics.playClick() }
                            isDeleteHovered = hovering
                        }
                    }
                    .frame(width: 120)
                    .background(Color.black)
                    .compositingGroup()
                    .border(Color.white.opacity(0.22), width: 1)
                    .overlay(CornerBrackets())
                    .offset(x: 0, y: 28) // Positioned directly below 3-dots button
                    .shadow(color: Color.black, radius: 10, x: 0, y: 4)
                    .zIndex(1000)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isActive ? Color.red.opacity(0.12) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
        .border(isActive ? Color.red.opacity(0.4) : Color.clear, width: 1)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Scroll Position and Content Height Preference Keys
struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
