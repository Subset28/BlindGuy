import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var scanDistance: Double = 15.0
    @State private var alertVolume: Double = 0.8
    @State private var useHeadTracking = true
    @State private var highThreatOnly = false
    @State private var voiceOverGuidance = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Max Scan Distance: \(Int(scanDistance))m")
                                .font(.headline)
                            Slider(value: $scanDistance, in: 5...30, step: 1)
                                .tint(.green)
                        }
                        .padding(.vertical, 4)
                        
                        Toggle("Head Tracking (AirPods Pro)", isOn: $useHeadTracking)
                            .tint(.green)
                            .font(.body)
                    } header: {
                        Text("Spatial Radar Configuration")
                    } footer: {
                        Text("Higher distance allows earlier detection but may increase background processing.")
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Alert Volume: \(Int(alertVolume * 100))%")
                                .font(.headline)
                            Slider(value: $alertVolume, in: 0...1)
                                .tint(.green)
                        }
                        .padding(.vertical, 4)
                        
                        Toggle("High Threat Alerts Only", isOn: $highThreatOnly)
                            .tint(.green)
                        
                        Toggle("VoiceOver Haptic Feedback", isOn: $voiceOverGuidance)
                            .tint(.green)
                    } header: {
                        Text("Audio & Alerts")
                    }
                    
                    Section {
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Text("System Permissions")
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Privacy")
                    } footer: {
                        Text("BlindGuy requires Camera and Motion permissions for object detection and head tracking.")
                    }
                    
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0 (Academies Hacks)")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Re-watch Onboarding") {
                            // Logic to reset AppStorage would go here
                        }
                    } header: {
                        Text("Information")
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .onAppear {
                    // Set list background transparency in SwiftUI is tricky, but we can use this for the theme
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
    }
}

#Preview {
    SettingsView()
}
