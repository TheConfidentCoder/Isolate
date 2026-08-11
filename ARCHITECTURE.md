# Isolate - Architecture Document

## Overview
Isolate is a native macOS application built with SwiftUI, designed for Apple Silicon. It combines robust music library management with on-device AI stem splitting and real-time audio manipulation.

## Core Technologies
1. **UI Framework**: SwiftUI. Modern declarative UI, allowing for the highly custom "Nothing" aesthetic while maintaining native performance.
2. **State Management**: Observation framework (`@Observable`). We will use a clean MVVM (Model-View-ViewModel) architecture.
3. **Audio Processing (Stem Splitting)**: CoreML. We will utilize the Demucs model, converted and optimized for the Apple Neural Engine (ANE) on Apple Silicon. This ensures the highest quality separation of 4 stems (Vocals, Bass, Drums, Other) entirely offline.
4. **Audio Playback & Effects**: `AVFoundation` and `AVAudioEngine`. Provides low-latency playback, multi-node graph construction for stem mixing, and real-time effects (pitch, speed, looping).
5. **Persistence (Library)**: Core Data or SwiftData to manage the persistent database of imported tracks, metadata, and locations of cached separated stems.

## High-Level Modules

### 1. App State & Router
Manages the global state, navigation (Library view vs. Player view), and global settings.

### 2. Library Manager
Handles dragging and dropping of audio files (MP3, AAC, FLAC, WAV, M4A), parsing ID3 tags (metadata/artwork), and persisting track information to the local database.

### 3. Stem Separation Engine (CoreML Worker)
An asynchronous worker that takes an input audio file, prepares the tensor data, runs inference via the Demucs CoreML model, and outputs 4 separate audio files (stems) to a cache directory. 

### 4. Audio Playback Engine
A robust wrapper around `AVAudioEngine` that loads the 4 stems synchronously, routes them through individual mixer nodes (for volume/mute/solo), and applies global effect nodes (like `AVAudioUnitTimePitch`) before routing to the main output.

### 5. Export Engine
An offline rendering pipeline that takes the current mixer states and effects, and renders a mixed down `.wav` or `.m4a` file, or exports the 4 individual stem files to a user-specified directory on the Mac.
