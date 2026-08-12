import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct IsolateApp: App {
    @State private var engineManager = AudioEngineManager()
    @State private var isTargeted = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(engineManager)
                .modelContainer(for: TrackModel.self)
                .preferredColorScheme(.dark)
                .frame(minWidth: 950, minHeight: 600)
                .overlay {
                    if engineManager.isSplitting {
                        ZStack {
                            Color.black.opacity(0.9)
                            VStack(spacing: 20) {
                                Text(engineManager.isCompilingModel ? "OPTIMIZING NEURAL ENGINE..." : "ANALYZING STEMS...")
                                    .font(.custom("DotGothic16-Regular", size: 36))
                                    .foregroundColor(.white)
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Path { path in
                                            path.move(to: CGPoint(x: 0, y: 4))
                                            path.addLine(to: CGPoint(x: geo.size.width, y: 4))
                                        }
                                        .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 8, dash: [8, 8]))
                                        
                                        Path { path in
                                            path.move(to: CGPoint(x: 0, y: 4))
                                            path.addLine(to: CGPoint(x: max(0, geo.size.width * engineManager.splitProgress), y: 4))
                                        }
                                        .stroke(Color.red, style: StrokeStyle(lineWidth: 8, dash: [8, 8]))
                                    }
                                }
                                .frame(width: 400, height: 8)
                                
                                if !engineManager.isCompilingModel {
                                    Text("\(Int(engineManager.splitProgress * 100))%")
                                        .font(.custom("DotGothic16-Regular", size: 24))
                                        .foregroundColor(.red)
                                } else {
                                    Text("FIRST RUN ONLY. THIS TAKES 30 SECS.")
                                        .font(.custom("DotGothic16-Regular", size: 16))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .ignoresSafeArea()
                    } else if isTargeted {
                        ZStack {
                            Color.black.opacity(0.8)
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red, style: StrokeStyle(lineWidth: 4, dash: [10]))
                                .padding(20)
                            VStack(spacing: 20) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 64))
                                    .foregroundColor(.red)
                                Text("DROP TRACK TO LOAD")
                                    .font(.custom("DotGothic16-Regular", size: 36))
                                    .foregroundColor(.red)
                            }
                        }
                        .ignoresSafeArea()
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    if let provider = providers.first {
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                                handleDroppedFile(url: url)
                            } else if let url = item as? URL {
                                handleDroppedFile(url: url)
                            }
                        }
                        return true
                    }
                    return false
                }
        }
        .windowResizability(.contentSize)
    }
    
    private func handleDroppedFile(url: URL) {
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

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            LibraryView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            PlayerView()
        }
    }
}
