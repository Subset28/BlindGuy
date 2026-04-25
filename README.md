# BlindGuy

A project for visual and audio assistance.

## Visual Branch Quick Start

This repository now includes a complete Python-based Visual Engine implementation
that matches the PRD contract for real-time object detection payloads.
It is fully standalone.

### 1) Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2) Run vision service

**Laptop camera only (quick dev):**

```bash
PYTHONPATH=src python -m visual_engine.main --host 127.0.0.1 --port 8765
```

**iPhone camera → Mac on the same Wi-Fi (for Swift UI/UX + Audio partners):** bind to all interfaces and do not open the laptop webcam. The iOS app POSTs JPEG frames; everyone still uses the same JSON.

```bash
PYTHONPATH=src python -m visual_engine.main --host 0.0.0.0 --port 8765 --no-local-camera
```

Point the iOS app at `http://<your-mac-lan-ip>:8765` (`POST /infer` with a JPEG, or `GET /frame` to poll the latest). See `docs/visual-integration.md` and `docs/contract.example.json` for the exact contract and Swift notes.

### 3) Endpoints

- `GET /health` - service heartbeat + live performance stats.
- `GET /frame` - latest detection payload in the shared JSON contract.
- `POST /infer` - one JPEG (raw body or multipart field `image`); same JSON in the response, and it updates the snapshot for `GET /frame`.

### 4) Optional calibration

Distance uses:

```text
distance_m = (known_object_height_m * focal_length_px) / bbox_height_px
```

Override the default focal length:

```bash
PYTHONPATH=src python -m visual_engine.main --focal-length-px 900
```

You can also compute focal length from one or more measured samples:

```bash
PYTHONPATH=src python -m visual_engine.calibration \
  --known-height-m 1.7 \
  --known-distance-m 3.0 \
  --bbox-heights-px 475 482 469
```

### 5) Integration handoff

See `docs/visual-integration.md` for the JSON contract and bridge notes.

**Visual branch changelog (append-only):** `docs/VISION_BRANCH_LOG.md` — add a dated entry whenever you merge vision contract or pipeline changes.

### 6) iPhone / SwiftUI (on-device vision)

The **`ios/BlindGuyKit`** Swift package runs **YOLOv8n** with **CoreML + Vision** on the phone, outputs the same **`FramePayload`** shape as `docs/contract.example.json`, and includes **`BlindGuySession`** for SwiftUI. Export the model with `python3 scripts/export_coreml.py`, then follow **`ios/README.md`** (camera preset, frame rate, orientation, performance knobs, **lens / smudge** detection + TTS on iOS).

### 7) Tests and validation

**Pytest (recommended with venv and `pip install -r requirements.txt`):**

```bash
pytest -q
```

**Built-in testing engine (no pytest required):** runs schema + lens smokes in-process.

```bash
PYTHONPATH=src python3 -m visual_engine.testing_engine
```

The same validators live in `src/visual_engine/testing_engine.py` (`validate_frame_payload`, `run_built_in_smoke`).

### 8) Simulation (no camera, no phone)

Synthetic BGR frames for bench demos and CI (lens path never needs YOLO):

```bash
PYTHONPATH=src python3 -m visual_engine.simulation --scenario lens_streak
PYTHONPATH=src python3 -m visual_engine.simulation --scenario lens_sharp
# slow: requires ultralytics + yolov8n download
PYTHONPATH=src python3 -m visual_engine.simulation --scenario vision_random --frames 1
```

Use `--print` for full JSON (with payload array) or `--payloads-only` for the frame list only.
