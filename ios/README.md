# BlindGuy on iOS (Swift / SwiftUI)

This folder contains **`BlindGuyKit`**, a Swift package that runs **YOLOv8n on-device** via **CoreML + Vision** and produces the **same JSON-shaped `FramePayload`** as the Python reference server (`docs/contract.example.json`).

Your **UI/UX** teammate can add the package to an Xcode app and bind SwiftUI to `BlindGuySession`. Your **Audio** teammate reads `lastPayload?.objects` (or subscribes with a thin adapter) and maps `class`, `pan_value`, `distance_m`, `object_id` into spatial audio.

## 1) Add the package in Xcode

1. **File → Add Package Dependencies… → Add Local…** and select `ios/BlindGuyKit`.
2. Add **`BlindGuyKit`** to your app target.

## 2) Export CoreML (`yolov8n.mlpackage`)

On a machine with Python + Ultralytics (from repo root):

```bash
pip install ultralytics
python3 scripts/export_coreml.py
```

Drag the generated **`yolov8n.mlpackage`** into the Xcode app target (not the package, unless you add a **Copy Bundle Resources** entry to the library—**simpler to keep the model in the app**). In code, load with:

```swift
let detector = try CoreMLDetector(modelResourceName: "yolov8n", bundle: .main)
let engine = OnDeviceVisionEngine(detector: detector)
let session = BlindGuySession(engine: engine)
```

Use the **Vision + NMS** export so `VNRecognizedObjectObservation` is produced. If you see zero detections, re-export with `nms=True` (the script does) and confirm the model is in **Copy Bundle Resources**.

## 3) Wire `AVCaptureSession` (minimal pattern)

- **Session preset:** prefer **`AVCaptureSession.Preset.vga640x480`** or **`hd1280x720`** for a balance of speed and range; lower resolution reduces Neural Engine load.
- **Frame rate:** cap to **15–30 fps** with `activeVideoMinFrameDuration` / `Max` as needed.
- **Queue:** implement `AVCaptureVideoDataOutputSampleBufferDelegate` on a **serial** `DispatchQueue` (not the main queue). In `captureOutput`, get `CMSampleBuffer` → `CVPixelBuffer`, then call:

```swift
session.ingest(
    pixelBuffer: pixelBuffer,
    orientation: .right // use the correct CGImagePropertyOrientation for your camera + device rotation
)
```

- **Orientation** must match the buffer. Wrong orientation breaks `pan_value` and distance. Use Apple’s guidance for mapping `UIDeviceOrientation` / connection to `CGImagePropertyOrientation`.

## 4) SwiftUI

```swift
struct LanyardRoot: View {
    @StateObject private var vision: BlindGuySession = {
        let d = try! CoreMLDetector(modelResourceName: "yolov8n", bundle: .main)
        return BlindGuySession(engine: OnDeviceVisionEngine(detector: d))
    }()

    var body: some View {
        Text(vision.lastPayload.map { "\($0.objects.count) objects" } ?? "…")
    }
}
```

Your UI partner owns the real **black / status-dot** layout from the PRD; this is only wiring.

## 5) Performance knobs (already in code + config)

| Knob | Location / behavior |
|------|----------------------|
| **15 Hz cap** | `VisionConfiguration.default.minEmitInterval` (1/15 s) drops extra frames before inference. |
| **Backpressure** | If a request is still running, new frames are dropped (`nil` completion). |
| **Background Vision** | `VNImageRequestHandler` uses `preferBackgroundProcessing`. |
| **Serial work queue** | One inference at a time on a high-priority queue. |
| **Class filter + conf** | Same as PRD: six classes, `confidence >= 0.55`. |
| **Calibration** | Adjust `focalLengthPixels` for the iPhone camera after a real-world tape measure + single reference object. |

## 6) Python bridge vs on-device

- **Shipping path (sponsor / latency story):** CoreML on the **phone** — no Mac, no Wi‑Fi required.
- **Python `POST /infer`:** optional for lab integration; see root `README.md`.

## 7) Lens / smudge detection (accessibility)

- **Payload:** `FramePayload.camera` with `lens_status`, `lens_laplacian_var`, `lens_announce` (see `docs/contract.example.json`).
- **Heuristic:** low Laplacian variance (blur / haze) for several frames in a row → `warning` and a non-null `lens_announce` string.
- **Speech (iOS):** `BlindGuySession` creates a **`LensWarningAnnouncer`** by default. Pass `enableLensSpeech: false` to disable.
- **Tuning:** `VisionConfiguration` — `lensLaplacianThreshold` (~100 for 400px long side, adjust per device), `lensWarnConsecutive` (default 4).

## 8) Tests

**Python (authoritative in CI):** from repo root, `pytest -q` and `PYTHONPATH=src python3 -m visual_engine.testing_engine`.

**This package (Xcode):** add a **Unit Test** target to your app, link `BlindGuyKit`, and use `XCTest` against `LensStreakState` / `LensQualityAnalyzer` if you want on-device matrix tests. Command-line `swift test` for iOS packages may need a full **Xcode** toolchain; building with `swift build` is the usual headless check.
