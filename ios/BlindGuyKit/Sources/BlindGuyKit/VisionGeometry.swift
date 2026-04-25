import CoreGraphics
import Foundation

enum VisionGeometry {
    /// Convert Vision's normalized box (origin lower-left) to top-left / PRD-style normalized centers and sizes.
    static func prdBoxFromVisionBoundingBox(
        _ box: CGRect
    ) -> (xCenter: Double, yCenter: Double, w: Double, h: Double) {
        let x = box.origin.x
        let w = box.size.width
        let yBottom = box.origin.y
        let h = box.size.height
        let yTop = 1.0 - yBottom - h
        let cx = x + w * 0.5
        let cy = yTop + h * 0.5
        return (Double(cx), Double(cy), Double(w), Double(h))
    }

    static func panValue(xCenterNorm: Double) -> Double {
        let v = (xCenterNorm - 0.5) * 2.0
        return min(1, max(-1, v))
    }

    static func monocularDistanceM(
        className: String,
        knownHeightsM: [String: Double],
        focalLengthPx: Double,
        bboxHeightPx: Double
    ) -> Double {
        let hRef = knownHeightsM[className] ?? 1.7
        let d = (hRef * focalLengthPx) / max(1, bboxHeightPx)
        return max(0.1, (d * 100).rounded() / 100)
    }
}
