import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@main
struct IsolateApp: App {
    @State private var engineManager = AudioEngineManager()
    @State private var isTargeted = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(engineManager)
                .preferredColorScheme(.dark)
                .frame(minWidth: 800, minHeight: 600)
                .overlay {
                    if isTargeted {
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
                                Task { @MainActor in
                                    engineManager.loadAudio(url: url)
                                }
                            } else if let url = item as? URL {
                                Task { @MainActor in
                                    engineManager.loadAudio(url: url)
                                }
                            }
                        }
                        return true
                    }
                    return false
                }
        }
        .windowResizability(.contentMinSize)
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
