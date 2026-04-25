import BlindGuyKit
import SwiftUI

struct ContentView: View {
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding: Bool = true
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var hearing: HearingEngine
    @State private var showingSettings = false
    @AppStorage(BlindGuyFeatureKey.spatial3DBubble) private var spatial3DBubble: Bool = true
    @AppStorage(BlindGuyFeatureKey.payloadHUD) private var showPayloadHUD: Bool = true
    @AppStorage(BlindGuyFeatureKey.haptics) private var hapticsOn: Bool = true

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView(shouldShowOnboarding: $shouldShowOnboarding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                mainDashboard
                    .sheet(isPresented: $showingSettings) {
                        SettingsView()
                            .environmentObject(app)
                    }
            }
        }
        .onDisappear {
            app.setScanning(false)
        }
    }

    private var mainDashboard: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack {
                Circle()
                    .fill(Color.green.opacity(0.05))
                    .frame(width: 600, height: 600)
                    .blur(radius: 100)
                    .offset(y: -200)
                Spacer()
            }

            VStack(spacing: 40) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BLINDGUY")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .tracking(2)
                        Text("SPATIAL RADAR")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    Spacer()

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(hearing.isUsingOnDevicePayload ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(hearing.isUsingOnDevicePayload ? "ON-DEVICE" : "BRIDGE")
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )

                        HStack(spacing: 6) {
                            Image(systemName: hearing.isSpatialHeadphoneRouteActive ? "headphones" : "speaker.wave.2")
                                .font(.system(size: 10, weight: .bold))
                            Text(
                                (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble)
                                ? "3D BUBBLE"
                                : "SPEAKER 2D"
                            )
                            .font(.system(size: 10, weight: .heavy))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            ((hearing.isSpatialHeadphoneRouteActive && spatial3DBubble) ? Color.cyan : Color.orange)
                                .opacity(0.12)
                        )
                        .cornerRadius(20)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble)
                            ? "Virtual spatial audio bubble active with headphones"
                            : (spatial3DBubble
                               ? "Use stereo headphones or AirPods for a three D audio bubble; tones are wider on the built in speaker"
                               : "Three D audio bubble is off in Settings; using stereo pan only"
                            )
                        )

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)

                if !app.modelAvailable {
                    Text("For on-device camera vision: add yolov8n.mlpackage to the BlindGuy app target in Xcode. For use without that file: open Settings (gear) → Development, set the Python bridge URL to the machine running visual_engine, tap Apply — hearing can use the bridge; Start scanning still needs the bundled model.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                RadarView()

                Spacer()

                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        InfoCard(title: "THREAT", value: app.threatLabel, color: .green)
                        InfoCard(title: "CLONES", value: "\(app.cloneCount)", color: .white)
                        InfoCard(title: "LATENCY", value: app.latencyLine, color: .white)
                    }
                    .padding(.horizontal, 20)

                    if showPayloadHUD, app.modelAvailable, let s = app.session {
                        PayloadHUD(session: s, hapticsEnabled: hapticsOn)
                            .padding(.horizontal, 20)
                    }

                    Button(action: {
                        app.setScanning(!app.isScanning)
                    }) {
                        Text(app.isScanning ? "Stop scanning" : "Start scanning")
                            .font(.headline.bold())
                            .foregroundColor(app.isScanning ? .black : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(app.isScanning ? Color.green : Color(uiColor: .systemBackground))
                            .cornerRadius(16)
                            .shadow(
                                color: (app.isScanning ? Color.green : Color.white).opacity(0.15),
                                radius: 12, x: 0, y: 6
                            )
                    }
                    .padding(.horizontal, 24)
                    .opacity(app.modelAvailable ? 1.0 : 0.5)
                    .accessibilityHint(
                        app.modelAvailable
                        ? (app.isScanning ? "Stops the camera and vision." : "Starts on-device camera and vision.")
                        : "On-device model missing; use Python bridge in Settings. Camera starts only with a model."
                    )
                }
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct InfoCard: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold().monospaced())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
        .environmentObject(HearingEngine())
}
