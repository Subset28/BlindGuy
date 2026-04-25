# 📄 PRD: BlindGuy — The 3D Auditory Twin
**Academies Hacks 2026 | Theme: CLONING**
**Prepared by:** Senior Technical Product Manager
**Deadline:** 24 Hours | **Team Size:** 3 Developers
**Version:** 1.2.4 — COMPETITION DRAFT (as-built: `main` trunk, iOS hearing 3D audio bubble w/ HRTF on headphones, Python `/frame`/`/payload`; `VISION_BRANCH_LOG` continual-updates policy)

> **PRD maintenance (engineering):** When behavior or the JSON contract changes, update **§4**, **§4.1**, and **§4.2** in this file, bump the **Version** line (minor for contract/tooling, patch for typos), and keep **`docs/contract.example.json`**, **`README.md`**, and **`docs/visual-integration.md`** in sync. **Continually** append to **`docs/VISION_BRANCH_LOG.md`**—a short bullet in the same commit for **each** vision- or contract-scoped change (not only at the end of a sprint). This file is the single narrative source for judges + teammates; the repo is the source of truth for exact flags and filenames.

**Ship target (this team):** **iPhone (iOS)** on the user’s body (lanyard or chest mount), with **AirPods Pro** for spatial output. The phone is the camera and the runtime for **Swift** (UI/UX + Audio). Vision ML is **YOLOv8n**; production inference is **on-device** (see Edge Processing). A **local Python bridge** in this repo is for integration and dev only (see below).

---

## 1. Concept & Theme Alignment

**Theme (CLONING):** The product “clones” the physical world into a **3D auditory twin** — not a list of labels, but spatial audio objects that move with real objects (position, distance, priority).

**Who it is for:** People who are blind or have low vision navigating streets where many hazards are **visually** obvious but **acoustically** silent (EVs, e‑bikes, etc.).

**What success looks like:** **Sub‑100ms** perception-to-audio for relevant objects in class scope, with **on-device** inference and **no cloud dependency** during live use (pitch requirement).

---

## 🚀 The Winning Code Stack (iOS Edition)

To achieve sub-100ms latency and "utter beauty," we are using a **hybrid** stack. **Primary delivery is iOS (iPhone).** Android-specific APIs below are **optional** if the team ships iOS only.

### **Mobile (The Sensor & Output) — iPhone (primary)**
- **Language / UI:** **Swift** + **SwiftUI** (zero-touch lanyard UI, judge debug surface).
- **Camera & mic:** **AVFoundation** (capture path on the phone). Use **`Combine`** (or `Observation`) for low-latency binding between **Vision** and **Hearing** engines.
- **Spatial audio (iOS):** **AVAudioEngine** with **`AVAudioEnvironmentNode`** (Apple HRTF). AirPods Pro for binaural output; head tracking is a **bonus** if time allows.
- **(Alternate / not required for this team)** Android + `Camera2` + `AudioTrack` + Resonance Audio if a separate Android build is ever scoped.

### **AI Engine (The Vision)**
- **Model:** **YOLOv8 (Nano)** — `yolov8n` (Ultralytics / export to **CoreML** `.mlpackage` for on-device iOS).
- **On-device iOS (target):** **CoreML** + Neural Engine / GPU (quantized **INT8** when exported for deployment).
- **Reference / dev (in this repo):** **Python 3** + **Flask** + `ultralytics` + `opencv-python` (camera or **JPEG-in** inference), same **`FramePayload` JSON** as the app. Live judge page: `GET /judge` on the local bridge.

### **Cloud & Dashboard (The Judge Experience)**
- **Optional** for the live user path. Local-only operation is a **sponsor and safety story**.
- **In-repo (works today):** **Flask** on the laptop/edge for `/infer`, `/frame`, and **`/judge`** — no cloud required.
- **If the team deploys external telemetry later:** **FastAPI** on **GCP Cloud Run** + **Firebase** (or similar) is compatible for a remote judge view — **not** required for live inference.

---

## 2. User Experience (UX) Flow

### The Problem

Over **7 million Americans** are visually impaired. The modern street is increasingly silent — electric vehicles (EVs) produce almost no audible warning below 18 mph. High-speed cyclists and e-scooters are similarly ghost-like. Existing assistive tech (white canes, guide dogs) offers zero real-time threat detection for fast-moving silent obstacles. People are dying from threats they literally cannot hear.

### The "Cloning" Solution: The 3D Auditory Twin

> **We are not building a navigation app. We are building a second pair of eyes that speaks directly into the brain.**

The "Cloning" theme is not a metaphor — it is the core architecture.

**Every real-world object detected by YOLOv8 gets cloned as an "Audio Object" in a virtual 3D soundscape.** This Audio Clone is not a notification or a ping. It is a living, breathing sonic representation of a physical entity — mirroring its position, velocity, direction, and distance in real time.

| Physical World | Auditory Twin (The Clone) |
|---|---|
| A car 10m to the left, approaching fast | A deep low-frequency rumble, panning hard-left, rising in pitch and volume |
| A cyclist 4m ahead, stationary | A steady mid-tone centered in stereo field |
| A pedestrian 2m to the right, walking away | A soft receding tone, panning right and fading |

The result is a **Spatial Radar** — a 3D audio clone of the user's physical environment that exists entirely within their AirPods. The blind user does not hear a description of the world. They *feel the shape of it* through sound.

**This is cloning.** The physical world is duplicated as a real-time acoustic twin.

---

## 2. User Experience (UX) Flow

### Hardware Setup
- **iPhone** — worn on a lanyard around the neck or mounted on the chest. Camera faces forward. No hands required.
- **AirPods Pro** — mandatory for binaural/HRTF spatial audio output. The headphones are the output display.

### Interface Philosophy: Zero-Touch
The app has **no active UI**. It boots, detects the camera feed, connects to AirPods, and runs. The user never touches their phone. The phone is a sensor, not a screen.

**App States:**
1. `IDLE` — Listening for motion trigger or manual start.
2. `SCANNING` — YOLOv8 actively processing frames, spatial audio engine live.
3. `ALERT` — High-priority threat detected (EV, fast-moving object). Audio intensity spikes.
4. `DEBUG` (Judge Mode) — Overlay UI showing bounding boxes, JSON feed, and latency metrics.

### The Spatial Radar Feedback Loop

This is the core user experience. Here is exactly how the "Spatial Radar" effect works:

**Step 1 — Capture:** iPhone camera captures 30fps video stream.

**Step 2 — Detect (Vision Engine):** YOLOv8 identifies objects with bounding box coordinates and confidence scores. The bounding box size relative to frame area is used to estimate distance via inverse proportion math.

**Step 3 — Clone (Bridge):** The Vision Engine outputs a JSON payload for each detected object. The Bridge serializes this and passes it to the Audio Engine with sub-10ms handoff latency.

**Step 4 — Render (Audio Engine):** Each JSON object is instantiated as an **Audio Clone**:
- **Horizontal Position** → Stereo pan (left/right)
- **Distance** → Volume (far = quiet, close = loud) + pitch (far = low, close = high)
- **Object Class** → Unique audio signature (cars get a low rumble; people get a soft tone; cyclists get a mid buzz)
- **Velocity (if tracked)** → Doppler-effect pitch modulation — approaching objects rise in pitch, receding fall

**Step 5 — Feel:** The user processes this soundscape intuitively. No training needed. The human brain is already wired for spatial sound. Within minutes, users describe it as *feeling* the space around them.

---

## 3. Branch-Specific Engineering Tasks

> All branches are cut from `main`. PRs merge into `main` at the integration checkpoint (Hour 18). Build buffer is Hours 18–22. Demo prep is Hours 22–24.

---

### Branch 1: `Visual` — AI Lead

**Goal:** Deliver a real-time object detection module that outputs a clean JSON stream.

**Tech:** Python, YOLOv8 (Ultralytics), OpenCV, CoreML (optional for on-device iOS)

#### Tasks:

**T1.1 — YOLOv8 Setup**
- Install `ultralytics` package. Use `yolov8n.pt` (nano model — fastest, lowest latency).
- Target classes: `person`, `car`, `bicycle`, `motorcycle`, `truck`, `bus`. Ignore everything else.
- Filter confidence threshold: `>= 0.55`. Below this, do not emit.

**T1.2 — Bounding Box-to-Distance Math**
No LiDAR, no depth camera. Use monocular estimation:
```
estimated_distance_m = (known_object_height_m * focal_length_px) / bounding_box_height_px
```
Reference heights (meters) used in the Visual implementation: `person=1.7`, `car=1.5`, `bicycle=1.1`, `motorcycle=1.3`, `truck=3.5`, `bus=3.2`

Focal length: calibrate once using a known object at a known distance (e.g. a 1.7m person at 3m), then set **`focal_length_px`** to match. Default in code: **850** (override via CLI; see **§4.1**).

For horizontal position, normalize the bounding box center X to `[-1.0, 1.0]`:
```
pan_value = (bbox_center_x / frame_width - 0.5) * 2.0
```

**T1.3 — JSON Output Format (THE CONTRACT)**
Emit a **JSON object** (not an array) at **~15 Hz** (~66 ms). Same schema in **Section 4**; one top-level `objects` array.

**T1.4 — Performance Gate**
Vision processing must complete in < 50ms per frame on iPhone 12 or newer. Profile with `time.perf_counter()`. If > 50ms, drop to 10fps or reduce input resolution to 480p.

---

### Branch 2: `Audio` — Audio Lead

**Goal:** Consume JSON object payloads and render a real-time binaural spatial soundscape through AirPods Pro.

**Tech:** Java (Android) or Swift (iOS) + AVFoundation / AudioKit, HRTF via AVAudioEnvironmentNode

#### Tasks:

**T2.1 — HRTF Spatial Audio Setup**
- Use `AVAudioEnvironmentNode` (iOS) which implements Apple's built-in HRTF engine.
- Place the listener at `(0, 0, 0)`. Each audio clone is positioned in 3D space relative to the listener.
- Enable **Head Tracking** via AirPods Pro motion data if time permits (bonus points).

**T2.2 — Audio Clone Instantiation**
For each object in the JSON payload:
- Map `object_id` to a persistent `AVAudioPlayerNode`.
- Assign a unique audio signature per `class`:
  - `car`, `truck`, `bus` → Low sine-wave rumble (80–120 Hz)
  - `person` → Soft mid-range tone (440 Hz)
  - `bicycle`, `motorcycle` → Buzzing mid-tone (300 Hz)
- Persistent nodes: do not create/destroy nodes per frame. Pool them and update position each tick.

**T2.3 — Proximity-Based Modulation**
Map `distance_m` to audio properties:
```
volume     = clamp(1.0 - (distance_m / MAX_RANGE), 0.05, 1.0)  // MAX_RANGE = 20m
pitch_rate = clamp(1.0 + (5.0 - distance_m) * 0.05, 0.8, 1.5)  // rises as closer
```
Map `pan_value` directly to the node's 3D X position:
```
node.position = AVAudio3DPoint(x: pan_value * 10, y: 0, z: -distance_m)
```

**T2.4 — Alert Mode**
If any object has `distance_m < 3.0` AND `velocity > 1.5 m/s` (if tracked), trigger:
- Haptic feedback (if available)
- Sharply rising tone + volume spike on that specific clone
- Interrupt/duck all other clones by 60%

**T2.5 — Latency Gate**
Audio engine update loop must complete in < 30ms per tick. Do NOT run on the main thread. Use a dedicated high-priority `DispatchQueue` or `HandlerThread`.

---

### Branch 3: `UI/UX` — Team Lead / Bridge

**Goal:** Wire the Vision Engine and Audio Engine together, build the zero-touch "Lanyard Mode" UI, and build the Judge Debug Dashboard.

**Tech:** Swift (iOS), Python-to-Swift IPC or REST bridge, SwiftUI

#### Tasks:

**T3.1 — Thread Management / Bridge Architecture**
The on-device app uses **Swift**; for integration and dev, a **Python** process can expose the same contract.

**Option A (Implemented in this repo, dev + integration with iOS):** **Flask** (not FastAPI) on **port `8765`**, same default as the PRD.
- **`GET /health`** — process up, `frame_id`, moving averages, `inference_source`, etc.
- **`GET /frame`** — latest full payload (for polling at ~15 Hz or for the judge JSON panel).
- **`POST /infer`** — iPhone (or any client) sends a **JPEG** (raw `image/jpeg` body, or `multipart/form-data` field **`image`**). Returns the **same JSON** as `GET /frame` and **updates** the latest snapshot (so `GET /frame` and Audio stay aligned).
- **`OPTIONS` + CORS** — `Access-Control-Allow-Origin: *` for a browser-based judge UI if needed.
- **LAN (iPhone → Mac for hackathon build):** run the server with **`--host 0.0.0.0`**; iOS base URL is `http://<mac-lan-ip>:8765`. iOS may require **App Transport Security** exceptions for local HTTP. Use **`--no-local-camera`** when the **only** image source is the iPhone (no OpenCV Mac webcam).
- **Local Mac/PC only (no iPhone):** run without `--no-local-camera` to use a laptop webcam; **`GET /frame`** auto-refreshes at the target rate.

**Option B:** Unix socket IPC (not implemented here).

**Production iOS (no Mac in the path):** **AVFoundation** capture + **on-device** **CoreML** YOLOv8n, outputting the **identical in-memory or in-process** struct as this JSON. **No HTTP** between vision and audio in the ideal path.

Handoff budget: < 10ms where a bridge exists. Use **`timestamp_ms`** and **`vision_duration_ms`** in the payload to measure.

**T3.2 — Lanyard Mode UI**
This is what the user sees (barely):
- Fullscreen black screen.
- Single large status indicator: `●` green = ACTIVE, `●` yellow = LOW CONFIDENCE, `●` red = ALERT.
- Font: SF Pro Rounded, 72pt. Nothing else.
- Auto-lock disabled. Screen brightness minimum (saves battery, reduces distraction).
- No buttons. Shake to toggle Debug Mode.

**T3.3 — Judge Debug Dashboard (Critical for Winning)**
This is what the judges see. Shake the phone twice to activate:
- Live camera feed with bounding boxes overlaid (YOLOv8 annotations).
- Scrolling JSON feed panel showing the live payload.
- Latency meter: Vision `__ms` | Bridge `__ms` | Audio `__ms` | Total `__ms`.
- Object count and class distribution bar chart.
- The dashboard must look polished. Use a dark theme with green accent (`#00FF88`). Judges are evaluating technical depth — make it visible.

**T3.4 — App Lifecycle**
- App must run in background (enable Background Modes: `audio`, `location` if needed).
- Auto-restart vision loop on foreground.
- Handle AirPods connection/disconnection gracefully (fall back to phone speaker mono).

---

## 4. Technical Constraints

### Latency Budget: < 100ms End-to-End

| Stage | Budget |
|---|---|
| Frame Capture → YOLOv8 Detection | ≤ 50ms |
| Vision Engine → Bridge Serialization | ≤ 5ms |
| Bridge → Audio Engine Handoff | ≤ 10ms |
| Audio Engine → Node Update | ≤ 30ms |
| **Total** | **≤ 95ms** |

> **If you miss 100ms, a person can walk into traffic before the alert fires. This is not a performance metric. It is a safety requirement.**

### Edge Processing: Local-Only (production path)

- **User-facing / pitch path:** **Zero cloud** during live assist. **All ML inference on the iPhone** (CoreML `yolov8n` or equivalent on-device). **No network required** to interpret the world or drive spatial audio in that mode.
- **Exception (development only):** the **Python Flask bridge** may run on a **Mac** and accept **LAN `POST /infer`** from the phone for faster team integration. That path **is not** the sponsor “edge-only” story until inference moves fully on-device (see **§4.1**).
- Model: `yolov8n` — **CoreML** `.mlpackage` (iOS), optional ONNX for tooling.
- Explicitly compatible with **GT Edge AI sponsor requirements** when the **iOS on-device** path is what you demo: say **"100% on-device inference, zero network dependency"** for that configuration.
- Battery optimization: process every other frame at idle walking speed, every frame in high-motion environments (use accelerometer delta to gate processing rate).

### The JSON Contract — Exact Schema

```json
{
  "frame_id": 1042,
  "timestamp_ms": 1714052800123,
  "vision_duration_ms": 34,
  "camera": {
    "lens_status": "ok",
    "lens_laplacian_var": 235.4,
    "lens_announce": null
  },
  "objects": [
    {
      "object_id": "car_001",
      "class": "car",
      "confidence": 0.87,
      "bbox": {
        "x_center_norm": 0.32,
        "y_center_norm": 0.61,
        "width_norm": 0.18,
        "height_norm": 0.14
      },
      "distance_m": 8.4,
      "pan_value": -0.36,
      "velocity_mps": 2.1,
      "priority": "HIGH"
    }
  ]
}
```

**Field Definitions:**
- `object_id` — Persistent across frames for the same tracked object. Format: `{class}_{3-digit-counter}`.
- `pan_value` — Range `[-1.0, 1.0]`. `-1.0` = hard left, `1.0` = hard right.
- `priority` — `"HIGH"` if `distance_m < 3.0`, else `"NORMAL"`.
- `velocity_mps` — **Implemented** in both the **Python** visual service and **`BlindGuyKit` (iOS)** as a scalar (meters per second, estimated from distance change between frames on a stable `object_id`). If tracking is disabled in a future build, use `0.0`; the field stays in the contract for Audio.
- `camera` — **Optional** in transport when lens checks are off; when present: `lens_status` (`ok` | `warning`), `lens_laplacian_var` (sharpness proxy), `lens_announce` (string for TTS when `warning`, else `null`). Used to warn when the **lens may be smudged** (low multi-frame sharpness / Laplacian variance).
- All `_norm` bbox values are normalized `[0.0, 1.0]` relative to frame dimensions.

---

## 4.1 Vision implementation (this repository, on `main`, iPhone-focused)

This section records what the **`Visual` branch code** does today so **UI/UX**, **Audio**, and **judge tooling** share one truth. **Runtime target for the product is still the iPhone on iOS**; the Python service is the **reference implementation** and **integration bridge** until CoreML runs the same model on-device.

| Topic | Specific |
|--------|-----------|
| **Platform (user)** | **iOS** app on **iPhone**; camera forward; AirPods Pro for spatial output. |
| **Vision model** | **YOLOv8n** via **Ultralytics**; weights file **`yolov8n.pt`** (downloaded on first run by the library). |
| **Classes emitted** | `person`, `car`, `bicycle`, `motorcycle`, `truck`, `bus` only; all other COCO classes discarded. |
| **Confidence** | Detections below **0.55** are suppressed at inference (`conf` threshold). |
| **Distance** | `estimated_distance_m = (known_object_height_m * focal_length_px) / bbox_height_px` using reference heights in **T1.2**; **default `focal_length_px` = 850** (re-calibrate per camera with `visual_engine.calibration` + `--focal-length-px` on the server). |
| **Pan** | `pan_value = (bbox_center_x / frame_width - 0.5) * 2.0`, clamped to **[-1, 1]**. |
| **Tracking** | **Persistent `object_id`** per class with simple bbox association; **velocity_mps** from inter-frame distance delta / dt. |
| **Rate** | Target **15 Hz** emit for local webcam loop; if rolling average **vision** time **> 50 ms**, effective output rate **falls back to 10 Hz**. iOS-POST mode: client should send **~10–15 JPEG/s** to match. |
| **Input resolution (webcam default)** | **640×480** OpenCV pull (device-dependent). iPhone JPEGs use native capture size; same math on pixel bbox height. |
| **Server** | **Flask**; default bind **`127.0.0.1:8765`**; use **`0.0.0.0`** for LAN. |
| **HTTP API** | `GET /health`, `GET /frame`, `POST /infer` (JPEG), CORS for dashboards. |
| **Docs in repo** | `docs/visual-integration.md` (team handoff), `docs/contract.example.json` (example payload), **`docs/VISION_BRANCH_LOG.md`** (append-only **vision pipeline** log; all work on **`main`**). |
| **Dependencies** | `flask`, `ultralytics`, `opencv-python`, `numpy` (see `requirements.txt`). |
| **iOS on-device (Swift / SwiftUI)** | Swift package **`ios/BlindGuyKit`**: **CoreML** + **Vision** (`VNCoreMLRequest`), **YOLOv8n** exported with **NMS** (`scripts/export_coreml.py`), **`FramePayload`** / **`DetectedObjectDTO`** `Codable` types matching Section 4, **`OnDeviceVisionEngine`** (serial queue, **~15 Hz** emit cap, **drop** if inference still running, `VNImageOption.preferBackgroundProcessing`), **`BlindGuySession`** (`ObservableObject`, `@Published lastPayload`) for SwiftUI. **Lens / smudge:** `LensQualityAnalyzer` + **`LensWarningAnnouncer`** (iOS, `AVSpeechSynthesizer`, cooldown). Integrate: add local package in Xcode, bundle **`yolov8n.mlpackage`** in the **app** target, `AVCaptureVideoDataOutput` → `CVPixelBuffer` → `session.ingest(...)`. See **`ios/README.md`**. |
| **Tests** | **Pytest** (`tests/`, `pytest.ini`); **`python -m visual_engine.testing_engine`** in-process smokes; `validate_frame_payload` for schema. |
| **Smudge / dirty lens (Python + iOS)** | Laplacian variance on a downscaled grayscale frame; if below **`lens_laplacian_threshold` for N consecutive** frames, set `lens_status: warning` and a **`lens_announce`** string. Tuned via `VisualConfig` / `VisionConfiguration`. |

**Pitch wording (edge AI):** For sponsor and safety messaging, the **product** is **100% on-device inference** in production. **Mac + Wi-Fi + `POST /infer`** is a **non-shipping integration path** for the hackathon; do not claim “zero network” if that path is what you demo without moving inference onto the phone.

---

## 4.2 As-built repository map (maintain with code)

This section is the **living index** of what exists in the repo today. Update it when you add files, change entrypoints, or change the contract.

### Python — `src/visual_engine/`

| Module | Purpose |
|--------|---------|
| `config.py` | `VisualConfig`: YOLO path, class set, `confidence_threshold`, height table, `focal_length_px`, **lens** toggles and thresholds, emit/rate and tracking knobs. |
| `contracts.py` | `DetectedObject`, `BBoxNorm`, `make_frame_payload` (optional **`camera`** block). |
| `vision_engine.py` | YOLO inference, pan/distance, `VisionResult`. |
| `tracker.py` | `object_id` + `velocity_mps` + `priority`. |
| `lens_quality.py` | Laplacian sharpness, **`LensWarningState`** (consecutive low-variance → warning). |
| `app.py` | **Flask** `VisionService`, `GET /health`, `GET /frame`, `POST /infer`, CORS; optional local webcam; merges detections + lens into one payload. |
| `main.py` | CLI: `--host`, `--port`, `--camera-index`, `--confidence`, `--focal-length-px`, `--emit-hz`, **`--no-local-camera`**. |
| `calibration.py` | CLI: compute **`focal_length_px`** from measured height/distance and bbox height samples. |
| `testing_engine.py` | **Testing engine:** `validate_frame_payload`, `run_built_in_smoke` / `TestReport` (includes **`smoke_simulation`**); no pytest required. Run: `PYTHONPATH=src python -m visual_engine.testing_engine`. |
| `synthesis.py` | **Synthetic BGR** images: random sharp, Gaussian blur, **uniform** field, **lens_streak_sequence** (labelled sharp/blur) — no camera. |
| `simulation.py` | **Simulation engine:** `SimulationEngine` + **`SimulationReport`**; scenarios **`lens_streak`**, **`lens_sharp`**, **`vision_random`** (lazy-imports YOLO). CLI: `python -m visual_engine.simulation`. **Does not** require `ultralytics` for lens-only scenarios. |

**Tests:** `tests/` (pytest), `pytest.ini` (`pythonpath = src`, marker **`slow`** for YOLO). Run: `pytest -q` after `pip install -r requirements.txt`. Skip slow: `pytest -m "not slow"`.

**Top-level `requirements.txt`:** `flask`, `numpy`, `opencv-python`, `ultralytics`, `pytest` (and transitive deps).

**Root `README.md`:** venv, run server (laptop cam vs iPhone → Mac), calibration, iOS package pointer, **testing** section (pytest + testing engine).

### iOS — `ios/BlindGuyKit/` (Swift package)

| Area | Purpose |
|------|---------|
| `Package.swift` | iOS 16+ (and macOS 13+ for `swift build` of the library on a dev machine). |
| `ContractModels.swift` | `FramePayload`, `DetectedObjectDTO`, **`CameraHealthDTO`**, `BBoxNorm` (snake_case JSON). |
| `VisionConfiguration.swift` | Mirrors Python tuning: classes, conf, heights, focal, **lens** fields, 15Hz-style `minEmitInterval`. |
| `COCOMapping.swift` | COCO index / name for Vision labels. |
| `CoreMLDetector.swift` | Load `yolov8n` from bundle, `VNCoreMLRequest`, `VNRecognizedObjectObservation` → `RawDetection`. |
| `ObjectTracker.swift` | Same ID/velocity/priority story as Python. |
| `VisionGeometry.swift` | Vision bbox → PRD pan/distance. |
| `OnDeviceVisionEngine.swift` | CoreML+Vision + tracker + **lens** on each emitted frame; backpressure and rate cap. |
| `BlindGuySession.swift` | SwiftUI `ObservableObject`, **`enableLensSpeech`** and **`lensAnnouncer`**. |
| `LensQualityAnalyzer.swift` | Laplacian on downscaled BGRA path; `LensStreakState`. |
| `LensWarningAnnouncer.swift` (iOS) | **`AVSpeechSynthesizer`**, debounced, for `lens_announce`. |

**`ios/README.md`:** add package to Xcode, **export CoreML** (`scripts/export_coreml.py`), camera wiring, **lens** + TTS, performance notes, testing note (Xcode vs CLI).

**`scripts/export_coreml.py`:** Ultralytics `yolov8n` → CoreML with **NMS** for Vision.

### Implementation changelog (high level)

| Version / note | What landed |
|----------------|-------------|
| **PRD 1.0** | Original competition draft (concept, branches, JSON contract). |
| **PRD 1.1** | iPhone ship target, Flask bridge details, §4.1 Visual table, CoreML / Swift path described. |
| **PRD 1.2 (this)** | **`camera` / lens-smudge** in schema and both stacks; **pytest** + **`testing_engine`**; **PRD + docs** process above; `ios/BlindGuyKit` file map; as-built **§4.2**. |

---

## 5. The Winning Pitch

### 30-Second Elevator Pitch (Memorize This)

> *"When a blind person walks outside, they are navigating a world that has gone silent. Electric cars make no sound. Cyclists make no sound. And by the time they hear something, it's too late.*
>
> *BlindGuy clones the physical world into a 3D audio twin — running live, on-device, with no internet required. Every car, every person, every bike around you gets cloned as a spatial sound object in your AirPods. Move left, the sound moves left. Get closer, the pitch rises. We didn't build an app that talks to blind people. We built a second pair of eyes that lives inside their ears.*
>
> *100% on-device. Under 100 milliseconds. Built in 24 hours. This is cloning."*

---

## Appendix: 24-Hour Build Timeline

| Hours | Milestone |
|---|---|
| 0–2 | Repo setup, branch cuts, dev environment confirmed on all 3 machines |
| 2–8 | Parallel dev: Vision (YOLOv8 running + JSON output), Audio (spatial node setup), Bridge (Flask server + Swift client) |
| 8–12 | First integration: JSON flowing from Vision → Bridge → Audio. Any sound playing spatially. |
| 12–16 | Polish: Distance math tuned, audio signatures differentiated, alert mode working |
| 16–18 | Debug Dashboard built and populated with live data |
| 18–20 | Full end-to-end test. Measure actual latency. Fix blockers only. |
| 20–22 | Demo rehearsal. Test on a real street (or hallway). Tune audio for AirPods. |
| 22–24 | Pitch rehearsal, slide deck if required, rest. |

> **Rule:** If a feature isn't working by Hour 16, cut it. A working demo that does 3 things well beats a broken demo that claims 10 features.
