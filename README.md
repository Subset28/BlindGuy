# DualSight ◉

<div align="center">

```
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║              ◉  DualSight   E N G I N E            ║
  ║                                                           ║
  ║      Hearing Through Sight  |  On-Device First           ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
```

**Academies of Loudoun 2026 Hackathon · CLONE Theme**

[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20SwiftUI-0D1117?style=for-the-badge&labelColor=161B22)](https://github.com/Subset28/DualSight)
[![Swift](https://img.shields.io/badge/Swift-6.0-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![CoreML](https://img.shields.io/badge/CoreML-ANE--Optimized-2563EB?style=for-the-badge)](https://developer.apple.com/documentation/coreml)
[![Latency](https://img.shields.io/badge/Latency-<100ms-16A34A?style=for-the-badge)](https://github.com/Subset28/DualSight)

</div>

---

## The Vision: An Auditory Twin

**DualSight** is a high-performance accessibility engine that "clones" human vision into a spatial auditory stream. Designed specifically for the visually impaired, it transforms a standard iPhone into a sophisticated perception field that identifies, tracks, and speaks the physical environment in real-time.

For the **2026 Academies Hackathon**, we've pushed the boundaries of on-device AI to create a system that doesn't just see—it understands urgency, distance, and spatial context.

---

## Key Features

### ◉ The Auditory Twin (Hearing Engine)
- **Spatialized TTS:** Converts vision detections into concise, directional audio cues.
- **Priority Gating:** Intelligently suppresses background clutter (e.g., "chair") to focus on critical hazards (e.g., "approaching car").
- **Ducking Logic:** Automatically lowers background audio (music/podcasts) when a safety announcement is triggered.

### ◉ 100° Spatial Radar
- **Field-of-View Perspective:** A premium glassmorphic UI representing the 100° field ahead of the user.
- **Non-Linear Scaling:** Nearby objects are visually and aurally emphasized using square-root distance normalization.
- **Live Sonar Sweep:** An oscillating scanner provides continuous feedback that the vision engine is active.

### ◉ Physical UI (Tactile Design)
- **High-Fidelity Haptics:** Uses the Taptic Engine to communicate object density and proximity through touch.
- **Accessibility First:** Massive touch targets, VoiceOver-optimized semantic hints, and automatic vision startup on launch.

### ◉ Judge Debug Dashboard
- **Glassmorphic HUD:** Real-time telemetry including vision latency (ms), frame-by-frame object counts, and model health.
- **Lab Bridge:** Optional WebSocket support for remote telemetry streaming during testing.

---

## Engineering Excellence

### High-Performance Vision Loop
- **Model:** YOLOv8m trained on **Open Images V7** (601 classes).
- **Optimization:** Fully optimized for the **Apple Neural Engine (ANE)** with FP16 precision.
- **Zero-Allocation Loop:** Implementation of request caching and pixel buffer reuse to maintain a rock-solid **15Hz inference rate** with sub-100ms end-to-end latency.

### Tracking & Deduplication
- **Ghost Tracking:** Maintains object identity across frames to estimate velocity and prevent "flickering" audio announcements.
- **Custom NMS:** Strict Non-Maximum Suppression ensures that a single physical object (like a car) only results in a single, clear audio cue.

---

## Technical Stack

- **Core:** Swift 6.0, SwiftUI, Combine
- **AI/ML:** CoreML, Vision Framework, YOLOv8
- **Audio:** AVFoundation (AVAudioSession with Ducking & Mix-With-Others)
- **Haptics:** UIImpactFeedback / CoreHaptics
- **Infrastructure:** BlindGuyKit (Reusable Swift Package)

---

## Project Structure

- `App/` - Primary iOS application, UI components, and the Hearing Engine.
- `ios/BlindGuyKit/` - The core engine: Camera pipeline, YOLO detector, and Object Tracker.
- `docs/` - PRD, contract specifications, and design system tokens.
- `scripts/` - Model conversion and class-mapping automation.

---

## Getting Started

1. Clone the repository.
2. Open `BlindGuy/BlindGuy.xcodeproj` in **Xcode 15+**.
3. Ensure the `yolov8m-oiv7.mlpackage` is included in the App target.
4. Build and run on a physical iOS device (iPhone 12 or newer recommended for ANE performance).

---

<div align="center">
  Built with ❤️ for Academies Hacks 2026.
</div>
