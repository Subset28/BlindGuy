import SwiftUI

/// Shared look: deep charcoal shell, single mint accent, glass surfaces.
enum BlindGuyTheme {
    static let accent = Color(hue: 0.40, saturation: 0.55, brightness: 0.92) // soft mint
    static let accentDim = Color(hue: 0.40, saturation: 0.35, brightness: 0.55)
    static let warmAlert = Color(hue: 0.12, saturation: 0.55, brightness: 0.95)
    static let info = Color(hue: 0.55, saturation: 0.45, brightness: 0.95) // cool blue-white

    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.035, blue: 0.055),
                Color(red: 0.01, green: 0.012, blue: 0.02),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var glassStroke: some ShapeStyle {
        Color.white.opacity(0.1)
    }

    static let cornerL: CGFloat = 22
    static let cornerM: CGFloat = 16
    static let cornerS: CGFloat = 12
}

struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: BlindGuyTheme.cornerM, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: BlindGuyTheme.cornerM, style: .continuous)
                    .strokeBorder(BlindGuyTheme.glassStroke, lineWidth: 1)
            }
    }
}
