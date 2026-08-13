import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngineManager.self) private var engineManager
    @Query(sort: \TrackModel.dateAdded, order: .reverse) private var tracks: [TrackModel]
    
    @State private var trackToRename: TrackModel?
    @State private var renameText: String = ""
    @State private var isShowingRenameModal = false
    
    @State private var trackToDelete: TrackModel?
    @State private var isShowingDeleteModal = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header & Import Button
                VStack(alignment: .leading, spacing: 14) {
                    Text("LIBRARY")
                        .font(.custom("DotGothic16-Regular", size: 14))
                        .foregroundColor(.gray)
                    
                    Button(action: importTrack) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
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
                                    onSelect: {
                                        Task {
                                            await engineManager.loadTrack(track)
                                        }
                                    },
                                    onRename: {
                                        trackToRename = track
                                        renameText = track.title
                                        isShowingRenameModal = true
                                    },
                                    onDelete: {
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
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
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
            
            // 3-Dots Action Menu
            Menu {
                Button(action: onRename) {
                    Label("Rename Track", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Track", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isHovered ? .white : .gray)
                    .frame(width: 28, height: 28)
                    .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
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
