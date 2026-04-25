import BlindGuyKit
import SwiftUI

/// Main shell: iOS-first. Optional “lab computer” URL lives only in Settings; no ports on the home screen.
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
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.09),
                    Color.black,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft vignette
            RadialGradient(
                colors: [Color.green.opacity(0.08), Color.clear],
                center: .top,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    statusChips
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if !app.modelAvailable {
                        modelSetupCallout
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }

                    radarBlock
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)

                    statsRow
                        .padding(.horizontal, 20)

                    if showPayloadHUD, app.modelAvailable, let s = app.session {
                        PayloadHUD(session: s, hapticsEnabled: hapticsOn)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    scanButton
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BlindGuy")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Spatial audio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var statusChips: some View {
        HStack(spacing: 8) {
            statusPill(
                icon: hearing.isUsingOnDevicePayload ? "iphone" : "antenna.radiowaves.left.and.right",
                text: hearing.isUsingOnDevicePayload ? "This iPhone" : "Hearing",
                detail: hearing.isUsingOnDevicePayload
                    ? "Vision on-device"
                    : "Spatial sound active",
                tint: hearing.isUsingOnDevicePayload
                    ? Color.green.opacity(0.85)
                    : Color.orange.opacity(0.9)
            )

            statusPill(
                icon: (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble) ? "headphones" : "speaker.wave.2",
                text: (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble) ? "Headphones" : "Speaker",
                detail: (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble) ? "3D audio" : "Stereo",
                tint: (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble)
                    ? Color.cyan.opacity(0.9)
                    : Color.orange.opacity(0.75)
            )
        }
    }

    private func statusPill(icon: String, text: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var modelSetupCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Camera on this iPhone")
                    .font(.headline)
            } icon: {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(.green)
            }
            Text("Add the yolov8n Core ML model in Xcode, then build again, so the camera can see your surroundings. Everything else in this app already runs on your iPhone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("A separate computer in the same room is only for team testing. If your project uses that, you’ll set it in Settings — not for normal, everyday use.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.green.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
        }
    }

    private var radarBlock: some View {
        RadarView()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            InfoCard(title: "Alert", value: app.threatLabel, valueColor: .green)
            InfoCard(title: "Objects", value: "\(app.cloneCount)", valueColor: Color(white: 0.95))
            InfoCard(title: "Delay", value: app.latencyLine, valueColor: Color(white: 0.6))
        }
    }

    private var scanButton: some View {
        Button {
            app.setScanning(!app.isScanning)
        } label: {
            Text(app.isScanning ? "Stop" : "Start camera")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(ScanningButtonStyle(isScanning: app.isScanning, enabled: app.modelAvailable))
        .disabled(!app.modelAvailable)
        .accessibilityLabel(app.isScanning ? "Stop camera" : "Start camera")
        .accessibilityHint(
            app.modelAvailable
                ? (app.isScanning
                    ? "Stops the camera and vision."
                    : "Uses the on-device camera and vision when the model is included.")
                : "The vision model is not in this app build. Add the Core ML model in Xcode, or ask your developer."
        )
    }
}

// MARK: - Button style

private struct ScanningButtonStyle: ButtonStyle {
    var isScanning: Bool
    var enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isScanning ? .black : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isScanning
                            ? AnyShapeStyle(Color.green)
                            : AnyShapeStyle(Color(.secondarySystemBackground))
                    )
            }
            .opacity(enabled ? 1.0 : 0.45)
            .scaleEffect(configuration.isPressed && enabled ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Stat cards

struct InfoCard: View {
    var title: String
    var value: String
    var valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospaced()
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
        .environmentObject(HearingEngine())
}
