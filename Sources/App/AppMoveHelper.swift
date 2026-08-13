import AppKit
import SwiftUI

@MainActor
public final class AppMoveHelper: ObservableObject {
    public static let shared = AppMoveHelper()
    
    @Published public var shouldShowMoveModal = false
    @Published public var isMoving = false
    @Published public var moveErrorMessage: String? = nil
    
    private init() {}
    
    public var isRunningFromApplications: Bool {
        let bundlePath = Bundle.main.bundlePath
        return bundlePath.hasPrefix("/Applications/") || bundlePath.hasPrefix("/Applications") || bundlePath.hasPrefix(NSHomeDirectory() + "/Applications/")
    }
    
    public var isRunningFromDiskImage: Bool {
        let bundlePath = Bundle.main.bundlePath
        return bundlePath.hasPrefix("/Volumes/")
    }
    
    public func checkLocationOnStartup() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
        #endif
        
        if !isRunningFromApplications {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.shouldShowMoveModal = true
            }
        }
    }
    
    public func moveToApplications() {
        isMoving = true
        moveErrorMessage = nil
        
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let sourceURL = Bundle.main.bundleURL
            let destURL = URL(fileURLWithPath: "/Applications/Isolate.app")
            
            do {
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }
                
                try fileManager.copyItem(at: sourceURL, to: destURL)
                
                // Strip macOS Gatekeeper quarantine from installed app
                let xattrProcess = Process()
                xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattrProcess.arguments = ["-dr", "com.apple.quarantine", destURL.path]
                try? xattrProcess.run()
                xattrProcess.waitUntilExit()
                
                let config = NSWorkspace.OpenConfiguration()
                config.createsNewApplicationInstance = true
                
                await MainActor.run {
                    NSWorkspace.shared.openApplication(at: destURL, configuration: config) { _, error in
                        if let error = error {
                            print("Error launching moved app: \(error)")
                        }
                    }
                    
                    let bundlePath = Bundle.main.bundlePath
                    if bundlePath.hasPrefix("/Volumes/") {
                        let components = bundlePath.split(separator: "/")
                        if components.count >= 2 {
                            let volumePath = "/Volumes/\(components[1])"
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                            process.arguments = ["detach", volumePath, "-quiet", "-force"]
                            try? process.run()
                        }
                    }
                    
                    NSApp.terminate(nil)
                }
            } catch {
                await MainActor.run {
                    self.isMoving = false
                    self.moveErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
