# BlindGuy ◉

<div align="center">

```
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║              ◉  B L I N D G U Y   E N G I N E            ║
  ║                                                           ║
  ║      Hearing Through Sight  |  On-Device First           ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
```

**Academies of Loudoun 2026 Hackathon · CLONE Theme**

![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Python%20Bridge-0D1117?style=for-the-badge&labelColor=161B22)
![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=for-the-badge&logo=swift&logoColor=white)
![CoreML](https://img.shields.io/badge/CoreML-ON--DEVICE-2563EB?style=for-the-badge)
![YOLOv8m](https://img.shields.io/badge/YOLOv8m-Open%20Images%20V7-22C55E?style=for-the-badge)
![Offline](https://img.shields.io/badge/100%25-Offline%20Inference-16A34A?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-8B5CF6?style=for-the-badge)

</div>

---

## Why We Built This

Most assistive tools solve one narrow problem at a time. Real life is not narrow.

BlindGuy is built for fast, crowded, unpredictable spaces where important things can be silent, partially visible, and moving. We wanted a system that can:

- understand what is in front of the user,
- estimate where it is (left/right and distance),
- prioritize what matters most,
- speak only what is useful.

Our design target is **low-latency, private, on-device assistance**.

For this hackathon's **CLONE** theme, our core idea is simple:  
we are **cloning human eyes into an always-on perception engine** that can speak what vision sees.

---

## The BlindGuy Experience

When the app runs, the phone camera feeds an on-device vision pipeline. The hearing engine converts detections into concise spoken cues with dedupe, cooldowns, priority logic, and strict pan gating to reduce noise.

### 1) Sight → Hearing (primary path)

- **Vision model:** YOLOv8m pretrained on **Open Images V7** (`yolov8m-oiv7`).
- **Runtime:** CoreML + Vision on iPhone.
- **Output contract:** shared `FramePayload` JSON (`docs/contract.example.json`).
- **Hearing logic:** front-focused, risk-aware, rate-limited speech.

### 2) Motion + urgency awareness

Tracking preserves `object_id` and estimates `velocity_mps` between frames. Nearby high-priority objects are escalated while low-value clutter is deprioritized.
---

## Architecture (Repo Map)

- `App/` - iOS app runtime (`AppViewModel`, `HearingEngine`, UI, model bundle)
- `ios/BlindGuyKit/` - reusable Swift package (camera pipeline, detector, tracker, payload models)
- `src/visual_engine/` - Python reference engine + Flask bridge
- `docs/` - PRD, contract, wiring docs, release checklist, vision changelog
- `scripts/` - model export + class mapping generation

---
## Distance + Spatial Model

Distance is monocular estimation using known object sizes and camera geometry. Pan is normalized to `[-1, 1]` and used by hearing for left/right phrases, threat ranking, and side suppression.

---
