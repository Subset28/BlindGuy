# 📄 PRD: BlindGuy — The 3D Auditory Twin
**Academies Hacks 2026 | Theme: CLONING**
**Prepared by:** Senior Technical Product Manager
**Deadline:** 24 Hours | **Team Size:** 3 Developers
**Version:** 1.0 — COMPETITION DRAFT

---

## 1. Concept & Theme Alignment
... [content omitted for brevity] ...

---

## 🚀 The Winning Code Stack (iOS Edition)

To achieve sub-100ms latency and "utter beauty" on Apple hardware, we are utilizing the following native stack:

### **Mobile (The Sensor & Output)**
- **Language**: **Swift / SwiftUI**. We will use `AVFoundation` for high-speed camera frame capture and `Combine` for low-latency data binding between the Vision and Audio engines.
- **Spatial Audio**: **AVAudioEnvironmentNode**. This is Apple's native HRTF engine. It provides the most realistic 3D soundscape for AirPods Pro users, including head-tracking support.

### **AI Engine (The Vision)**
- **Model**: **YOLOv8 (Nano)**.
- **Inference**: **CoreML**. We will export the model to an `.mlpackage` to leverage the **Apple Neural Engine (ANE)**. This ensures that object detection happens in real-time without draining the battery or heating up the device.

### **Cloud & Dashboard (The Judge Experience)**
- **Backend**: **Python (FastAPI)**. Perfect for the real-time telemetry bridge.
- **Hosting**: **Google Cloud Platform (GCP) Cloud Run**.
- **Real-time Sync**: **Firebase Realtime Database**. Provides the sub-50ms sync needed to mirror the "Auditory Twin" from the iPhone to the Judge's web dashboard.

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
Reference heights (meters): `car=1.5`, `person=1.7`, `bicycle=1.1`, `truck=3.5`
Focal length: calibrate once using a known object at a known distance (e.g. a 1.7m person at 3m).

For horizontal position, normalize the bounding box center X to `[-1.0, 1.0]`:
```
pan_value = (bbox_center_x / frame_width - 0.5) * 2.0
```

**T1.3 — JSON Output Format (THE CONTRACT)**
Emit a JSON array at 15Hz (every 66ms). Format defined in Section 4.

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
The Vision Engine (Python) and Audio Engine (Swift) are two separate processes. Bridge them via:
- **Option A (Preferred):** Local HTTP server. Python runs a lightweight Flask server on `localhost:8765`. Swift polls or subscribes via `URLSession` at 15Hz.
- **Option B:** Unix socket IPC for sub-millisecond handoff (more complex, use only if Option A latency is insufficient).

Handoff budget: < 10ms. Measure with timestamps in JSON payload (see Section 4).

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

### Edge Processing: Local-Only

- Zero cloud calls during operation. All ML inference runs on-device.
- Model: `yolov8n` (CoreML exported `.mlpackage` for iOS, ONNX for Android/desktop).
- Explicitly compatible with **GT Edge AI sponsor requirements**. Mention "100% on-device inference, zero network dependency" in your pitch.
- Battery optimization: process every other frame at idle walking speed, every frame in high-motion environments (use accelerometer delta to gate processing rate).

### The JSON Contract — Exact Schema

```json
{
  "frame_id": 1042,
  "timestamp_ms": 1714052800123,
  "vision_duration_ms": 34,
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
- `velocity_mps` — Optional. `null` if object tracking is not implemented. Set to `0.0` as default.
- All `_norm` bbox values are normalized `[0.0, 1.0]` relative to frame dimensions.

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
