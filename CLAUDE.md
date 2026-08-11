# Isolate - Development Guide & Source of Truth

This document serves as the central source of truth for the **Isolate** app. It consolidates the architecture, audio engine, design, roadmap, and user preferences into a single guide.

## Agent Instructions & Rules
* **CRITICAL INSTRUCTION**: Every time the user asks a question or makes a request in the terminal CLI, you MUST ask clarifying questions in a clickable format (using the `ask_question` tool) before beginning work. Aim to ask around 10 questions to ensure 95% confidence in what the user wants, rather than making assumptions.
* **Skills to Leverage**: Utilize the available skills in `/Users/neokumar/.agents/skills/` such as:
    * `swiftui-expert-skill` / `swiftui-pro` (For modern macOS 14 SwiftUI practices and `@Observable`)
    * `investigate` / `qa` (For deep bug squashing and testing)
    * `macos-design-guidelines` (Keep in mind the custom "Nothing" brand overrides standard HIG)
    * `design-html` / `axiom-swiftui` (For precise UI/UX implementation)

---

## 1. Project Overview & Target
* **App Name**: Isolate
* **Platform**: macOS (Apple Silicon optimized)
* **Minimum Target**: macOS 14 (Sonoma)
* **Core Purpose**: Music player and on-device AI stem splitter (Vocals, Bass, Drums, Other).

## 2. Requirements & User Preferences (Confirmed)
* **Stem Separation Model**: We need to find, download, or convert a Demucs model to CoreML format.
* **Stem Splitting UX**: The split process will be foreground/blocking with a loading screen.
* **Input Audio Formats**: Prioritize MP3, WAV, FLAC, AAC / M4A, ALAC.
* **Database/Persistence**: SwiftData.
* **Typography**: We will find and download a suitable open-source dot-matrix font to match the brand.
* **Exporting**: Default export format will be lossless WAV.
* **Player UI Layout**: Horizontal layout (like a traditional mixing console).
* **Stem Controls**: Each of the 4 stems will have a Volume (Slider), Mute, and Solo button.
* **Library Organization**: Tracks should be grouped by their original folder structure.

## 3. Architecture & Audio Engine
* **Frameworks**: SwiftUI, SwiftData, CoreML, AVFoundation (`AVAudioEngine`).
* **Stem Splitting Flow (CoreML)**:
    1. Read input audio via `AVAssetReader`.
    2. Chunk audio and run inference using the CoreML Demucs model on the Apple Neural Engine.
    3. Reconstruct the output and write 4 separate `.wav` or `.caf` stem files to a cache directory.
* **Playback Graph**:
    * 4 `AVAudioPlayerNode` instances (one for each stem), scheduled to play synchronously.
    * 4 `AVAudioMixerNode` instances (handling volume/mute/solo for each stem).
    * Routes into a Main Mixer Node.
    * `AVAudioUnitTimePitch` applied globally to adjust playback speed and pitch in real-time.
* **Export Pipeline**:
    * Switch `AVAudioEngine` to `enableManualRenderingMode` to rapidly process and bounce the current audio graph state (including effect nodes and mixer levels) directly to an audio file on disk.

## 4. Design System ("Nothing" Brand Aesthetic)
* **Visuals**: Highly stylized, utilitarian, hardware-inspired. Dark grays, deep blacks, dotted grids, glassmorphism, and subtle noise textures.
* **Accents**: High saturation red (`#FF0000`) for active states.
* **Typography**: Dot-matrix font for headers/numbers, and a rigid sans-serif (e.g., Space Grotesk/Inter/SF Pro) for secondary body text.
* **Components**: Custom sliders and pill-shaped/circular buttons. Rigid grid-based layouts mimicking physical mixers.
* **Interactions**: Snappy, rigid, fast-easing animations with tactile haptic feedback (where applicable).

## 5. Development Roadmap Summary
* **Phase 1**: SwiftUI scaffolding, "Nothing" design system setup, basic Drag & Drop, standard non-split `AVAudioEngine` playback.
* **Phase 2**: CoreML Demucs integration, offline caching, and blocking loading UI.
* **Phase 3**: 4-Channel Stem Player UX, `AVAudioEngine` graph syncing, global effects, and looping.
* **Phase 4**: SwiftData library persistence grouped by folders, ID3 tag parsing.
* **Phase 5**: Manual rendering export (mixed down and batch stems), final polish, and open-source prep.
