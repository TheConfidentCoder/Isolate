import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngineManager.self) private var engineManager
    @Query(sort: \TrackModel.dateAdded, order: .reverse) private var tracks: [TrackModel]
    
    var body: some View {
        List {
            Section("LIBRARY") {
                Button(action: importTrack) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("IMPORT TRACK")
                    }
                    .font(.custom("DotGothic16-Regular", size: 14))
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                
                if tracks.isEmpty {
                    Text("Drag & Drop Audio Files Here")
                        .font(.custom("DotGothic16-Regular", size: 14))
                        .foregroundColor(.gray)
                } else {
                    ForEach(tracks) { track in
                        Button(action: {
                            Task {
                                await engineManager.loadTrack(track)
                            }
                        }) {
                            VStack(alignment: .leading) {
                                Text(track.title)
                                    .font(.custom("DotGothic16-Regular", size: 16))
                                    .foregroundColor(.white)
                                Text(track.dateAdded, style: .date)
                                    .font(.custom("DotGothic16-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                modelContext.delete(track)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(white: 0.1))
        .scrollContentBackground(.hidden)
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
                        }
                    }
                }
            }
        }
    }
}
