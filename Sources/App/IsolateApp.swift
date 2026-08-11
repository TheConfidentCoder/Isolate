import SwiftUI
import SwiftData

@main
struct IsolateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // Force dark mode as requested
                .frame(minWidth: 800, minHeight: 600) // Fixed minimum size
        }
        .windowResizability(.contentMinSize) // Allow resizing above minimum
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
