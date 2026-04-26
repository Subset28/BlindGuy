import SwiftUI
import BlindGuyKit

struct RadarView: View {
    /// Real-time hazard payload from the Vision Engine
    var objects: [DetectedObjectDTO]
    /// Whether a critical threat is currently active
    var alertActive: Bool

    @State private var sweep: Double = 0
    @State private var pingScale: CGFloat = 0.5
    @State private var pingOpacity: Double = 0.8

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 + (size * 0.15))
            let maxRadius = size * 0.75
            
            ZStack {
                // ── FOV Cone Background ──────────────────────────────────────
                ConeShape(angle: 100)
                    .fill(
                        RadialGradient(
                            colors: [sweepColor.opacity(0.08), .clear],
                            center: .bottom,
                            startRadius: 0,
                            endRadius: maxRadius
                        )
                    )
                    .frame(width: maxRadius * 2, height: maxRadius)
                    .position(x: center.x, y: center.y - (maxRadius/2))
                
                // ── FOV Grid Lines ───────────────────────────────────────────
                ForEach([0.33, 0.66, 1.0], id: \.self) { fraction in
                    ConeShape(angle: 100)
                        .stroke(ringColor.opacity(0.12), lineWidth: 1)
                        .frame(width: maxRadius * 2 * fraction, height: maxRadius * fraction)
                        .position(x: center.x, y: center.y - (maxRadius * fraction / 2))
                }

                // ── Center Axis ──────────────────────────────────────────────
                Path { p in
                    p.move(to: center)
                    p.addLine(to: CGPoint(x: center.x, y: center.y - maxRadius))
                }
                .stroke(ringColor.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // ── Sweep arm (Scanner beam) ─────────────────────────────────
                ZStack {
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: CGPoint(
                            x: center.x + CGFloat(sin(sweepRadians)) * maxRadius,
                            y: center.y - CGFloat(cos(sweepRadians)) * maxRadius
                        ))
                    }
                    .stroke(
                        LinearGradient(
                            colors: [sweepColor.opacity(0.6), .clear],
                            startPoint: .init(x: 0.5, y: 1.0),
                            endPoint: .init(x: 0.5, y: 0.0)
                        ),
                        lineWidth: 3
                    )
                }
                .onAppear {
                    // Oscillating sweep instead of 360 circle
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        sweep = 50 // Sweeps from -50 to +50 degrees
                    }
                }

                // ── Object blips ─────────────────────────────────────────────
                ForEach(objects, id: \.objectId) { obj in
                    let pos = position(for: obj, in: maxRadius, center: center)
                    ZStack {
                        Circle()
                            .fill(sweepColor)
                            .frame(width: 10, height: 10)
                            .shadow(color: sweepColor.opacity(0.8), radius: 6)
                            .shadow(color: sweepColor.opacity(0.4), radius: 12)
                        
                        // Distance label for high priority
                        if obj.priority.uppercased() == "HIGH" {
                            Text(String(format: "%.1fm", obj.distanceM))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(sweepColor)
                                .offset(y: 14)
                        }
                    }
                    .position(pos)
                }

                // ── User position (Origin) ───────────────────────────────────
                Circle()
                    .fill(sweepColor)
                    .frame(width: 14, height: 14)
                    .shadow(color: sweepColor.opacity(0.6), radius: 12)
                    .position(center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spatial field of view")
    }

    // MARK: - Helpers

    private var sweepRadians: Double {
        sweep * .pi / 180.0
    }

    private var sweepColor: Color {
        alertActive ? BlindGuyTheme.warmAlert : BlindGuyTheme.accent
    }

    private var ringColor: Color { BlindGuyTheme.accent }

    /// Maps the real world 3D position to the 2D radar plane
    private func position(for obj: DetectedObjectDTO, in maxRadius: CGFloat, center: CGPoint) -> CGPoint {
        // Map pan to a wider arc (-50° to +50°)
        let angleDegrees = obj.panValue * 50.0
        let angleRadians = angleDegrees * .pi / 180.0
        
        // Non-linear distance mapping: emphasize closer objects
        // (y = sqrt(x) makes the center area larger for closer objects)
        let maxDist = 7.0
        let rawNorm = min(max(obj.distanceM, 0.3), maxDist) / maxDist
        let normDist = sqrt(rawNorm) 
        
        let radius = maxRadius * CGFloat(normDist)
        
        let x = center.x + CGFloat(sin(angleRadians)) * radius
        let y = center.y - CGFloat(cos(angleRadians)) * radius
        
        return CGPoint(x: x, y: y)
    }
}

struct ConeShape: Shape {
    var angle: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = rect.height
        let startAngle = Angle(degrees: 270 - (angle/2))
        let endAngle = Angle(degrees: 270 + (angle/2))
        
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.closeSubpath()
        return p
    }
}
