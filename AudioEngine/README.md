# BlindGuy — Audio Engine

This folder contains a standalone iOS audio engine app and a local JSON simulator.

Overview:
- `AudioEngineApp/` — SwiftUI iOS app implementing `AVAudioEngine` with stereo panning and pitch/volume modulation. Polls a local JSON bridge and renders spatialized audio clones.
- `simulator/` — Small Flask server that emits JSON frames matching the PRD contract for testing.

Quick start

1) Run the simulator (Python 3.9+):

```bash
cd "BlindGuy/AudioEngine/simulator"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python server.py
```

Simulator will listen on `http://127.0.0.1:8765/payload`.

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
