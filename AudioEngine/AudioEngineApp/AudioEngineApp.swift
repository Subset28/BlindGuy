import SwiftUI

/// **Deprecated entry.** The product app is **`ios/BlindGuyRuntime/BlindGuyAppEntry`**
/// + `AppViewModel` + `HearingEngine` (uses **`BlindGuyKit`** and optional **`/frame`** bridge).
/// This file is kept for reference; do not add `@main` here when building the full BlindGuy app.
struct AudioEnginePreviewShell: App {
    @StateObject private var engine = AudioEngineManager()

    var body: some Scene {
        WindowGroup {
            AudioEngine_OldContent()
                .environmentObject(engine)
                .onAppear { engine.start() }
                .onDisappear { engine.stop() }
        }
    }
}
