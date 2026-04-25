# Building the BlindGuy iOS app (Xcode)

There is **no committed `.xcodeproj`** (team machine and signing vary). Use **one** iOS app target and link the local **`BlindGuyKit`** package.

## 1. New project

1. Xcode → **File → New → App** → Product Name: **BlindGuy**, Interface: **SwiftUI**, Language: **Swift**, minimum **iOS 16.0**.
2. Save the project **next to** this repo or inside it (e.g. `BlindGuy/BlindGuy.xcodeproj` at repo root or under `ios/`).

## 2. Add the `BlindGuyKit` package

1. **File → Add Package Dependencies… → Add Local…**
2. Select `ios/BlindGuyKit` (the folder containing `Package.swift`).
3. Add **BlindGuyKit** to the **BlindGuy** app target.

## 3. Add app source files

Add these to the **BlindGuy** app target (**Target → Build Phases → Compile Sources**), *not* to the package:

| Path (from repo root) | Role |
|----------------------|------|
| `BlindGuy/BlindGuy/BlindGuyAppEntry.swift` | `@main` entry |
| `BlindGuy/BlindGuy/AppViewModel.swift` | Wires vision + camera + hearing |
| `BlindGuy/BlindGuy/HearingEngine.swift` | Spatial audio engine |
| `BlindGuy/BlindGuy/ContentView.swift` | Main UI Dashboard |
| `BlindGuy/BlindGuy/OnboardingView.swift` | Onboarding Flow |
| `BlindGuy/BlindGuy/RadarView.swift` | Spatial Radar Component |
| `BlindGuy/BlindGuy/SettingsView.swift` | App Settings |
| `BlindGuy/BlindGuy/HapticManager.swift` | Haptic Feedback Engine |

**Delete** the Xcode template `ContentView.swift` if it conflicts with `ios/ContentView.swift`.

## 4. CoreML model

1. From repo root: `python3 scripts/export_coreml.py` (see `ios/README.md`).
2. Drag **`yolov8n.mlpackage`** into the **app** target and ensure **Copy items** + **BlindGuy** target membership.

Without the model, the app still runs **hearing** by polling the Python **`GET /frame`** endpoint (Settings → Development).

## 5. Info.plist (app target)

Merge at least:

- **Privacy – Camera** (`NSCameraUsageDescription`): e.g. *“BlindGuy uses the camera to detect objects for spatial audio.”*
- **App Transport Security**: **Allow arbitrary loads in local networks** (or use **`NSAppTransportSecurity` → `NSAllowsLocalNetworking` = true**) so `http://<mac-ip>:8765` works on device.

A reference plist fragment is in **`ios/BlindGuyRuntime/Info.plist.example`** (copy keys into the target’s Info or use a build setting).

## 6. One `@main` only

- Keep **`BlindGuyAppEntry`** as the only `@main`.
- Do not compile the old **`AudioEngine/AudioEngineApp/AudioEngineApp.swift`** in this target (or leave it out of the target); it is reference-only.

## 7. Run

- **On-device + CoreML:** start scanning; hearing uses `BlindGuySession` + `CameraPipeline`.
- **Lab + Python only:** `PYTHONPATH=src python -m visual_engine.main --host 0.0.0.0 --port 8765` on the Mac; on the phone set **Settings → Development → bridge URL** to `http://<mac-lan-ip>:8765`.

Server exposes **`/frame`**, **`/payload`** (alias), **`/health`**, **`/infer`**, **`/judge`**.
