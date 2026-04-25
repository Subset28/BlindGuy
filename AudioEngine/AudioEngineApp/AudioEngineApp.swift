import SwiftUI

@main
struct AudioEngineApp: App {
    @StateObject private var engine = AudioEngineManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .onAppear {
                    engine.start()
                }
                .onDisappear {
                    engine.stop()
                }
        }
    }
}
