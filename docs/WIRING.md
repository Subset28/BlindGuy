# End-to-end wiring (Visual)

Use this as a **checklist** to connect camera → vision → consumers. Deeper API notes live in [visual-integration.md](visual-integration.md) and the PRD.

## 1. Repository and Python service

- Branch: **`Visual`** (pull before integrating).
- Create a venv, install from `requirements.txt`, then from repo root with `pythonpath` pointing at `src`:

  ```bash
  PYTHONPATH=src python -m visual_engine.main --host 0.0.0.0 --port 8765
  ```

- iPhone or another client is the only camera (no Mac webcam): add **`--no-local-camera`** and drive **`POST /infer`** from the app (see [visual-integration.md](visual-integration.md)).
- **Health check:** `GET /health` — **Frame mirror:** `GET /frame` (same JSON as a successful infer).

## 2. iOS: on-device path (BlindGuyKit)

1. Add **BlindGuyKit** (local Swift package) to your Xcode app target.
2. Bundle a **CoreML** model; construct **`CoreMLDetector` → `OnDeviceVisionEngine` → `BlindGuySession`**.
3. Wire the camera: create **`CameraPipeline(vision: session)`** and call **`await pipeline.start()`** after your UI is ready. Stop with **`pipeline.stop()`** on teardown.
4. **Info.plist:** `NSCameraUsageDescription` (user-facing string for why the camera is used).
5. Optional: observe **`BlindGuySession`’s `lastPayload`** for UI; use **`FramePayload.jsonString()`** for debug overlays or file logging.

`CameraPipeline` uses preset **VGA 640×480**, BGRA buffers, and the **back** wide camera. Set **`imageOrientation:`** in the initializer if the physical mount (e.g. lanyard) does not match the default **`.right`** (portrait rear camera with Vision).

## 3. iOS: dev bridge to the Mac (no CoreML in loop)

- Same **`FramePayload`** JSON (decode server responses the same as on-device `Codable`).
- Send JPEGs to **`POST /infer`**, or poll **`GET /frame`**. CORS and ATS exceptions for local HTTP are documented in [visual-integration.md](visual-integration.md).

## 4. Audio / spatial

- Input: **`FramePayload`**, in particular **`objects[]`**: `class`, `object_id`, **`pan_value`**, **`distance_m`**, `confidence` (and **`camera`** for lens TTS, which `BlindGuySession` can already speak on iOS).
- Map fields into your existing spatialization rules; keep **`object_id`** stable for **continuous** cues across frames.

## 5. Quality gates before shipping a build

- **Python (fast):** `pytest -m "not slow"` from repo root.
- **Python (smoke, optional YOLO):** `python -m visual_engine.testing_engine` and/or `python -m visual_engine.simulation` (see README § simulation).
- **iOS:** run on device; confirm **`lastPayload` updates** and lens announcements behave when the camera is smeared or sharp.

## 6. Who owns what

| Layer | Owns |
|--------|------|
| **Visual (this repo)** | YOLO / CoreML → **`FramePayload`**, Flask bridge, simulation |
| **iOS app** | Session lifecycle, camera permissions, `CameraPipeline`, routing JSON to UI/Audio |
| **Audio** | Pan/distance/identity **semantics** from **`objects[]`** |
