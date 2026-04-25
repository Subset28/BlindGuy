import SwiftUI

struct RadarView: View {
    @State private var pulse: CGFloat = 0.4
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<5) { i in
                Circle()
                    .stroke(BlindGuyTheme.accent.opacity(0.06 - Double(i) * 0.01), lineWidth: 0.5)
                    .scaleEffect(0.28 + CGFloat(i) * 0.18)
            }

            Circle()
                .stroke(BlindGuyTheme.accent.opacity(0.2), lineWidth: 1.2)
                .scaleEffect(pulse)
                .opacity(1.1 - (pulse - 0.4) * 1.2)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                        pulse = 1.05
                    }
                }

            Circle()
                .trim(from: 0, to: 0.22)
                .stroke(
                    AngularGradient(
                        colors: [BlindGuyTheme.accent.opacity(0.45), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [BlindGuyTheme.accent, BlindGuyTheme.accent.opacity(0.25)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 14, height: 14)
                .shadow(color: BlindGuyTheme.accent.opacity(0.4), radius: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Field radar")
        .accessibilityValue("Animated when idle. Live camera shows when you start the camera.")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RadarView()
    }
    .frame(height: 280)
}
