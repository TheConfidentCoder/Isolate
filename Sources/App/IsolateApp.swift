import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct IsolateApp: App {
    @State private var engineManager = AudioEngineManager()
    @State private var isTargeted = false
    @Environment(\.modelContext) private var modelContext
    
    init() {
        // Pre-warm CoreML Demucs Neural Engine pipeline in the background on startup
        Task.detached(priority: .userInitiated) {
            await DemucsEngine.shared.prewarmModel()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(engineManager)
                .modelContainer(for: TrackModel.self)
                .preferredColorScheme(.dark)
                .frame(minWidth: 960, minHeight: 600)
                .overlay {
                    if engineManager.isSplitting {
                        // Detailed AI Stem Splitting Progress Modal
                        ZStack {
                            Color.black.opacity(0.92)
                            
                            VStack(spacing: 24) {
                                // Header Status
                                Text(engineManager.splitStatusMessage)
                                    .font(.custom("DotGothic16-Regular", size: 26))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                // Discrete LED Hardware Progress Bar
                                ModalDotMatrixProgressBar(progress: engineManager.splitProgress)
                                    .frame(width: 440, height: 10)
                                
                                // Metrics Readout
                                HStack(spacing: 36) {
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("PROGRESS")
                                            .font(.custom("DotGothic16-Regular", size: 12))
                                            .foregroundColor(.gray)
                                        Text("\(Int(engineManager.splitProgress * 100))%")
                                            .font(.custom("DotGothic16-Regular", size: 22))
                                            .foregroundColor(.red)
                                    }
                                    
                                    if engineManager.totalChunkCount > 0 {
                                        VStack(alignment: .center, spacing: 4) {
                                            Text("CHUNKS")
                                                .font(.custom("DotGothic16-Regular", size: 12))
                                                .foregroundColor(.gray)
                                            Text("\(engineManager.currentChunkNumber)/\(engineManager.totalChunkCount)")
                                                .font(.custom("DotGothic16-Regular", size: 22))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("ESTIMATED TIME")
                                            .font(.custom("DotGothic16-Regular", size: 12))
                                            .foregroundColor(.gray)
                                        Text(engineManager.etaRemainingString)
                                            .font(.custom("DotGothic16-Regular", size: 22))
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Text("APPLE SILICON NEURAL ENGINE ACCELERATED")
                                    .font(.custom("DotGothic16-Regular", size: 12))
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                            .padding(40)
                            .background(Color.black.opacity(0.9))
                            .border(Color.white.opacity(0.18), width: 1)
                            .overlay(CornerBrackets())
                        }
                        .ignoresSafeArea()
                    } else if isTargeted {
                        // Drag & Drop Target Overlay
                        ZStack {
                            Color.black.opacity(0.85)
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red, style: StrokeStyle(lineWidth: 4, dash: [10]))
                                .padding(24)
                            VStack(spacing: 20) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 64))
                                    .foregroundColor(.red)
                                Text("DROP AUDIO TO ISOLATE STEMS")
                                    .font(.custom("DotGothic16-Regular", size: 32))
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

struct ModalDotMatrixProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geo in
            let blockWidth: CGFloat = 8.0
            let blockSpacing: CGFloat = 4.0
            let totalUnitWidth = blockWidth + blockSpacing
            let blockCount = max(1, Int(geo.size.width / totalUnitWidth))
            let activeCount = Int(round(Double(blockCount) * max(0, min(1, progress))))
            
            HStack(spacing: blockSpacing) {
                ForEach(0..<blockCount, id: \.self) { i in
                    Rectangle()
                        .fill(i < activeCount ? Color.red : Color.white.opacity(0.15))
                        .frame(width: blockWidth, height: 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            LibraryView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 280)
        } detail: {
            PlayerView()
        }
    }
}
