import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppViewModel

    @AppStorage(BlindGuyFeatureKey.spatial3DBubble) private var spatial3DBubble: Bool = true
    @AppStorage(BlindGuyFeatureKey.hearingTones) private var hearingTones: Bool = true
    @AppStorage(BlindGuyFeatureKey.hearingTTS) private var hearingTTS: Bool = true
    @AppStorage(BlindGuyFeatureKey.haptics) private var haptics: Bool = true
    @AppStorage(BlindGuyFeatureKey.payloadHUD) private var payloadHUD: Bool = true
    @AppStorage(BlindGuyFeatureKey.lensTTS) private var lensTTS: Bool = true
    @AppStorage("blindguy.visionBridgeBaseURLString") private var bridgeURLString: String = "http://127.0.0.1:8765"
    @State private var showOptionalComputer: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                BlindGuyTheme.background.ignoresSafeArea()
                List {
                    Section {
                        Toggle(isOn: $spatial3DBubble) {
                            Label("3D audio on headphones", systemImage: "headphones")
                        }
                    } header: {
                        sectionHeader("Spatial", icon: "wave.3d.right")
                    } footer: {
                        Text("Binaural mix on earphones. When off, only left–right pan.")
                    }

                    Section {
                        Toggle(isOn: $hearingTones) { Label("Say each object’s name", systemImage: "text.bubble.fill") }
                        Toggle(isOn: $hearingTTS) { Label("Add distance in speech", systemImage: "ruler") }
                    } header: {
                        sectionHeader("Hearing", icon: "ear")
                    } footer: {
                        Text("When the first toggle is on, the app speaks what it sees (e.g. person, car), throttled. The second adds how many meters. When the first is off, only high-priority tracks get a spoken line if distance is on.")
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
                        Toggle(isOn: $lensTTS) { Label("Lens smudge voice hint", systemImage: "exclamationmark.triangle") }
                    } header: {
                        sectionHeader("Camera", icon: "camera")
                    } footer: {
                        Text("Gentle reminder if the glass may be dirty.")
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
        .onChange(of: spatial3DBubble) { _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
        .onChange(of: hearingTones) { _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
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
