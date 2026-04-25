# Visual branch — engineering log

This file is **append-only** (add new entries at the **top** under the date). It records work that belongs to the **`Visual` branch**: on-device / reference **vision pipeline**, **JSON contract**, **Python bridge**, **tests**, and **PRD/docs** updates that describe vision only. **Audio** and **UI/UX** app code should log in their own docs if needed.

**How to use:** when you ship a PR to `Visual` (or merge vision-related changes), add a short bullet under today’s date: what changed, which paths, and why.

---

## 2026-04-26

- **Synthesis** (`synthesis.py`): random sharp BGR, Gaussian blur, flat **uniform** field, **`lens_streak_sequence()`** (tagged sharp/blur) for reproducible smudge demos without hardware.
- **Simulation engine** (`simulation.py`): **`SimulationEngine`**, **`SimulationReport`**; **`lens_streak`** / **`lens_sharp`** (no YOLO import) and **`vision_random`** (lazy `VisionEngine` + full contract); CLI **`python -m visual_engine.simulation`** with `--print` / `--payloads-only`. Lens-only path works in CI without `ultralytics`.
- **Tests:** `test_synthesis.py`, `test_simulation.py`; **`smoke_simulation`** in **`testing_engine.run_built_in_smoke`**. Pytest marker **`slow`** for optional YOLO sim.
- **Docs:** README §8 simulation; **PRD** §4.2 table rows for `synthesis` / `simulation`.

---

## 2026-04-25

- **Scaffolded Python vision service** (`src/visual_engine/`): Ultralytics **YOLOv8n**, six PRD classes, confidence **≥ 0.55**, monocular distance + pan, simple **object_id** tracking and **velocity_mps** / **priority**, **~15 Hz** emit with **10 Hz** fallback when average detection time exceeds the gate.
- **Flask bridge** (`app.py`, `main.py`): **`GET /health`**, **`GET /frame`**, **`POST /infer`** (JPEG body or multipart `image`), CORS; **`--no-local-camera`** for iPhone-only capture to Mac; default port **8765**.
- **Contract** (`contracts.py`): `make_frame_payload` aligned with PRD; optional **`camera`** block when lens checks are on.
- **Lens / smudge heuristic** (`lens_quality.py`): Laplacian variance on downscaled gray frame; consecutive low readings → **`lens_status: warning`** and **`lens_announce`** text; tunable via **`VisualConfig`**.
- **Calibration CLI** (`calibration.py`): compute **`focal_length_px`** from real-world measurements.
- **Testing engine** (`testing_engine.py`): `validate_frame_payload`, in-process **`run_built_in_smoke`**; CLI **`python -m visual_engine.testing_engine`** with `PYTHONPATH=src`.
- **Pytest** (`tests/`, `pytest.ini`): contract, lens, testing-engine tests; **`requirements.txt`** includes **pytest** / **opencv-python** as needed.
- **On-device parity (iOS Swift package)** `ios/BlindGuyKit/`: CoreML + Vision, same **`FramePayload`** / **`camera`** shape, **`BlindGuySession`**, lens analysis + **iOS TTS** announcer for warnings; **`scripts/export_coreml.py`** for **yolov8n** → CoreML with NMS.
- **Documentation**: `docs/visual-integration.md`, `docs/contract.example.json`, root **`README.md`**, **`ios/README.md`**, **`PRD.md`** (§4, §4.1, §4.2) updated to match the above.
- **Vision-only log (this file):** created **`docs/VISION_BRANCH_LOG.md`** as the append-only **Visual branch** engineering log; **`PRD.md`** (maintenance note + §4.1 **Docs in repo** row) and **`README.md`** (integration handoff) now reference it.
- **E2E wiring (follow-up):** iOS **`CameraPipeline`** — **`AVCaptureSession`** (VGA, BGRA, back wide) → **`BlindGuySession.ingest`**; **`FramePayload+JSON.swift`** for debug/logging; **`docs/WIRING.md`** checklist; macOS compiles a stub that throws from **`start()`**.

---

## Template (copy when adding a new day)

```markdown
## YYYY-MM-DD

- …
```
