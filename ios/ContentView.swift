import SwiftUI

struct ContentView: View {
    @AppStorage("shouldShowOnboarding") var shouldShowOnboarding: Bool = true
    @State private var isScanning = true
    @State private var showingSettings = false
    @State private var threatLevel = "LOW"
    @State private var objectCount = 3
    
    var body: some View {
        if shouldShowOnboarding {
            OnboardingView(shouldShowOnboarding: $shouldShowOnboarding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            mainDashboard
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
        }
    }
    
    var mainDashboard: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Decorative Glows
            VStack {
                Circle()
                    .fill(Color.green.opacity(0.05))
                    .frame(width: 600, height: 600)
                    .blur(radius: 100)
                    .offset(y: -200)
                Spacer()
            }
            
            VStack(spacing: 40) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BLINDGUY")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .tracking(2)
                        Text("SPATIAL RADAR v1.0")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    
                    // Connection Badge & Settings
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("AIRPODS PRO")
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
                        .accessibilityHint("Opens the app configuration and hardware setup.")
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                Spacer()
                
                // The Radar (Centerpiece)
                RadarView()
                
                Spacer()
                
                // Info Section
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        InfoCard(title: "THREAT", value: threatLevel, color: .green)
                        InfoCard(title: "CLONES", value: "\(objectCount)", color: .white)
                        InfoCard(title: "LATENCY", value: "84ms", color: .white)
                    }
                    .padding(.horizontal, 20)
                    
                    // Main Action Button (Lanyard Mode Toggle)
                    Button(action: { 
                        isScanning.toggle()
                        HapticManager.shared.triggerDiscovery() // Feedback on toggle
                    }) {
                        Text(isScanning ? "Stop Scanning" : "Start Scanning")
                            .font(.headline.bold())
                            .foregroundColor(isScanning ? .black : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(isScanning ? Color.green : Color(uiColor: .systemBackground))
                            .cornerRadius(16)
                            .shadow(color: (isScanning ? Color.green : Color.white).opacity(0.15), radius: 12, x: 0, y: 6)
                    }
                    .padding(.horizontal, 24)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(isScanning ? "Stops the real-time spatial radar." : "Starts the real-time spatial radar.")
                }
                .padding(.bottom, 24)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 10) }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    ContentView()
}
