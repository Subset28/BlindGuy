import SwiftUI

struct OnboardingView: View {
    @Binding var shouldShowOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "What BlindGuy detects",
            description: "People, vehicles, bikes, dogs, traffic lights, signs, benches, and selected everyday obstacles from the camera view.",
            icon: "viewfinder.circle",
            color: BlindGuyTheme.info
        ),
        OnboardingPage(
            title: "Distance is estimated",
            description: "Distance is approximate and may vary by lighting, motion, and camera angle. BlindGuy is assistive and does not replace a cane or guide dog.",
            icon: "ruler",
            color: BlindGuyTheme.warmAlert
        ),
        OnboardingPage(
            title: "How to read speech output",
            description: "High priority objects are spoken first. Distance phrases depend on confidence. Silence usually means no obstacles are currently detected.",
            icon: "text.bubble",
            color: BlindGuyTheme.accent
        ),
    ]

    var body: some View {
        ZStack {
            BlindGuyTheme.background.ignoresSafeArea()
            RadialGradient(
                colors: [pages[safe: currentPage]?.color.opacity(0.2) ?? BlindGuyTheme.accent.opacity(0.15), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: currentPage)

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        OnboardingContent(page: pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? pages[i].color : Color.white.opacity(0.2))
                            .frame(width: i == currentPage ? 28 : 6, height: 6)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentPage)

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { currentPage += 1 }
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) { shouldShowOnboarding = false }
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? "Get started" : "Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(currentPage == pages.count - 1 ? Color.black : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background {
                            RoundedRectangle(cornerRadius: BlindGuyTheme.cornerL, style: .continuous)
                                .fill(currentPage == pages.count - 1 ? AnyShapeStyle(BlindGuyTheme.accent) : AnyShapeStyle(Color.white.opacity(0.12)))
                        }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
    }
}

private struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

private struct OnboardingContent: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(page.color)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.bottom, 36)
            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(page.title). \(page.description)")
            Spacer()
            Spacer()
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? {
        (0..<count).contains(i) ? self[i] : nil
    }
}

#Preview {
    OnboardingView(shouldShowOnboarding: .constant(true))
}
