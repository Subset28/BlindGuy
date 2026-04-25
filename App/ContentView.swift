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
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
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
        NavigationStack {
            ZStack {
                BlindGuyTheme.background.ignoresSafeArea()
                RadialGradient(
                    colors: [BlindGuyTheme.accent.opacity(0.09), .clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 380
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        statusStrip
                        if !app.modelAvailable { modelCallout }
                        visualStage
                        statsStrip
                        if showPayloadHUD, app.modelAvailable, let s = app.session {
                            PayloadHUD(session: s, hapticsEnabled: hapticsOn)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("BlindGuy")
                            .font(.title2.weight(.bold))
                        Text("Spatial audio")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        if app.modelAvailable, let session = app.session {
                            NavigationLink {
                                DetectionDebugView(session: session)
                            } label: {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.body.weight(.semibold))
                                    .symbolRenderingMode(.hierarchical)
                                    .frame(width: 40, height: 40)
                                    .background {
                                        Circle()
                                            .fill(Color.white.opacity(0.06))
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Detection debug")
                        }
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.body.weight(.semibold))
                                .symbolRenderingMode(.hierarchical)
                                .frame(width: 40, height: 40)
                                .background {
                                    Circle()
                                        .fill(Color.white.opacity(0.06))
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                }
            }
        }
        .tint(BlindGuyTheme.accent)
        .safeAreaInset(edge: .bottom) { scanDock }
        .preferredColorScheme(.dark)
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            StatusChip(
                systemImage: hearing.isUsingOnDevicePayload ? "iphone" : "dot.radiowaves.left.and.right",
                title: hearing.isUsingOnDevicePayload ? "iPhone" : "Audio",
                subtitle: hearing.isUsingOnDevicePayload ? "On-device" : "Active",
                color: hearing.isUsingOnDevicePayload ? BlindGuyTheme.accent : BlindGuyTheme.warmAlert
            )
            StatusChip(
                systemImage: (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble) ? "headphones" : "speaker.wave.2",
                title: (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble) ? "Spatial" : "Stereo",
                subtitle: (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble) ? "3D" : "2D",
                color: (hearing.isSpatialHeadphoneRouteActive && spatial3DBubble) ? BlindGuyTheme.info : BlindGuyTheme.warmAlert.opacity(0.85)
            )
        }
    }

    private var modelCallout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(BlindGuyTheme.warmAlert)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add the vision model")
                        .font(.headline)
                    Text("Include yolov8n.mlpackage in this app in Xcode, then build again. Optional lab setup is in Settings if your team needs it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                .fill(BlindGuyTheme.warmAlert.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                .strokeBorder(BlindGuyTheme.warmAlert.opacity(0.3), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var visualStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            #if os(iOS)
            if app.modelAvailable, app.isScanning, let session = app.captureSessionForPreview {
                HStack {
                    Text("Camera")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("LIVE", systemImage: "record.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BlindGuyTheme.warmAlert)
                }
                CameraFeedPreview(session: session)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 220, idealHeight: 300)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                            .strokeBorder(LinearGradient(
                                colors: [BlindGuyTheme.accent.opacity(0.5), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1)
                    }
                    .shadow(color: BlindGuyTheme.accent.opacity(0.12), radius: 24, y: 12)
            } else {
                radarPlaceholder
            }
            #else
            radarPlaceholder
            #endif
        }
    }

    private var radarPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Field view")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                RadarView()
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var statsStrip: some View {
        HStack(spacing: 0) {
            StatPill(label: "Alert", value: app.threatLabel, emphasis: .high)
            divider
            StatPill(label: "Objects", value: "\(app.cloneCount)", emphasis: .normal)
            divider
            StatPill(label: "Latency", value: app.latencyLine, emphasis: .muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                .fill(Color.white.opacity(0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1)
            .frame(maxHeight: 44)
    }

    private var scanDock: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    app.setScanning(!app.isScanning)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: app.isScanning ? "stop.fill" : "camera.fill")
                    Text(app.isScanning ? "Stop camera" : "Start camera")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .buttonStyle(PrimaryDockButtonStyle(isOn: app.isScanning, enabled: app.modelAvailable))
            .disabled(!app.modelAvailable)
            .accessibilityLabel(app.isScanning ? "Stop camera" : "Start camera")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Subviews

private struct StatusChip: View {
    var systemImage: String
    var title: String
    var subtitle: String
    var color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: BlindGuyTheme.cornerS, style: .continuous)
                .fill(Color.white.opacity(0.06))
        }
    }
}

private struct StatPill: View {
    enum Emphasis { case high, normal, muted }
    var label: String
    var value: String
    var emphasis: Emphasis

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(foreground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var foreground: some ShapeStyle {
        switch emphasis {
        case .high: BlindGuyTheme.accent
        case .normal: Color.primary
        case .muted: Color.secondary
        }
    }
}

private struct PrimaryDockButtonStyle: ButtonStyle {
    var isOn: Bool
    var enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isOn ? Color.black : Color.primary.opacity(0.95))
            .background {
                RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                    .fill(
                        isOn
                            ? AnyShapeStyle(BlindGuyTheme.accent)
                            : AnyShapeStyle(Color.white.opacity(0.1))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: isOn ? 0 : 1)
            }
            .scaleEffect(configuration.isPressed && enabled ? 0.97 : 1)
            .opacity(enabled ? 1 : 0.4)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
        .environmentObject(HearingEngine())
}
