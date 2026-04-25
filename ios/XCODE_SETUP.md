# Building the BlindGuy iOS app (Xcode)

## 1. Open the committed project (recommended)

At the repo root:

- **BlindGuy/BlindGuy.xcodeproj** — iOS app target with **File System Synchronized** sources pointing at **`../App`** and a local **Swift Package** dependency on **`../ios/BlindGuyKit`**.

In Xcode, open that project, pick an **iOS Simulator** (e.g. iPhone) as the run destination, then **Build** (⌘B). No manual “add all Swift files” step is required: everything under `App/` is in the app target.

If you do **not** use this project, create your own and link **`BlindGuyKit`** (see below).

## 2. `BlindGuyKit` (already wired in the committed project)

The committed target already resolves **`ios/BlindGuyKit`**. If you add a new app target or project from scratch:

1. **File → Add Package Dependencies… → Add Local…**
2. Select `ios/BlindGuyKit` (the folder containing `Package.swift`).
3. Add **BlindGuyKit** to the app target.

## 3. App sources

With **`../App`** synchronized into the app target, all Swift files there are compiled, including e.g. **`BlindGuyAppEntry.swift`**, **`HearingEngine.swift`**, **`SettingsView.swift`**, **`BlindGuyFeatureFlags.swift`**, etc. Do **not** add `App` sources to the **`BlindGuyKit`** product.

**If you use a new Xcode app template:** remove its template `ContentView` / `App` struct if you replace them with the repo’s `App/` files.

## 4. CoreML model

1. From repo root: `python3 scripts/export_coreml.py` (see `ios/README.md`).
2. Drag **`yolov8n.mlpackage`** (output of `export_coreml.py`) into the **app** target and ensure **Copy items** + **BlindGuy** target membership.

Without the model, the app still runs **hearing** by polling the Python **`GET /frame`** endpoint (Settings → Development).

## 5. Info.plist (app target)

Merge at least:

- **Privacy – Camera** (`NSCameraUsageDescription`): e.g. *“BlindGuy uses the camera to detect objects for spatial audio.”*
- **App Transport Security**: **Allow arbitrary loads in local networks** (or use **`NSAppTransportSecurity` → `NSAllowsLocalNetworking` = true**) so `http://<mac-ip>:8765` works on device.

A reference plist fragment is in **`App/Info.plist.example`** (copy keys into the target’s Info or use a build setting).

## 6. One `@main` only

- Keep **`BlindGuyAppEntry`** as the only `@main`.
- Do not compile the old **`AudioEngine/AudioEngineApp/AudioEngineApp.swift`** in this target (or leave it out of the target); it is reference-only.

## 7. Run

- **On-device + CoreML:** start scanning; hearing uses `BlindGuySession` + `CameraPipeline`.
- **Lab + Python only:** `PYTHONPATH=src python -m visual_engine.main --host 0.0.0.0 --port 8765` on the Mac; on the phone set **Settings → Development → bridge URL** to `http://<mac-lan-ip>:8765`.

Server exposes **`/frame`**, **`/payload`** (alias), **`/health`**, **`/infer`**, **`/judge`**.
## 8. Visual Identity (App Icon & Splash)

To ensure the app feels like a premium product for the judges:

### App Icon
1. Open **Assets.xcassets** -> **AppIcon**.
2. Drag the **blindguy_app_icon** into the 1024px universal slot.
3. In the Attributes Inspector, set **Devices** to "Single Size" for quick setup.

### Launch Screen
1. Drag **blindguy_splash_logo** into **Assets.xcassets** and name it `LaunchLogo`.
2. In the app target **Info** tab, add a **Launch Screen** dictionary.
3. Inside it, add **Image Name** = `LaunchLogo` and **Background Color** = `Black`.
