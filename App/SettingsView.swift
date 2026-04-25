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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Python bridge (Mac / PC)")
                                .font(.headline)
                            Text("When no CoreML model in the app, or for lab demos, the hearing engine polls this base URL for GET /frame (same as GET /payload on the server).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("http://192.168.1.10:8765", text: $bridgeURLString)
                                .textContentType(.URL)
                                .autocorrectionDisabled()
                                .onSubmit { applyBridgeURL() }
                        }
                        .padding(.vertical, 4)
                        Button("Apply bridge URL") {
                            applyBridgeURL()
                        }
                        .tint(.green)
                    } header: {
                        Text("Development")
                    } footer: {
                        Text("Run: PYTHONPATH=src python -m visual_engine.main --host 0.0.0.0 --port 8765 (optionally --no-local-camera for phone-only).")
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
        .onChange(of: spatial3DBubble) { _, _ in
            app.hearing.applyFeatureTogglesFromUserDefaults()
        }
        .onChange(of: hearingTones) { _, _ in
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
