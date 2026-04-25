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
                    Section(header: Text("Spatial Radar Configuration").foregroundColor(.green)) {
                        VStack(alignment: .leading) {
                            Text("Max Scan Distance: \(Int(scanDistance))m")
                            Slider(value: $scanDistance, in: 5...30, step: 1)
                                .accentColor(.green)
                        }
                        .padding(.vertical, 8)
                        
                        Toggle("Head Tracking (AirPods Pro)", isOn: $useHeadTracking)
                            .tint(.green)
                    }
                    
                    Section(header: Text("Audio & Alerts").foregroundColor(.green)) {
                        VStack(alignment: .leading) {
                            Text("Alert Volume: \(Int(alertVolume * 100))%")
                            Slider(value: $alertVolume, in: 0...1)
                                .accentColor(.green)
                        }
                        .padding(.vertical, 8)
                        
                        Toggle("High Threat Alerts Only", isOn: $highThreatOnly)
                            .tint(.green)
                        
                        Toggle("VoiceOver Haptic Feedback", isOn: $voiceOverGuidance)
                            .tint(.green)
                    }
                    
                    Section(header: Text("Information").foregroundColor(.green)) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0 (Academies Hacks)")
                                .foregroundColor(.gray)
                        }
                        
                        Button("Re-watch Onboarding") {
                            // Logic to reset AppStorage would go here
                        }
                        .foregroundColor(.blue)
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
