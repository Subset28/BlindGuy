# Hearing Branch Log

Branch: `hearing`
Created: 2026-04-25 (local notes)

This file records work performed for the audio/hearing features. Use it as the authoritative changelog for the `hearing` branch.

---

2026-04-25T15:00:00Z — Initialize work
- Created scaffold for standalone audio engine under `BlindGuy/AudioEngine/`.
- Added `README.md` and a small Python simulator at `AudioEngine/simulator/server.py`.

2026-04-25T15:12:00Z — Swift app scaffold
- Added SwiftUI app files under `AudioEngine/AudioEngineApp/`:
  - `AudioEngineApp.swift` (app entry)
  - `ContentView.swift` (minimal UI)
  - `Models.swift` (JSON payload decoders)
  - `AudioEngineManager.swift` (audio engine + bridge)
  - `Info.plist` (background audio + mic description)

2026-04-25T15:35:00Z — Audio engine implementation
- Implemented `AVAudioEngine` audio clones using `AVAudioPlayerNode` + `AVAudioUnitVarispeed`.
- Implemented polling bridge to `http://127.0.0.1:8765/payload` at ~15Hz and decoding into `FramePayload`.
- Object pooling: map `object_id` → persistent `AudioClone` nodes; update pan/volume/varispeed per tick.

2026-04-25T15:50:00Z — Text-to-Speech (TTS)
- Added `AVSpeechSynthesizer` usage in `AudioEngineManager` to announce object `class` and rounded distance.
- Announcements: on new object creation and for objects flagged `priority: "HIGH"`.
- Cooldown: 3 seconds per `object_id` to avoid repetition.

2026-04-25T16:05:00Z — Documentation
- Updated `AudioEngine/README.md` to document simulator, how to run it, and voice announcement behavior.

---

Files added (workspace paths):
- [BlindGuy/AudioEngine/README.md](BlindGuy/AudioEngine/README.md)
- [BlindGuy/AudioEngine/simulator/server.py](BlindGuy/AudioEngine/simulator/server.py)
- [BlindGuy/AudioEngine/simulator/requirements.txt](BlindGuy/AudioEngine/simulator/requirements.txt)
- [BlindGuy/AudioEngine/AudioEngineApp/AudioEngineApp.swift](BlindGuy/AudioEngine/AudioEngineApp/AudioEngineApp.swift)
- [BlindGuy/AudioEngine/AudioEngineApp/ContentView.swift](BlindGuy/AudioEngine/AudioEngineApp/ContentView.swift)
- [BlindGuy/AudioEngine/AudioEngineApp/Models.swift](BlindGuy/AudioEngine/AudioEngineApp/Models.swift)
- [BlindGuy/AudioEngine/AudioEngineApp/AudioEngineManager.swift](BlindGuy/AudioEngine/AudioEngineApp/AudioEngineManager.swift)
- [BlindGuy/AudioEngine/AudioEngineApp/Info.plist](BlindGuy/AudioEngine/AudioEngineApp/Info.plist)
- [BlindGuy/hearing-branch-log.md](BlindGuy/hearing-branch-log.md)

How to create the `hearing` branch locally and commit these changes (example):

```bash
cd "$(git rev-parse --show-toplevel)" # repo root
git checkout -b hearing
git add BlindGuy/AudioEngine BlindGuy/hearing-branch-log.md
git commit -m "hearing: add audio engine, simulator, TTS, README"
git push --set-upstream origin hearing
```

Notes / Next steps
- I recommend creating an Xcode project or workspace including the files under `AudioEngineApp/` so the app is ready to open.
- Optionally swap the polling bridge to a WebSocket or local socket for lower latency in production.
- If you want HRTF/3D spatialization, replace stereo panning with `AVAudioEnvironmentNode` and test on AirPods Pro.
