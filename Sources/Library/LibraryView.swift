import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngineManager.self) private var engineManager
    @Query(sort: \TrackModel.dateAdded, order: .reverse) private var tracks: [TrackModel]
    
    @State private var isShowingRenameModal = false
    @State private var isShowingDeleteModal = false
    @State private var trackToRename: TrackModel? = nil
    @State private var trackToDelete: TrackModel? = nil
    @State private var renameText = ""
    @State private var activeMenuTrackID: String? = nil
    
    public init() {}
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header: Title & Quick Import Track Button
                HStack {
                    Text("LIBRARY")
                        .font(.custom("DotGothic16-Regular", size: 14))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button(action: importTrack) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("IMPORT TRACK")
                        }
                        .font(.custom("DotGothic16-Regular", size: 14))
                        .foregroundColor(.red)
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
                        LazyVStack(spacing: 6) {
                            ForEach(tracks) { track in
                                TrackRowView(
                                    track: track,
                                    isActive: engineManager.currentTrackName == track.title.uppercased(),
                                    isMenuOpen: activeMenuTrackID == track.id,
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
                                        trackToRename = track
                                        renameText = track.title
                                        isShowingRenameModal = true
                                    },
                                    onDelete: {
                                        activeMenuTrackID = nil
                                        trackToDelete = track
                                        isShowingDeleteModal = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(Color.black.opacity(0.85))
            .onTapGesture {
                if activeMenuTrackID != nil {
                    activeMenuTrackID = nil
                }
            }
            
            // MARK: - Nothing-Style Rename Modal
            if isShowingRenameModal, let track = trackToRename {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isShowingRenameModal = false
                        }
                    
                    VStack(spacing: 20) {
                        Text("RENAME TRACK")
                            .font(.custom("DotGothic16-Regular", size: 18))
                            .foregroundColor(.white)
                        
                        TextField("Track Title", text: $renameText)
                            .font(.custom("DotGothic16-Regular", size: 15))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 16) {
                            Button("CANCEL") {
                                isShowingRenameModal = false
                            }
                            .font(.custom("DotGothic16-Regular", size: 13))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                            .foregroundColor(.gray)
                            .buttonStyle(.plain)
                            
                            Button("SAVE") {
                                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    track.title = trimmed
                                    try? modelContext.save()
                                    if engineManager.currentTrackName == track.title.uppercased() || engineManager.currentTrackName.contains(track.id) {
                                        engineManager.currentTrackName = trimmed.uppercased()
                                    }
                                }
                                isShowingRenameModal = false
                            }
                            .font(.custom("DotGothic16-Regular", size: 13))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(28)
                    .frame(width: 340)
                    .background(Color.black.opacity(0.95))
                    .border(Color.white.opacity(0.2), width: 1)
                    .overlay(CornerBrackets())
                }
            }
            
            // MARK: - Delete Confirmation Modal
            if isShowingDeleteModal, let track = trackToDelete {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isShowingDeleteModal = false
                        }
                    
                    VStack(spacing: 18) {
                        Text("DELETE TRACK?")
                            .font(.custom("DotGothic16-Regular", size: 18))
                            .foregroundColor(.red)
                        
                        Text("Are you sure you want to delete '\(track.title)' and its isolated stems?")
                            .font(.custom("DotGothic16-Regular", size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Button("CANCEL") {
                                isShowingDeleteModal = false
                            }
                            .font(.custom("DotGothic16-Regular", size: 13))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                            .foregroundColor(.gray)
                            .buttonStyle(.plain)
                            
                            Button("DELETE") {
                                // Delete stem files from disk
                                try? FileManager.default.removeItem(at: track.vocalStemURL)
                                try? FileManager.default.removeItem(at: track.drumStemURL)
                                try? FileManager.default.removeItem(at: track.bassStemURL)
                                try? FileManager.default.removeItem(at: track.otherStemURL)
                                
                                modelContext.delete(track)
                                try? modelContext.save()
                                isShowingDeleteModal = false
                            }
                            .font(.custom("DotGothic16-Regular", size: 13))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(28)
                    .frame(width: 340)
                    .background(Color.black.opacity(0.95))
                    .border(Color.white.opacity(0.2), width: 1)
                    .overlay(CornerBrackets())
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
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                // Main Track Click Area
                Button(action: {
                    if isMenuOpen {
                        onToggleMenu()
                    } else {
                        onSelect()
                    }
                }) {
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
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? Color.red.opacity(0.12) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            .border(isActive ? Color.red.opacity(0.4) : Color.clear, width: 1)
            .onHover { hovering in
                isHovered = hovering
            }
            
            // In-View Flat Nothing Hardware Overlay (Zero Liquid Glass / Zero Popover Bubble)
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
                        .padding(.vertical, 7)
                        .background(isRenameHovered ? Color.red : Color.clear)
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
                        .padding(.vertical, 7)
                        .background(isDeleteHovered ? Color.red : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering && !isDeleteHovered { Haptics.playClick() }
                        isDeleteHovered = hovering
                    }
                }
                .frame(width: 120)
                .background(Color(white: 0.08))
                .border(Color.white.opacity(0.22), width: 1)
                .overlay(CornerBrackets())
                .offset(x: -28, y: 0)
                .zIndex(100)
                .shadow(color: Color.black.opacity(0.9), radius: 6, x: 0, y: 3)
            }
        }
    }
}
