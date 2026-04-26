import SwiftUI
import BlindGuyKit

struct RadarView: View {
    /// Real-time hazard payload from the Vision Engine
    var objects: [TrackedDetection]
    /// Whether a critical threat is currently active
    var alertActive: Bool

    @State private var sweep: Double = 0
    @State private var pingScale: CGFloat = 0.5
    @State private var pingOpacity: Double = 0.8

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                // ── Background Rings ─────────────────────────────────────────
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .stroke(ringColor.opacity(0.08), lineWidth: 1)
                        .frame(width: size * CGFloat(Double(i) / 3.0), height: size * CGFloat(Double(i) / 3.0))
                }

                // ── Crosshair axes ───────────────────────────────────────────
                Path { p in
                    p.move(to: CGPoint(x: center.x, y: center.y - size/2))
                    p.addLine(to: CGPoint(x: center.x, y: center.y + size/2))
                    p.move(to: CGPoint(x: center.x - size/2, y: center.y))
                    p.addLine(to: CGPoint(x: center.x + size/2, y: center.y))
                }
                .stroke(ringColor.opacity(0.1), lineWidth: 1)

                // ── Sweep arm ───────────────────────────────────────────────
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.18)
                        .fill(
                            AngularGradient(
                                colors: [sweepColor.opacity(0.35), sweepColor.opacity(0)],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(65)
                            )
                        )
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(sweep))
                }
                .onAppear {
                    withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                        sweep = 360
                    }
                }

                // ── Outgoing ping ────────────────────
                Circle()
                    .stroke(sweepColor.opacity(objects.isEmpty ? 0 : pingOpacity), lineWidth: 1.5)
                    .frame(width: size * pingScale, height: size * pingScale)
                    .onAppear {
                        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                            pingScale = 1.0
                            pingOpacity = 0
                        }
                    }

                // ── Object blips ─────────────────────────────────────────────
                // Render true spatial blips based on actual Pan and Distance metrics
                ForEach(objects, id: \.objectId) { obj in
                    Circle()
                        .fill(sweepColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: sweepColor.opacity(0.8), radius: 6)
                        .position(position(for: obj, in: size, center: center))
                }

                // ── Center user dot ──────────────────────────────────────────
                Circle()
                    .fill(sweepColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: sweepColor.opacity(0.6), radius: 12)

                // ── Alert ring flash ─────────────────────────────────────────
                if alertActive {
                    Circle()
                        .stroke(BlindGuyTheme.critical.opacity(0.5), lineWidth: 2)
                        .frame(width: size * 0.92, height: size * 0.92)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever(autoreverses: true),
                            value: alertActive
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spatial radar")
    }

    // MARK: - Helpers

    private var sweepColor: Color {
        alertActive ? BlindGuyTheme.critical : BlindGuyTheme.accent
    }

    private var ringColor: Color { BlindGuyTheme.accent }

    /// Maps the real world 3D position to the 2D radar plane
    private func position(for obj: TrackedDetection, in size: CGFloat, center: CGPoint) -> CGPoint {
        // Pan goes from -1 (far left) to +1 (far right).
        // Let's map that to an angle arc of -38° to +38° relative to top-center (0°)
        let angleDegrees = obj.panValue * 38.0
        let angleRadians = angleDegrees * .pi / 180.0
        
        // Distance mapping: cap the radar visual at 7.0 meters.
        let maxDist = 7.0
        let normDist = min(max(obj.distanceM, 0.3), maxDist) / maxDist
        
        let maxRadius = (size / 2) * 0.95
        let radius = maxRadius * normDist
        
        // Trigonometry: 0 degrees is straight UP (y decreases)
        let x = center.x + CGFloat(sin(angleRadians)) * radius
        let y = center.y - CGFloat(cos(angleRadians)) * radius
        
        return CGPoint(x: x, y: y)
    }
}
