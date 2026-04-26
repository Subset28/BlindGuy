import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppViewModel

    @AppStorage(BlindGuyFeatureKey.hearingTones) private var hearingTones: Bool = true
    @AppStorage(BlindGuyFeatureKey.hearingTTS) private var hearingTTS: Bool = true
    @AppStorage(BlindGuyFeatureKey.ttsCriticalOnly) private var ttsCriticalOnly: Bool = false
    @AppStorage(BlindGuyFeatureKey.distanceUnits) private var distanceUnits: String = "metric"
    @AppStorage(BlindGuyFeatureKey.ttsVoiceStyle) private var ttsVoiceStyle: String = "calm"
    @AppStorage(BlindGuyFeatureKey.ttsVerbosity) private var ttsVerbosity: String = "low"
    @AppStorage(BlindGuyFeatureKey.ttsTelemetryEnabled) private var ttsTelemetryEnabled: Bool = false
    @AppStorage(BlindGuyFeatureKey.suppressedClassesCSV) private var suppressedClassesCSV: String = ""
    @AppStorage(BlindGuyFeatureKey.haptics) private var haptics: Bool = true
    @AppStorage(BlindGuyFeatureKey.payloadHUD) private var payloadHUD: Bool = true
    @AppStorage("blindguy.visionBridgeBaseURLString") private var bridgeURLString: String = "http://127.0.0.1:8765"
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding: Bool = true
    @State private var showOptionalComputer: Bool = false
    @State private var telemetryShareURL: URL?
    @State private var showTelemetryShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                BlindGuyTheme.background.ignoresSafeArea()
                List {
                    Section {
                        Toggle(isOn: $hearingTones) { Label("Say each object’s name", systemImage: "text.bubble.fill") }
                        Toggle(isOn: $hearingTTS) { Label("Add distance in speech", systemImage: "ruler") }
                        Toggle(isOn: $ttsCriticalOnly) {
                            Label("Critical-only speech mode", systemImage: "exclamationmark.triangle")
                        }
                        Picker("Distance units", selection: $distanceUnits) {
                            Text("Metric").tag("metric")
                            Text("Imperial").tag("imperial")
                        }
                        Picker("Voice", selection: $ttsVoiceStyle) {
                            Text("Calm").tag("calm")
                            Text("Clear").tag("clear")
                            Text("Compact").tag("compact")
                        }
                        Picker("Speech amount", selection: $ttsVerbosity) {
                            Text("Low noise").tag("low")
                            Text("Normal").tag("normal")
                        }
                    } header: {
                        sectionHeader("Hearing", icon: "ear")
                    } footer: {
                        Text("When the first toggle is on, the app speaks what it sees (e.g. person, car), throttled. The second adds distance. When the first is off, only high-priority tracks get a spoken line if distance is on.")
                    }

                    Section {
                        Toggle(isOn: $haptics) { Label("Haptics", systemImage: "iphone.radiowaves.left.and.right") }
                        Toggle(isOn: $payloadHUD) { Label("Show stats overlay", systemImage: "chart.bar") }
                    } header: {
                        sectionHeader("Feedback", icon: "hand.tap")
                    } footer: {
                        Text("Haptics and optional on-screen count & timing.")
                    }

                    Section {
                        DisclosureGroup(isExpanded: $showOptionalComputer) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("For developer or lab use only. Enter an address only if your team set one up.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Address", text: $bridgeURLString)
                                    .textContentType(.URL)
                                    .autocorrectionDisabled()
                                    .padding(10)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                    .onSubmit { applyBridgeURL() }
                                Button("Save", action: applyBridgeURL)
                                    .fontWeight(.semibold)
                                Divider()
                                Text("Suppressed classes (comma-separated)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("optional class names to silence, comma-separated", text: $suppressedClassesCSV)
                                    .autocorrectionDisabled()
                                    .padding(10)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                Toggle(isOn: $ttsTelemetryEnabled) {
                                    Label("Enable local TTS telemetry", systemImage: "waveform.path.ecg")
                                }
                                Button("Export TTS telemetry JSON") {
                                    do {
                                        telemetryShareURL = try TTSTelemetryStore.shared.exportJSONFile()
                                        showTelemetryShareSheet = telemetryShareURL != nil
                                    } catch {
                                        telemetryShareURL = nil
                                    }
                                }
                                .disabled(!ttsTelemetryEnabled)
                                .fontWeight(.semibold)
                            }
                            .padding(.top, 6)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Lab on Wi‑Fi (optional)")
                                    Text("Developers only")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            } icon: {
                                Image(systemName: "cable.connector")
                            }
                        }
                    } header: {
                        sectionHeader("Advanced", icon: "hammer")
                    } footer: {
                        Text("BlindGuy runs on this iPhone. No second device is required in normal use.")
                    }

                    Section {
                        if let session = app.session {
                            NavigationLink {
                                DetectionDebugView(session: session)
                            } label: {
                                Label("Raw detections (debug)", systemImage: "list.bullet.rectangle")
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Raw detections (debug)", systemImage: "list.bullet.rectangle")
                                Text("Not available until the on-device YOLO model is bundled in Xcode.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        sectionHeader("Debug", icon: "ladybug")
                    } footer: {
                        Text("Live text of every object in the last vision frame. Requires the on-device YOLO model in the app.")
                            .font(.caption)
                    }

                    Section {
                        Button {
                            if let u = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(u)
                            }
                        } label: {
                            HStack {
                                Label("iOS settings", systemImage: "gearshape")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } header: {
                        sectionHeader("System", icon: "app.badge")
                    }

                    Section {
                        Button {
                            shouldShowOnboarding = true
                            dismiss()
                        } label: {
                            Label("Show onboarding again", systemImage: "sparkles")
                        }
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(.tertiary)
                        }
                    } header: {
                        sectionHeader("About", icon: "info.circle")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: { dismiss() })
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(BlindGuyTheme.accent)
        .preferredColorScheme(.dark)
        .onChange(of: hearingTones) { _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
        .onChange(of: ttsCriticalOnly) { _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
        .onChange(of: distanceUnits) { _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
        .onChange(of: ttsVoiceStyle) { _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
        .onChange(of: ttsVerbosity) { _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
        .onChange(of: ttsTelemetryEnabled) { on in
            TTSTelemetryStore.shared.setEnabled(on)
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
        .sheet(isPresented: $showTelemetryShareSheet) {
            if let url = telemetryShareURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func applyBridgeURL() {
        var s = bridgeURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = "http://127.0.0.1:8765" }
        if URL(string: s) == nil { return }
        if let u = URL(string: s) {
            app.hearing.reconfigure(bridgeBase: u)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppViewModel())
}
