# Isolate - Audio Engine & CoreML Details

## 1. Stem Separation (CoreML)
Isolate uses the Demucs model to separate audio into 4 stems. Because running this in Python via PyTorch is not viable for a native, fast Mac app, we will use a CoreML-converted version of the model.

### Process Flow:
1. **Decode**: `AVAssetReader` extracts raw PCM float32 audio data from the input file (MP3, FLAC, etc.).
2. **Chunking**: The model accepts specific window sizes. The audio must be chunked and passed to the Neural Engine.
3. **Inference**: `MLModel` processes the chunk. Apple Silicon's Neural Engine handles the heavy matrix multiplications.
4. **Reconstruction**: The output tensors are stitched back together.
5. **Encode**: The resulting 4 arrays (Vocals, Bass, Drums, Other) are written to a temporary cache directory as `.wav` or `.caf` files for fast loading.

## 2. Playback Architecture (AVAudioEngine)
Once the stems are available on disk, we construct a real-time playback graph.

### The Audio Graph
```
[Player Node 1 (Vocals)] ---> [Mixer 1] --\
[Player Node 2 (Bass)]   ---> [Mixer 2] ---> [Main Stem Mixer] ---> [Time/Pitch Effect] ---> [Main Mixer / Output Node]
[Player Node 3 (Drums)]  ---> [Mixer 3] --/
[Player Node 4 (Other)]  ---> [Mixer 4] -/
```

### Key Components
- **AVAudioPlayerNode**: We use 4 of these, one for each stem. They must be scheduled to play simultaneously using a shared `AVAudioTime` to guarantee sample-accurate sync.
- **AVAudioMixerNode**: Each player node routes to its own mixer. The UI volume sliders directly manipulate the `volume` property of these 4 mixers.
- **AVAudioUnitTimePitch**: Inserted between the main stem mixer and the output node. This allows real-time manipulation of the `rate` (speed) and `pitch` of the entire track.

## 3. Export Pipeline
To export, we switch `AVAudioEngine` to **manual rendering mode** (`enableManualRenderingMode`). 
Instead of outputting to the speakers, the engine processes the audio as fast as possible (faster than real-time) and writes the output of the Main Mixer to an `AVAudioFile` on the user's disk. This captures the exact volume and effect states the user has set.
