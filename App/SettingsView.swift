import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
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
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                List {
                    Section {
                        Toggle("3D audio bubble (HRTF on headphones)", isOn: $spatial3DBubble)
                            .tint(.green)
                    } header: {
                        Text("Spatial audio")
                    } footer: {
                        Text("When on and you use AirPods, wired, or similar stereo, tones use a binaural stage. When off, stereo pan is used only.")
                    }

                    Section {
                        Toggle("Hearing tones (clones)", isOn: $hearingTones)
                            .tint(.green)
                        Toggle("Distance TTS (high-priority objects)", isOn: $hearingTTS)
                            .tint(.green)
                    } header: {
                        Text("Hearing")
                    } footer: {
                        Text("Tones: looping audio per tracked object. TTS: spoken distance and class for high-priority items.")
                    }

                    Section {
                        Toggle("Haptics (scan, alerts)", isOn: $haptics)
                            .tint(.green)
                        Toggle("Payload HUD overlay", isOn: $payloadHUD)
                            .tint(.green)
                    } header: {
                        Text("Haptics & display")
                    } footer: {
                        Text("Payload HUD is the on-screen object count and vision latency panel. Haptics also drive high-priority pulse when the HUD is shown.")
                    }

                    Section {
                        Toggle("Lens smudge TTS", isOn: $lensTTS)
                            .tint(.green)
                    } header: {
                        Text("Camera / vision")
                    } footer: {
                        Text("When the lens looks dirty, a short TTS can remind you to clean the camera. Independent of object distance TTS.")
                    }

                    Section {
                        DisclosureGroup(isExpanded: $showOptionalComputer) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(
                                    "BlindGuy runs on this iPhone. A Mac or PC on the same Wi‑Fi is only for developer or lab setups — not everyday use. If your team gave you a web address to use, enter it here. Otherwise, leave this collapsed."
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                                TextField("http://10.0.0.1:8765", text: $bridgeURLString)
                                    .textContentType(.URL)
                                    .autocorrectionDisabled()
                                    .onSubmit { applyBridgeURL() }
                                Button("Save address") {
                                    applyBridgeURL()
                                }
                                .tint(.green)
                            }
                            .padding(.top, 4)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Optional: lab computer on Wi‑Fi")
                                    Text("Hidden unless you need it")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "laptopcomputer.and.iphone")
                            }
                        }
                    } header: {
                        Text("For developers")
                    } footer: {
                        Text("Normal use: vision and audio on this device. No second machine required.")
                    }

                    Section {
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Text("System permissions")
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Privacy")
                    } footer: {
                        Text("BlindGuy uses Camera and Motion for object detection and head tracking where enabled.")
                    }

                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0 (Academies Hacks)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Information")
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .onAppear {
                    UITableView.appearance().backgroundColor = .clear
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: spatial3DBubble) { _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
        .onChange(of: hearingTones) { _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
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
