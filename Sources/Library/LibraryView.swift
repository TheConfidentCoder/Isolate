import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngineManager.self) private var engineManager
    @Query(sort: \TrackModel.dateAdded, order: .reverse) private var tracks: [TrackModel]
    
    @Binding var activeMenuTrackID: String?
    var onRenameTrack: ((TrackModel) -> Void)? = nil
    var onDeleteTrack: ((TrackModel) -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil
    
    @State private var isSettingsHovered = false
    
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
                
                // Track List
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
                
                // Bottom Footer: Track Count & Nothing-Styled Settings Button
                HStack {
                    Text("\(tracks.count) \(tracks.count == 1 ? "TRACK" : "TRACKS")")
                        .font(.custom("DotGothic16-Regular", size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Spacer()
                    
                    Button(action: {
                        Haptics.playClick()
                        onOpenSettings?()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11, weight: .bold))
                            Text("SETTINGS")
                                .font(.custom("DotGothic16-Regular", size: 12))
                                .fontWeight(.bold)
                        }
                        .foregroundColor(isSettingsHovered ? .white : .gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
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
        panel.allowedContentTypes = [.audio]
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
                    Circle().fill(isMenuOpen ? Color.red : (isHovered ? Color.white : Color.gray.opacity(0.7))).frame(width: 3, height: 3)
                    Circle().fill(isMenuOpen ? Color.red : (isHovered ? Color.white : Color.gray.opacity(0.7))).frame(width: 3, height: 3)
                    Circle().fill(isMenuOpen ? Color.red : (isHovered ? Color.white : Color.gray.opacity(0.7))).frame(width: 3, height: 3)
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
