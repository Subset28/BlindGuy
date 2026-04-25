import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: AudioEngineManager

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Circle()
                    .fill(engine.alertActive ? Color.red : Color.green)
                    .frame(width: 30, height: 30)
                Text(engine.alertActive ? "ALERT" : "ACTIVE")
                    .font(.headline)
            }

            Text("Objects: \(engine.objectCount)")
                .font(.title2)

            Text("Bridge: \(engine.lastBridgeLatencyMs ?? 0) ms")
                .font(.subheadline)

            Spacer()
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AudioEngineManager())
    }
}
