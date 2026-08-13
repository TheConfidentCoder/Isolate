# Isolate - Audio Engine & CoreML Pipeline

## 1. High-Fidelity Stem Separation Pipeline (`DemucsEngine`)
Isolate uses the Hybrid Transformer Demucs (HTDemucs) model compiled to Apple Silicon CoreML (`MLProgram`), running natively on the Apple Neural Engine (`ANE`) and GPU with zero Python dependencies.

### Mathematical & DSP Architecture:
1. **Mastering Resampler (`AVAudioConverter`)**:
   - Decodes any format (`MP3`, `FLAC`, `ALAC`, `WAV`, `M4A`, `AAC`, `OGG`) at any sample rate (`44.1k`, `48k`, `96k`, `192k`).
   - Resamples using `AVSampleRateConverterAlgorithm_Mastering` with `AVAudioQuality.max` to 44.1kHz 32-bit Float Stereo with zero aliasing.
2. **Audio Energy & Dynamic Range Standardization**:
   - Calculates track-wide mean $\mu$ and standard deviation $\sigma$ using Accelerate `vDSP`.
   - Normalizes audio prior to inference: $x_{\text{norm}} = (x - \mu) / \sigma$.
   - Restores exact natural dynamics upon reconstruction: $s_{\text{actual}} = s_{\text{model}} \cdot \sigma + \mu$.
3. **Mirror / Reflection Padding**:
   - Center-aligns the start ($t=0$) and end ($t=L$) by reflection-padding by $hopSize = 220500$ samples (5.0 seconds).
   - Eliminates all onset/fade transients, boundary clicks, and edge attenuation.
4. **Normalized Overlap-Add (COLA) with Weight Accumulation**:
   - 10.0s Chunk duration ($N = 441000$) with 50% overlap ($H = 220500$).
   - Periodic Hann window $w[n] = 0.5 \cdot (1 - \cos(2\pi n / N))$ via `vDSP_hann_window`.
   - Accumulates stem energy: $A[s, t + n] += s_k[s, n] \cdot w[n]$.
   - Accumulates window weights: $W[t + n] += w[n]$.
   - Final normalization: $s[s, t] = A[s, t] / \max(10^{-5}, W[t])$.
   - Flat frequency response ($W[t] \equiv 1.0$) across the entire song.
5. **Lossless Stem Export**:
   - Outputs 4 separate 32-bit Float PCM Stereo WAV files:
     - `vocals.wav` (Stem Index 0)
     - `drums.wav` (Stem Index 1)
     - `bass.wav` (Stem Index 2)
     - `other.wav` (Stem Index 3)

---

## 2. Playback Architecture (`AudioEngineManager`)
```
[Vocals Player] ---> [Vocals Mixer] ---\
[Drums Player]  ---> [Drums Mixer]   ---\
                                          ---> [Stems Sum Mixer] ---> [Main Engine Mixer]
[Bass Player]   ---> [Bass Mixer]    ---/
[Other Player]  ---> [Other Mixer]   ---/
[Original Master Player] --------------------------------------------/ (Bypass Toggle)
```

### Key Capabilities:
- **Sample-Accurate Multi-Node Synchronization**: Stems and Original Master are scheduled simultaneously on a shared `mach_absolute_time()` host time boundary.
- **Master Bypass (Instant A/B Comparison)**: Seamless zero-latency toggling between unseparated master audio and the 4 isolated stems.
- **Live Visualizers**:
  - Live Master & Stem RMS Waveform analysis via `vDSP_rmsqv`.
  - 32-Band FFT Master Spectrum and per-stem 16-Band mini EQ spectrum visualizers running at 30 fps via `vDSP_fft_zrip`.
- **Persistent Caching**: Cached stems stored in `~/Library/Application Support/Isolate/Stems/` and indexed in `SwiftData`. Previously isolated tracks load instantaneously in 0.0s.
