# Isolate - Project Roadmap

## Phase 1: Foundation & UI Scaffolding
- [ ] Initialize SwiftUI macOS project (`Isolate`).
- [ ] Setup the fundamental "Nothing" design system (Colors, Fonts, basic custom controls).
- [ ] Create the core Views: Library View, Player/Mixer View.
- [ ] Implement basic Drag-and-Drop file ingestion (without splitting yet).
- [ ] Build a standard audio player using `AVAudioEngine` for non-split tracks.

## Phase 2: CoreML Stem Splitting
- [ ] Acquire/Convert a Demucs model to CoreML format optimized for Apple Silicon (ANE).
- [ ] Implement the asynchronous CoreML worker to ingest an audio file and produce 4 audio buffers/files.
- [ ] Handle caching of split stems (so files don't need to be re-split on subsequent plays).
- [ ] Add progress indicators/UI for the splitting process.

## Phase 3: The Stem Player UX & Effects
- [ ] Implement the 4-channel UI (custom sliders/knobs for Vocals, Bass, Drums, Other).
- [ ] Upgrade the `AVAudioEngine` graph to support 4 simultaneous player nodes perfectly synced.
- [ ] Hook up the UI volume sliders to the respective mixer nodes.
- [ ] Add real-time effects: Pitch shifting and Playback speed via `AVAudioUnitTimePitch`.
- [ ] Implement seamless looping capability.

## Phase 4: Library Management
- [ ] Implement persistent storage (SwiftData) for track metadata.
- [ ] Parse ID3 tags (Title, Artist, Album Artwork) upon drag-and-drop.
- [ ] Build a robust Library UI to sort, search, and manage imported tracks.

## Phase 5: Exporting & Polish
- [ ] Implement offline rendering to mix down the current slider states into a single audio file.
- [ ] Implement batch export of the 4 individual isolated stems.
- [ ] Final UI/UX polish (animations, haptics, layout adjustments).
- [ ] Prepare repository for Open Source release (Documentation, Licensing, Build instructions).
