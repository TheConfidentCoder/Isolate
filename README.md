# ISOLATE

> **Raw, zero-latency 4-stem audio isolation for macOS.**  
> Powered by Demucs v4 Neural Engine CoreML & Nothing OS hardware aesthetics.

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%2F%20Sequoia-black?style=for-the-badge&logo=apple)](https://github.com/TheConfidentCoder/Isolate)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20%2F%20M2%20%2F%20M3%20%2F%20M4%20Accelerated-red?style=for-the-badge)](https://github.com/TheConfidentCoder/Isolate)
[![License: MIT](https://img.shields.io/badge/License-MIT-white?style=for-the-badge)](LICENSE)

---

## [ 01. HIGHLIGHTS ]

- **4-Stem Neural Isolation**: Surgically separate any song into **Vocals**, **Drums**, **Bass**, and **Other** with Hybrid Demucs v4 on Apple Silicon Neural Engine (ANE).
- **Tactical Hardware Mixer**: Dynamic tactile faders, 1.2s peak-hold clip LEDs, dual decibel (`0.0 dB`) / linear percentage readouts, single-click **[M]** Mute and exclusive **[S]** Solo routing.
- **Rotary Stereo Pan Dials**: Channel pan knobs (`‹ C ›`, `‹ 42L`, `28R ›`) featuring magnetic haptic center snap.
- **Top Header Space & Telemetry HUD**: 32-band real-time FFT spectrum visualizer, ANE neural status, tempo / key indicators, and one-click stem macros (`[ ACAPELLA ]`, `[ INSTRUMENTAL ]`, `[ DRUMLESS ]`, `[ KARAOKE ]`, `[ D&B ]`, `[ RESET ]`).
- **Live A-B Region Looper**: Real-time loop boundary setting on the fly with dedicated hotkeys.
- **macOS Menu Bar Mini Controller**: Status bar controller with an animated 3-bar equalizer and native completion notifications.
- **Resilient Multi-Token Library Search**: Instant filtering across track names, artists, and filenames.
- **Modern macOS 26 & 27 Design**: Squircle app icon and zero-latency Nothing hardware aesthetic.

---

## [ 02. INSTALLATION ]

### Option A: Pre-Built DMG Installer

1. Download **`Isolate.dmg`** from [GitHub Releases](https://github.com/TheConfidentCoder/Isolate/releases/latest).
2. Drag **`Isolate.app`** to **`Applications`**, then launch.

---

### Option B: Build from Source

#### Prerequisites
- macOS 14.0 (Sonoma) or newer
- Xcode 15.4 or Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```bash
# 1. Clone the repository
git clone https://github.com/TheConfidentCoder/Isolate.git
cd Isolate

# 2. Generate Xcode project
xcodegen generate

# 3. Build & Run
xcodebuild -scheme Isolate -configuration Release -destination 'platform=macOS' build
open build/Release/Isolate.app
```

---

## [ 03. KEYBOARD SHORTCUTS ]

| Action | Shortcut | Description |
| :--- | :--- | :--- |
| **Play / Pause** | `Space` | Toggle global audio playback |
| **Solo Stem (1 - 4)** | `1` / `2` / `3` / `4` | Exclusive solo for Vocals, Drums, Bass, Other |
| **Mute Stem (V / D / B / O)** | `V` / `D` / `B` / `O` | Toggle mute for individual stem channels |
| **Set Loop In / Out** | `[` / `]` | Mark A-B loop start and end points on the fly |
| **Toggle Loop** | `L` | Toggle active A-B region loop on/off |
| **Acapella / Instrumental / Reset** | `A` / `I` / `R` | Trigger stem macros immediately |
| **Bypass Toggle** | `B` | Toggle between raw original master and stem mix |
| **Shortcut Cheat Sheet HUD** | `?` or `/` | Toggle in-app floating Nothing OS shortcuts card |
| **Export Stems** | `E` | Export 4-stem multi-format audio bundle |
| **Import Audio** | `⌘O` | Open file picker for single or batch stem separation |
| **Fader Reset to 100%** | `Double-Click` | Double-click fader thumb or volume number to reset to unity |
| **Dismiss / Close** | `Esc` | Cancel / dismiss active modal card |

---

## [ 04. ARCHITECTURE ]

```
Isolate/
├── Sources/
│   ├── App/
│   │   ├── IsolateApp.swift        # App entry point, scene hierarchy, and modal cards
│   │   ├── AudioEngineManager.swift # Low-latency 4-track AVAudioEngine DSP graph
│   │   ├── DemucsEngine.swift      # CoreML Demucs v4 Neural Engine inference pipeline
│   │   ├── AppMoveHelper.swift     # Automatic /Applications installation & DMG eject
│   │   └── Haptics.swift           # Mechanical tactile feedback synthesis
│   ├── Player/
│   │   ├── PlayerView.swift        # Mixer channel strips, transport bar, FFT visualizer
│   │   ├── CustomFader.swift       # Hardware faders with drag gestures & haptic detents
│   │   └── SpectrumVisualizer.swift# Live Accelerate vDSP FFT dot-matrix visualizer
│   ├── Library/
│   │   ├── LibraryView.swift       # Track list, 3-dots action menu, rename, delete
│   │   └── TrackModel.swift        # SwiftData persistent schema
│   └── Resources/
│       ├── DotGothic16-Regular.ttf # Nothing OS dot-matrix typography
│       └── HTDemucs.mlmodelc/      # Quantized Demucs CoreML Neural Engine model
├── scripts/
│   ├── package_release.sh          # Automated Release DMG & ZIP builder
│   └── generate_assets.swift       # Nothing OLED DMG wallpaper & icon generator
├── Tests/                          # XCTest unit test suite
└── .github/workflows/              # Automated CI/CD release workflow
```

---

## [ 05. CREDITS & LICENSE ]

- **Demucs**: Hybrid Transformer Demucs by Alexandre Défossez ([Meta AI Research](https://github.com/facebookresearch/demucs)).
- **Typography**: [DotGothic16](https://fonts.google.com/specimen/DotGothic16) font by Fontworks Inc.
- **License**: Released under the [MIT License](LICENSE).
