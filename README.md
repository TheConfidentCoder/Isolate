# ISOLATE

> **Raw, zero-latency 4-stem audio isolation for macOS.**  
> Powered by Demucs v4 Neural Engine CoreML & Nothing OS hardware aesthetics.

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%2F%20Sequoia-black?style=for-the-badge&logo=apple)](https://github.com/TheConfidentCoder/Isolate)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20%2F%20M2%20%2F%20M3%20%2F%20M4%20Accelerated-red?style=for-the-badge)](https://github.com/TheConfidentCoder/Isolate)
[![License: MIT](https://img.shields.io/badge/License-MIT-white?style=for-the-badge)](LICENSE)

---

## [ 01. HIGHLIGHTS ]

- **4-Stem Neural Isolation**: Surgically separate any song into **Vocals**, **Drums**, **Bass**, and **Other** with Hybrid Demucs v4.
- **Hardware Mixer Channel Strips**: Dynamic tactile faders, peak LED telemetry, single-click **[M]** Mute and **[S]** Solo routing, and master **[BYPASS]**.
- **Real-Time 60FPS FFT Spectrum**: Live hardware dot-matrix audio visualizer rendered via Metal & Accelerate DSP.
- **Double-Click Reset**: Double-click any stem fader or volume readout to snap directly to 100%.
- **Seamless Stem Export**: One-click multi-track `.wav` or `.m4a` export for seamless import into Logic Pro, Ableton, FL Studio, or Pro Tools.
- **100% Offline & Private**: Zero cloud dependency. All neural inference runs directly on your Mac's Apple Silicon Neural Engine (ANE).

---

## [ 02. INSTALLATION ]

### Option A: Pre-Built DMG (Recommended)

1. Download the latest **`Isolate-v1.0.0.dmg`** from [GitHub Releases](https://github.com/TheConfidentCoder/Isolate/releases).
2. Double-click the `.dmg` installer.
3. Drag the **`Isolate.app`** icon into the **`Applications`** folder.
4. Open **`Isolate.app`** from `/Applications`.

> [!NOTE]  
> **macOS Gatekeeper Notice (Ad-Hoc Open Source Build)**  
> Because Isolate is open-source, on your first launch macOS may show a developer verification notice:
> - **Method 1**: Right-click (or Control-click) `Isolate.app` in `/Applications` and choose **Open**, then click **Open** in the dialog.
> - **Method 2**: Or run this one-line command in Terminal:
>   ```bash
>   xattr -cr /Applications/Isolate.app
>   ```

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
xcodebuild -scheme Isolate -destination 'platform=macOS' build
open build/Release/Isolate.app
```

---

## [ 03. KEYBOARD SHORTCUTS ]

| Action | Shortcut | Description |
| :--- | :--- | :--- |
| **Play / Pause** | `Space` | Toggle global audio playback |
| **Bypass Toggle** | `B` | Toggle between raw original mix and active stem mix |
| **Export Stems** | `⌘E` | Open Stem Export dialog |
| **Import Audio** | `⌘O` | Open file picker for stem separation |
| **Toggle Sidebar** | `⌘S` | Show / hide left track library sidebar |
| **Fader Snap** | `Double-Click` | Double-click fader thumb or volume number to reset to 100 |
| **Dismiss Modal** | `Esc` | Cancel / dismiss active modal card |

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
