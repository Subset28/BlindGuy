import SwiftUI

struct OnboardingView: View {
    @Binding var shouldShowOnboarding: Bool
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to BlindGuy",
            description: "Your second pair of eyes. We clone the physical world into a 3D auditory twin directly in your ears.",
            icon: "eye.fill",
            color: .green
        ),
        OnboardingPage(
            title: "Spatial Radar",
            description: "Feel the distance and direction of silent threats like EVs and cyclists through intuitive spatial sound.",
            icon: "antenna.radiowaves.left.and.right",
            color: .blue
        ),
        OnboardingPage(
            title: "Hardware Ready",
            description: "For the best experience, wear your AirPods Pro. We use head-tracking to keep the soundscape stable as you move.",
            icon: "airpodspro",
            color: .purple
        ),
        OnboardingPage(
            title: "Always On-Device",
            description: "Zero cloud. Zero latency. Your privacy is absolute. Processing happens entirely on your Neural Engine.",
            icon: "cpu",
            color: .orange
        ),
        OnboardingPage(
            title: "Lanyard Setup",
            description: "Wear your iPhone on a lanyard or chest mount. Our UI is designed for zero-touch interaction so you can focus on the path ahead.",
            icon: "person.and.arrow.left.and.arrow.right",
            color: .red
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Background Glow
            Circle()
                .fill(pages[currentPage].color.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(y: -100)
                .animation(.easeInOut, value: currentPage)
            
            VStack {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingContent(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Custom Indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? pages[currentPage].color : Color.white.opacity(0.2))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 40)
                
                // Bottom Button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        withAnimation { shouldShowOnboarding = false }
                    }
                }) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(pages[currentPage].color)
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct OnboardingContent: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: page.icon)
                .font(.system(size: 100))
                .foregroundColor(page.color)
                .shadow(color: page.color.opacity(0.3), radius: 20)
                .padding(.top, 100)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(page.title). \(page.description)")
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(shouldShowOnboarding: .constant(true))
}
