# BlindGuy — Audio Engine (reference + lab tools)

**Production iOS app:** the wired **`HearingEngine`** and **`@main` entry** live under **`../ios/BlindGuyRuntime/`** with **`BlindGuyKit`**. See **`../ios/XCODE_SETUP.md`**.

This folder keeps a **local JSON simulator** and legacy Swift files for experiments:

- `AudioEngineApp/` — older SwiftUI shell (no longer the canonical `@main`). Spatial audio logic was merged into **`ios/BlindGuyRuntime/HearingEngine.swift`**, which consumes **`FramePayload`** from **on-device** vision or **GET `/frame`** (same as **GET `/payload`**) on the main Python service.
- `simulator/` — small Flask process for synthetic frames; you can also use the repo **`src/visual_engine`** service on port **8765** for real YOLO output.

Quick start

1) Run the simulator (Python 3.9+):

```bash
cd "BlindGuy/AudioEngine/simulator"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python server.py
```

The repo’s main vision service (`python -m visual_engine.main`, default **8765**) exposes **`/frame`**, **`/payload`** (alias), **`/infer`**, **`/judge`**. The legacy simulator in this folder may use `/payload` on its own port; align ports when testing.

2) Open `AudioEngineApp` in Xcode (open the folder as a project) and run on a device or simulator. The app polls the simulator and plays spatial audio using stereo panning, pitch, and volume modulation.

Voice announcements

- The app uses iOS TTS (`AVSpeechSynthesizer`) to announce detected object classes and approximate distance (rounded to meters).
- By default the app will announce new objects when they appear and any object flagged as `priority: "HIGH"` (e.g., within 3 meters).

Simulator tests and generator

- The simulator includes a payload generator and JSON schema validator under `simulator/`.
- To run tests and validate payloads:

```bash
cd "BlindGuy/AudioEngine/simulator"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pytest -q
```

- Use `python generator.py` to print example payloads.
- Use `python validator.py` to validate the sample payload in `validator.py`.

Notes
- The app is intentionally self-contained and does not reference any other repo code.
- For real deployment on device, enable microphone and background audio capabilities in Xcode.
