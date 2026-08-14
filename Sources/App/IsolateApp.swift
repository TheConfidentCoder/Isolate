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
                .overlay {
                    if engineManager.isSplitting {
                        SplittingProgressModal()
                            .environment(engineManager)
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
                .preferredColorScheme(.dark)
                .frame(minWidth: 960, minHeight: 600)
                .background(WindowAccessor())
                .navigationTitle("")
                .environment(engineManager)
        }
        .modelContainer(for: TrackModel.self)
        .environment(engineManager)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
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

// MARK: - Splitting Progress Modal with Cancel Import Action
struct SplittingProgressModal: View {
    @Environment(AudioEngineManager.self) private var engineManager
    @State private var isCancelHovered = false
    @State private var currentHeadlineIndex = 0
    @State private var currentFooterIndex = 0
    @State private var isBlinking = false
    @State private var rotationTimer: Timer? = nil
    @State private var blinkTimer: Timer? = nil
    
    private var dynamicHeadline: String {
        let progress = engineManager.splitProgress
        if progress <= 0.005 {
            return "INITIALIZING NEURAL ENGINE..."
        } else if progress >= 0.98 {
            return "RECOMBINING STEM MATRIX..."
        } else if progress < 0.35 {
            let earlyPool = [
                "HUNTING DOWN THE 808 SUB BASS...",
                "DE-BLEEDING DRUM TRANSIENTS...",
                "SEPARATING SINE WAVES FROM SOUL...",
                "ISOLATING THE GHOST IN THE MACHINE..."
            ]
            return earlyPool[currentHeadlineIndex % earlyPool.count]
        } else if progress < 0.75 {
            let midPool = [
                "SURGICALLY EXTRACTING VOCALS...",
                "UNTANGLING HARMONIC RESONANCE...",
                "CONSULTING THE NEURAL ENGINE ORACLE...",
                "PURGING BACKGROUND BLEED..."
            ]
            return midPool[currentHeadlineIndex % midPool.count]
        } else {
            let latePool = [
                "POLISHING ISOLATED ARTIFACTS...",
                "FILTERING RESIDUAL PHANTOM FREQUENCIES...",
                "ALMOST AT 100% PURITY..."
            ]
            return latePool[currentHeadlineIndex % latePool.count]
        }
    }
    
    private var dynamicFooter: String {
        let telemetryPool = [
            "APPLE SILICON NEURAL ENGINE ACCELERATED",
            "DEMUCS V4 COREML • FP16 QUANTIZED",
            "44.1KHZ 16-BIT STEREO PRECISION MATRIX",
            "HYBRID TRANSFORMER LATENCY 0.38X REALTIME",
            "4-STEM ISOLATION • DUAL-CHANNEL DSP"
        ]
        return telemetryPool[currentFooterIndex % telemetryPool.count]
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
            
            VStack(spacing: 24) {
                // Header Status: Rotating Nothing-Themed Quirky Headlines (0ms Snap)
                Text(dynamicHeadline)
                    .font(.custom("DotGothic16-Regular", size: 22))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 32)
                
                // Discrete LED Hardware Progress Bar
                ModalDotMatrixProgressBar(progress: engineManager.splitProgress)
                    .frame(width: 480, height: 10)
                
                // Metrics Readout
                HStack(spacing: 48) {
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
                
                // Footer Status: Dynamic Hardware Telemetry with Pulsing REC LED
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .opacity(isBlinking ? 1.0 : 0.2)
                    
                    Text(dynamicFooter)
                        .font(.custom("DotGothic16-Regular", size: 12))
                        .foregroundColor(.gray.opacity(0.85))
                        .lineLimit(1)
                }
                .frame(minHeight: 20)
                
                // Prominent Bottom Nothing-Style Cancel Action Button
                Button(action: {
                    Haptics.playClick()
                    engineManager.cancelSplitAudio()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("CANCEL IMPORT")
                            .font(.custom("DotGothic16-Regular", size: 13))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(isCancelHovered ? .black : .red)
                    .frame(width: 170, height: 36)
                    .background(isCancelHovered ? Color.red : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isCancelHovered ? Color.red : Color.red.opacity(0.8), lineWidth: 1)
                    )
                    .contentShape(Rectangle()) // Entire 170x36 area clickable!
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .onHover { hovering in
                    if hovering && !isCancelHovered { Haptics.playClick() }
                    isCancelHovered = hovering
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 36)
            .frame(width: 580)
            .background(Color.black.opacity(0.95))
            .border(Color.white.opacity(0.18), width: 1)
            .overlay(CornerBrackets())
        }
        .ignoresSafeArea()
        .onAppear {
            rotationTimer?.invalidate()
            rotationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                Haptics.playAlignment()
                currentHeadlineIndex += 1
                currentFooterIndex += 1
            }
            
            blinkTimer?.invalidate()
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                isBlinking.toggle()
            }
        }
        .onDisappear {
            rotationTimer?.invalidate()
            rotationTimer = nil
            blinkTimer?.invalidate()
            blinkTimer = nil
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
    @State private var isSidebarVisible = true
    @State private var trackToRename: TrackModel? = nil
    @State private var trackToDelete: TrackModel? = nil
    @State private var isShowingRenameModal = false
    @State private var isShowingDeleteModal = false
    @State private var renameText = ""
    @State private var activeMenuTrackID: String? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioEngineManager.self) private var engineManager
    
    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                LibraryView(
                    activeMenuTrackID: $activeMenuTrackID,
                    onRenameTrack: { track in
                        activeMenuTrackID = nil
                        trackToRename = track
                        renameText = track.title
                        isShowingRenameModal = true
                    },
                    onDeleteTrack: { track in
                        activeMenuTrackID = nil
                        trackToDelete = track
                        isShowingDeleteModal = true
                    }
                )
                .frame(width: 270)
                .transition(.identity) // 0ms Instant Nothing Hardware Snap
                
                Divider()
                    .background(Color.white.opacity(0.12))
            }
            
            PlayerView(isSidebarVisible: $isSidebarVisible)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    // Tap anywhere in PlayerView to dismiss active 3-dots library menu
                    if activeMenuTrackID != nil {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                activeMenuTrackID = nil
                            }
                    }
                }
        }
        .background(Color.black)
        .overlay {
            // MARK: - Window-Centered Nothing-Style Rename Modal
            if isShowingRenameModal, let track = trackToRename {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isShowingRenameModal = false
                        }
                    
                    RenameModalCard(
                        trackTitle: track.title,
                        renameText: $renameText,
                        onCancel: {
                            isShowingRenameModal = false
                        },
                        onSave: { newTitle in
                            track.title = newTitle
                            try? modelContext.save()
                            if engineManager.currentTrackName == track.title.uppercased() || engineManager.currentTrackName.contains(track.id) {
                                engineManager.currentTrackName = newTitle.uppercased()
                            }
                            isShowingRenameModal = false
                        }
                    )
                }
            } else if isShowingDeleteModal, let track = trackToDelete {
                // MARK: - Window-Centered Nothing-Style Delete Confirmation Modal
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isShowingDeleteModal = false
                        }
                    
                    DeleteModalCard(
                        trackTitle: track.title,
                        onCancel: {
                            isShowingDeleteModal = false
                        },
                        onDelete: {
                            try? FileManager.default.removeItem(at: track.vocalStemURL)
                            try? FileManager.default.removeItem(at: track.drumStemURL)
                            try? FileManager.default.removeItem(at: track.bassStemURL)
                            try? FileManager.default.removeItem(at: track.otherStemURL)
                            
                            modelContext.delete(track)
                            try? modelContext.save()
                            isShowingDeleteModal = false
                        }
                    )
                }
            } else if AppMoveHelper.shared.shouldShowMoveModal && !engineManager.isSplitting {
                // MARK: - Window-Centered Move to Applications Prompt
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                        .onTapGesture {
                            UserDefaults.standard.set(true, forKey: "hasDeclinedMoveToApplications")
                            AppMoveHelper.shared.shouldShowMoveModal = false
                        }
                    
                    MoveToApplicationsModalCard(
                        appMoveHelper: AppMoveHelper.shared,
                        onDismiss: {
                            UserDefaults.standard.set(true, forKey: "hasDeclinedMoveToApplications")
                            AppMoveHelper.shared.shouldShowMoveModal = false
                        }
                    )
                }
            }
        }
        .onAppear {
            AppMoveHelper.shared.checkLocationOnStartup()
        }
    }
}

// MARK: - Move to Applications Modal Card
struct MoveToApplicationsModalCard: View {
    @ObservedObject var appMoveHelper: AppMoveHelper
    let onDismiss: () -> Void
    
    @State private var isInstallHovered = false
    @State private var isSkipHovered = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.app")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.red)
                Text("MOVE TO APPLICATIONS?")
                    .font(.custom("DotGothic16-Regular", size: 20))
                    .foregroundColor(.white)
            }
            
            Text("Isolate works best when installed in your Applications folder.\nWould you like to move it now and eject the installer?")
                .font(.custom("DotGothic16-Regular", size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            if let error = appMoveHelper.moveErrorMessage {
                Text(error)
                    .font(.custom("DotGothic16-Regular", size: 11))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                // Skip Button
                Button(action: {
                    Haptics.playClick()
                    onDismiss()
                }) {
                    Text("NOT NOW")
                        .font(.custom("DotGothic16-Regular", size: 13))
                        .fontWeight(.bold)
                        .foregroundColor(isSkipHovered ? .white : .gray)
                        .frame(width: 120, height: 36)
                        .background(isSkipHovered ? Color.white.opacity(0.12) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(isSkipHovered ? Color.white : Color.gray.opacity(0.6), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .onHover { hovering in
                    if hovering && !isSkipHovered { Haptics.playClick() }
                    isSkipHovered = hovering
                }
                
                // Move Button
                Button(action: {
                    Haptics.playClick()
                    appMoveHelper.moveToApplications()
                }) {
                    HStack(spacing: 6) {
                        if appMoveHelper.isMoving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        Text(appMoveHelper.isMoving ? "INSTALLING..." : "MOVE & RELAUNCH")
                            .font(.custom("DotGothic16-Regular", size: 13))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(isInstallHovered ? .black : .white)
                    .frame(width: 180, height: 36)
                    .background(isInstallHovered ? Color.white : Color.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.red, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(appMoveHelper.isMoving)
                .onHover { hovering in
                    if hovering && !isInstallHovered { Haptics.playClick() }
                    isInstallHovered = hovering
                }
            }
        }
        .padding(32)
        .frame(width: 440)
        .background(Color.black.opacity(0.96))
        .border(Color.white.opacity(0.2), width: 1)
        .overlay(CornerBrackets())
    }
}

// MARK: - Window-Centered Rename Modal Card
struct RenameModalCard: View {
    let trackTitle: String
    @Binding var renameText: String
    let onCancel: () -> Void
    let onSave: (String) -> Void
    
    @State private var isCancelHovered = false
    @State private var isSaveHovered = false
    
    var body: some View {
        VStack(spacing: 22) {
            Text("RENAME TRACK")
                .font(.custom("DotGothic16-Regular", size: 20))
                .foregroundColor(.white)
            
            TextField("Track Title", text: $renameText)
                .font(.custom("DotGothic16-Regular", size: 15))
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1))
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                // Cancel Button
                Button(action: {
                    Haptics.playClick()
                    onCancel()
                }) {
                    Text("CANCEL")
                        .font(.custom("DotGothic16-Regular", size: 13))
                        .fontWeight(.bold)
                        .foregroundColor(isCancelHovered ? .white : .gray)
                        .frame(width: 110, height: 34)
                        .background(isCancelHovered ? Color.white.opacity(0.12) : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(isCancelHovered ? Color.white : Color.gray.opacity(0.6), lineWidth: 1))
                        .contentShape(Rectangle()) // Entire 110x34 area clickable!
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .onHover { hovering in
                    if hovering && !isCancelHovered { Haptics.playClick() }
                    isCancelHovered = hovering
                }
                
                // Save Button
                Button(action: {
                    Haptics.playClick()
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onSave(trimmed)
                    } else {
                        onCancel()
                    }
                }) {
                    Text("SAVE")
                        .font(.custom("DotGothic16-Regular", size: 13))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(width: 110, height: 34)
                        .background(isSaveHovered ? Color.red.opacity(0.85) : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .contentShape(Rectangle()) // Entire 110x34 area clickable!
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .onHover { hovering in
                    if hovering && !isSaveHovered { Haptics.playClick() }
                    isSaveHovered = hovering
                }
            }
        }
        .padding(32)
        .frame(width: 420)
        .background(Color.black.opacity(0.96))
        .border(Color.white.opacity(0.2), width: 1)
        .overlay(CornerBrackets())
        .shadow(color: Color.black.opacity(0.9), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Window-Centered Delete Modal Card
struct DeleteModalCard: View {
    let trackTitle: String
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    @State private var isCancelHovered = false
    @State private var isDeleteHovered = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("DELETE TRACK?")
                .font(.custom("DotGothic16-Regular", size: 22))
                .foregroundColor(.red)
            
            Text("Are you sure you want to delete '\(trackTitle)' and its isolated stems?")
                .font(.custom("DotGothic16-Regular", size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
            
            HStack(spacing: 16) {
                // Cancel Button
                Button(action: {
                    Haptics.playClick()
                    onCancel()
                }) {
                    Text("CANCEL")
                        .font(.custom("DotGothic16-Regular", size: 13))
                        .fontWeight(.bold)
                        .foregroundColor(isCancelHovered ? .white : .gray)
                        .frame(width: 110, height: 34)
                        .background(isCancelHovered ? Color.white.opacity(0.12) : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(isCancelHovered ? Color.white : Color.gray.opacity(0.6), lineWidth: 1))
                        .contentShape(Rectangle()) // Entire 110x34 area clickable!
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .onHover { hovering in
                    if hovering && !isCancelHovered { Haptics.playClick() }
                    isCancelHovered = hovering
                }
                
                // Delete Button
                Button(action: {
                    Haptics.playClick()
                    onDelete()
                }) {
                    Text("DELETE")
                        .font(.custom("DotGothic16-Regular", size: 13))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(width: 110, height: 34)
                        .background(isDeleteHovered ? Color.red.opacity(0.85) : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .contentShape(Rectangle()) // Entire 110x34 area clickable!
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering && !isDeleteHovered { Haptics.playClick() }
                    isDeleteHovered = hovering
                }
            }
        }
        .padding(32)
        .frame(width: 420)
        .background(Color.black.opacity(0.96))
        .border(Color.white.opacity(0.2), width: 1)
        .overlay(CornerBrackets())
        .shadow(color: Color.black.opacity(0.9), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Window Accessor to eliminate title text next to traffic lights
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.title = ""
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isOpaque = false
                window.backgroundColor = .black
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.title = ""
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }
    }
}
