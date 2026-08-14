import SwiftUI
import AppKit

// MARK: - Persistent App Settings Model
@Observable
public final class AppSettings {
    public static let shared = AppSettings()
    
    public var defaultExportFormat: String {
        didSet {
            UserDefaults.standard.set(defaultExportFormat, forKey: "defaultExportFormat")
            UserDefaults.standard.synchronize()
        }
    }
    
    public var isHapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(!isHapticsEnabled, forKey: "isHapticsDisabled")
            UserDefaults.standard.synchronize()
            if isHapticsEnabled {
                Haptics.playClick()
            }
        }
    }
    
    public var isAutoPlayOnSelect: Bool {
        didSet {
            UserDefaults.standard.set(!isAutoPlayOnSelect, forKey: "isAutoPlayDisabled")
            UserDefaults.standard.synchronize()
        }
    }
    
    public var waveformSensitivity: Double {
        didSet {
            UserDefaults.standard.set(waveformSensitivity, forKey: "waveformSensitivity")
            UserDefaults.standard.synchronize()
        }
    }
    
    private init() {
        self.defaultExportFormat = UserDefaults.standard.string(forKey: "defaultExportFormat") ?? "WAV"
        self.isHapticsEnabled = !UserDefaults.standard.bool(forKey: "isHapticsDisabled")
        self.isAutoPlayOnSelect = !UserDefaults.standard.bool(forKey: "isAutoPlayDisabled")
        let savedSensitivity = UserDefaults.standard.double(forKey: "waveformSensitivity")
        self.waveformSensitivity = savedSensitivity > 0 ? savedSensitivity : 1.0
    }
    
    public func reloadFromStorage() {
        self.defaultExportFormat = UserDefaults.standard.string(forKey: "defaultExportFormat") ?? "WAV"
        self.isHapticsEnabled = !UserDefaults.standard.bool(forKey: "isHapticsDisabled")
        self.isAutoPlayOnSelect = !UserDefaults.standard.bool(forKey: "isAutoPlayDisabled")
        let savedSensitivity = UserDefaults.standard.double(forKey: "waveformSensitivity")
        self.waveformSensitivity = savedSensitivity > 0 ? savedSensitivity : 1.0
    }
    
    public func resetToDefaults() {
        defaultExportFormat = "WAV"
        isHapticsEnabled = true
        isAutoPlayOnSelect = true
        waveformSensitivity = 1.0
        Haptics.playClick()
    }
}

// MARK: - Settings & Shortcuts Modal Card
struct SettingsModalCard: View {
    let onDismiss: () -> Void
    
    @State private var selectedTab: Int = 0 // 0 = Settings, 1 = Shortcuts
    @Bindable private var settings = AppSettings.shared
    @State private var isCloseHovered = false
    @State private var isResetHovered = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header: Title & Tab Switcher
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                    Text("SYSTEM PREFERENCES")
                        .font(.custom("DotGothic16-Regular", size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Tab Switcher [ SETTINGS | SHORTCUTS ]
                HStack(spacing: 4) {
                    Button(action: {
                        Haptics.playClick()
                        selectedTab = 0
                    }) {
                        Text("SETTINGS")
                            .font(.custom("DotGothic16-Regular", size: 12))
                            .fontWeight(.bold)
                            .foregroundColor(selectedTab == 0 ? .black : .gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedTab == 0 ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        Haptics.playClick()
                        selectedTab = 1
                    }) {
                        Text("SHORTCUTS")
                            .font(.custom("DotGothic16-Regular", size: 12))
                            .fontWeight(.bold)
                            .foregroundColor(selectedTab == 1 ? .black : .gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedTab == 1 ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Content Area based on Tab
            if selectedTab == 0 {
                settingsTabContent
            } else {
                shortcutsTabContent
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Footer: Reset & Close Buttons
            HStack {
                if selectedTab == 0 {
                    Button(action: {
                        settings.resetToDefaults()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                            Text("RESET DEFAULTS")
                                .font(.custom("DotGothic16-Regular", size: 12))
                        }
                        .foregroundColor(isResetHovered ? .white : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isResetHovered ? Color.white.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(isResetHovered ? Color.white : Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering && !isResetHovered { Haptics.playClick() }
                        isResetHovered = hovering
                    }
                }
                
                Spacer()
                
                Button(action: {
                    Haptics.playClick()
                    onDismiss()
                }) {
                    Text("CLOSE")
                        .font(.custom("DotGothic16-Regular", size: 13))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(width: 100, height: 32)
                        .background(isCloseHovered ? Color.white : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering && !isCloseHovered { Haptics.playClick() }
                    isCloseHovered = hovering
                }
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(Color.black)
        .compositingGroup()
        .border(Color.white.opacity(0.2), width: 1)
        .overlay(CornerBrackets())
        .shadow(color: Color.black, radius: 24, x: 0, y: 8)
    }
    
    // MARK: - Settings Tab Content
    private var settingsTabContent: some View {
        VStack(spacing: 16) {
            // Setting 1: Default Export Format
            settingRow(
                title: "DEFAULT EXPORT FORMAT",
                subtitle: "Preferred audio format for multi-track stem export"
            ) {
                HStack(spacing: 6) {
                    exportFormatButton("WAV", label: "WAV (24-BIT)")
                    exportFormatButton("M4A", label: "M4A (320K)")
                }
            }
            
            // Setting 2: Haptic Feedback
            settingRow(
                title: "TACTILE HAPTICS",
                subtitle: "Physical haptic feedback on clicks, faders, and buttons"
            ) {
                toggleSwitch(isOn: $settings.isHapticsEnabled)
            }
            
            // Setting 3: Auto-Play on Select
            settingRow(
                title: "AUTO-PLAY ON SELECT",
                subtitle: "Automatically start playback when clicking a track in Library"
            ) {
                toggleSwitch(isOn: $settings.isAutoPlayOnSelect)
            }
            
            // Setting 4: Waveform Sensitivity
            settingRow(
                title: "WAVEFORM SENSITIVITY",
                subtitle: "Dynamic height multiplier for master & stem waveforms"
            ) {
                HStack(spacing: 6) {
                    sensitivityButton(0.7, label: "0.7x SUBTLE")
                    sensitivityButton(1.0, label: "1.0x STD")
                    sensitivityButton(1.5, label: "1.5x PUNCH")
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Shortcuts Tab Content
    private var shortcutsTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            shortcutRow(keys: ["1", "2", "3", "4"], description: "Toggle Mute for Vocals, Drums, Bass, Other")
            shortcutRow(keys: ["⇧ Shift", "+", "1 2 3 4"], description: "Toggle Solo for Vocals, Drums, Bass, Other")
            shortcutRow(keys: ["Space"], description: "Play / Pause playback")
            shortcutRow(keys: ["B"], description: "Toggle Bypass (Original vs Separated Stems)")
            shortcutRow(keys: ["E"], description: "Open Stem Export dialogue")
            shortcutRow(keys: ["⌘", "O"], description: "Import new audio track")
            shortcutRow(keys: ["⌘", ","], description: "Open System Preferences & Shortcuts")
            shortcutRow(keys: ["Tab"], description: "Collapse / Expand Library Sidebar")
            shortcutRow(keys: ["Double-Click"], description: "Reset stem slider to 100% Unity Gain")
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - UI Helpers
    private func settingRow<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("DotGothic16-Regular", size: 13))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.custom("DotGothic16-Regular", size: 10))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            content()
        }
    }
    
    private func exportFormatButton(_ format: String, label: String) -> some View {
        let isSelected = settings.defaultExportFormat == format
        return Button(action: {
            Haptics.playClick()
            settings.defaultExportFormat = format
        }) {
            Text(label)
                .font(.custom("DotGothic16-Regular", size: 11))
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.red : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isSelected ? Color.red : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func sensitivityButton(_ value: Double, label: String) -> some View {
        let isSelected = abs(settings.waveformSensitivity - value) < 0.05
        return Button(action: {
            Haptics.playClick()
            settings.waveformSensitivity = value
        }) {
            Text(label)
                .font(.custom("DotGothic16-Regular", size: 10))
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(isSelected ? Color.red : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isSelected ? Color.red : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func toggleSwitch(isOn: Binding<Bool>) -> some View {
        Button(action: {
            Haptics.playClick()
            isOn.wrappedValue.toggle()
        }) {
            HStack(spacing: 0) {
                Text("ON")
                    .font(.custom("DotGothic16-Regular", size: 10))
                    .fontWeight(.bold)
                    .foregroundColor(isOn.wrappedValue ? .white : .gray.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isOn.wrappedValue ? Color.red : Color.clear)
                
                Text("OFF")
                    .font(.custom("DotGothic16-Regular", size: 10))
                    .fontWeight(.bold)
                    .foregroundColor(!isOn.wrappedValue ? .white : .gray.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(!isOn.wrappedValue ? Color.white.opacity(0.2) : Color.clear)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func shortcutRow(keys: [String], description: String) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    if key == "+" {
                        Text("+")
                            .font(.custom("DotGothic16-Regular", size: 11))
                            .foregroundColor(.gray)
                    } else {
                        Text(key)
                            .font(.custom("DotGothic16-Regular", size: 11))
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            }
            .frame(width: 140, alignment: .leading)
            
            Text(description)
                .font(.custom("DotGothic16-Regular", size: 12))
                .foregroundColor(.white.opacity(0.85))
            
            Spacer()
        }
    }
}
