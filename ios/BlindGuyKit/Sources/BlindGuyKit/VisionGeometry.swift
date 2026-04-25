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

    /// Fraction of PRD bbox (origin top-left, y down) that lies in the unit square. Used to drop mostly off-screen detections.
    static func prdBboxVisibleAreaFraction(
        xCenter: Double,
        yCenter: Double,
        w: Double,
        h: Double
    ) -> Double {
        let x0 = xCenter - w * 0.5
        let x1 = xCenter + w * 0.5
        let y0 = yCenter - h * 0.5
        let y1 = yCenter + h * 0.5
        let ix0 = max(0, min(1, x0))
        let ix1 = max(0, min(1, x1))
        let iy0 = max(0, min(1, y0))
        let iy1 = max(0, min(1, y1))
        let iw = max(0, ix1 - ix0)
        let ih = max(0, iy1 - iy0)
        let aIn = iw * ih
        let aBox = max(w * h, 1e-9)
        return aIn / aBox
    }

    static func monocularDistanceM(
        className: String,
        knownHeightsM: [String: Double],
        focalLengthPx: Double,
        bboxHeightPx: Double
    ) -> Double {
        let safeHeight = min(max(knownHeightsM[className] ?? 1.7, 0.05), 6.0)
        let safeFocal = min(max(focalLengthPx, 100.0), 10_000.0)
        let safeBoxHeight = min(max(bboxHeightPx, 1.0), 20_000.0)
        let d = (safeHeight * safeFocal) / safeBoxHeight
        let out = min(max(d, 0.1), 60.0)
        #if DEBUG
        if !d.isFinite || d < 0.05 || d > 1000 {
            print(
                "VisionGeometry distance diagnostic:",
                "class=\(className)",
                "hRef=\(safeHeight)",
                "focal=\(safeFocal)",
                "bboxH=\(safeBoxHeight)",
                "raw=\(d)",
                "clamped=\(out)"
            )
        }
        #endif
        return (out * 100).rounded() / 100
    }
}
