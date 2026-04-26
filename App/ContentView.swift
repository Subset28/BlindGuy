import BlindGuyKit
import SwiftUI

struct ContentView: View {
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding: Bool = true
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var hearing: HearingEngine
    @State private var showingSettings = false
    @AppStorage(BlindGuyFeatureKey.payloadHUD) private var showPayloadHUD: Bool = true
    @AppStorage(BlindGuyFeatureKey.haptics) private var hapticsOn: Bool = true
    @State private var speechMutedBanner = false

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView(shouldShowOnboarding: $shouldShowOnboarding)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                mainDashboard
                    .onAppear {
                        // Auto-start scanning if model is ready, reducing friction for blind users
                        if app.modelAvailable && !app.isScanning {
                            app.setScanning(true)
                        }
                    }
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
                ZStack {
                    RadialGradient(
                        colors: [BlindGuyTheme.accent.opacity(0.12), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 450
                    )
                    RadialGradient(
                        colors: [BlindGuyTheme.info.opacity(0.08), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 600
                    )
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        safetyDisclaimer
                        if speechMutedBanner {
                            mutedBanner
                        }
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
            // Two-finger double-tap only on the main scroll area, not the whole window — a full-screen
            // `UIView` overlay on `NavigationStack` was above the toolbar and swallowed log/settings taps.
            .overlay(alignment: .topLeading) {
                TwoFingerDoubleTapCapture {
                    hearing.muteFor(seconds: 10)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        speechMutedBanner = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            speechMutedBanner = false
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("BlindGuy")
                            .font(.title2.weight(.bold))
                        Text("Realtime speech")
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

    private var safetyDisclaimer: some View {
        Text("Assistive only. Distances are estimated and this does not replace a cane, guide dog, or orientation training.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
            .accessibilityLabel("Safety note. Assistive only. Distances are estimated and this does not replace cane or guide dog.")
    }

    private var mutedBanner: some View {
        HStack {
            Image(systemName: "speaker.slash.fill")
            Text("Speech muted for 10 seconds")
            Spacer()
            Text("Tap to unmute")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.semibold))
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .onTapGesture {
            hearing.unmuteNow()
            withAnimation(.easeInOut(duration: 0.2)) {
                speechMutedBanner = false
            }
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 12) {
            StatusChip(
                systemImage: hearing.isUsingOnDevicePayload ? "iphone" : "dot.radiowaves.left.and.right",
                title: hearing.isUsingOnDevicePayload ? "iPhone" : "Audio",
                subtitle: hearing.isUsingOnDevicePayload ? "On-device" : "Active",
                color: hearing.isUsingOnDevicePayload ? BlindGuyTheme.accent : BlindGuyTheme.warmAlert
            )
            StatusChip(
                systemImage: "text.bubble",
                title: "Speech",
                subtitle: "Realtime",
                color: BlindGuyTheme.info
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
                    Text("Include yolov8m-oiv7.mlpackage (from scripts/export_coreml.py) in this app in Xcode, then build again. Optional lab setup is in Settings if your team needs it.")
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
        VStack(alignment: .leading, spacing: 20) {
            #if os(iOS)
            if app.modelAvailable, app.isScanning, let session = app.captureSessionForPreview {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Camera feed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label("LIVE", systemImage: "record.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BlindGuyTheme.warmAlert)
                    }
                    CameraFeedPreview(session: session)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        }
                }
            }
            #endif
            
            radarContainer
        }
    }

    private var radarContainer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.isScanning ? "Spatial field" : "Radar (Idle)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            GlassPanel(padding: 0, cornerRadius: BlindGuyTheme.cornerL) {
                RadarView(
                    objects: app.session?.lastPayload?.objects ?? [],
                    alertActive: hearing.alertActive
                )
            }
            .frame(height: 300)
            .accessibilityLabel("Spatial Field")
            .accessibilityHint("A real-time radar showing nearby objects. High priority items are spoken through the hearing engine.")
        }
    }

    private var statsStrip: some View {
        GlassPanel(padding: 0, cornerRadius: BlindGuyTheme.cornerL) {
            HStack(spacing: 0) {
                StatPill(label: "Alert", value: app.threatLabel, emphasis: .high)
                divider
                StatPill(label: "Objects", value: "\(app.cloneCount)", emphasis: .normal)
                divider
                StatPill(label: "Latency", value: app.latencyLine, emphasis: .muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
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
                HStack(spacing: 16) {
                    Image(systemName: app.isScanning ? "stop.circle.fill" : "camera.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                    Text(app.isScanning ? "STOP SCANNING" : "START SCANNING")
                        .font(.title2.weight(.black))
                        .tracking(1.5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32) // Massive tap target for accessibility
            }
            .buttonStyle(PrimaryDockButtonStyle(isOn: app.isScanning, enabled: app.modelAvailable))
            .disabled(!app.modelAvailable)
            .accessibilityLabel(app.isScanning ? "Stop scanning" : "Start scanning")
            .accessibilityHint("Double tap to toggle the vision engine. When on, the app will speak nearby objects automatically.")
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
        GlassPanel(padding: 12, cornerRadius: BlindGuyTheme.cornerM) {
            HStack(spacing: 10) {
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
    struct PreviewHost: View {
        @StateObject private var app = AppViewModel()
        var body: some View {
            ContentView()
                .environmentObject(app)
                .environmentObject(app.hearing)
        }
    }
    return PreviewHost()
}
