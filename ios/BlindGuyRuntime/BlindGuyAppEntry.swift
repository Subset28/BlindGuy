import SwiftUI

@main
struct BlindGuyAppEntry: App {
    @StateObject private var app = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
                .environmentObject(app.hearing)
        }
    }
}
