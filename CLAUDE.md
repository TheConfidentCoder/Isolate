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
* **Frameworks**: SwiftUI, SwiftData, CoreML, AVFoundation (`AVAudioEngine`), Accelerate (`vDSP`).
* **Stem Splitting Flow (CoreML & Apple Silicon)**:
    1. Read input audio via `AVAssetReader` and convert to `Float32` chunks.
    2. Process audio using `vDSP` to conform to the 44.1kHz stereo format required by the model.
    3. Run inference sequentially through `HTDemucs_CoreML_FP16.mlpackage` utilizing the Apple Neural Engine (`ANE`) and GPU (`MLComputeDevice`).
    4. Reconstruct the output using Accelerate vector math and write 4 separate `.caf` stem files to the local App Sandbox cache.
    5. Maintain extreme memory efficiency (~1GB limit) by streaming inference chunks rather than holding the entire uncompressed track in RAM.
* **Playback Graph**:
    * 5 `AVAudioPlayerNode` instances (4 for stems, 1 for Bypass/Original).
    * `AVAudioTap` placed on the mixer nodes, backed by `Accelerate` to compute live RMS acoustic energy for the Dynamic UI.
    * 4 `AVAudioMixerNode` instances (handling volume/mute/solo for each stem).
    * Routes into a Main Mixer Node.
    * `AVAudioUnitTimePitch` applied globally to adjust playback speed and pitch in real-time.

### Phase 2: Core Enhancements & Optimization
1. **CPU/Memory Optimization (Priority)**: Clean up CoreML memory usage, profile CPU bottlenecks.
2. **Persistence / Caching**: SwiftData to remember imported tracks. Cache AI output stems to disk so subsequent loads are instant.
3. **Export Stems**: 'Save As' dialog to export the 4 individual separated stems bundled into a single ZIP archive, named `[TrackName]_[StemType].caf`.
4. **Master Bypass**: A toggle to instantly compare the AI-separated stems against the original audio.
5. **Keyboard Shortcuts**: Pro-level shortcuts (Spacebar for Play/Pause, hotkeys for Mute/Solo).
6. **Visual EQ Curve**: Add an EQ spectrum visualizer alongside the existing Nothing-style waveform for each stem.

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
