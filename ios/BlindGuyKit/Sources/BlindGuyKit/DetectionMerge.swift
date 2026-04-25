import Foundation

/// COCO (YOLOv8) + open-vocabulary (YOLOE) dedup: on overlap, the **COCO** box wins.
enum DetectionMerge: Sendable {
    /// Merges detections. `coco` = primary, fixed 80-class model; `open` = YOLOE with baked text prompts.
    static func mergeCocoWins(
        coco: [RawDetection],
        open: [RawDetection],
        iouSuppressionThreshold: Double
    ) -> [RawDetection] {
        guard iouSuppressionThreshold > 0, !open.isEmpty else { return coco + open }
        var out = coco
        for o in open {
            let suppressed = coco.contains { iou($0, o) >= iouSuppressionThreshold }
            if !suppressed { out.append(o) }
        }
        return out
    }

    static func iou(_ a: RawDetection, _ b: RawDetection) -> Double {
        iou(
            xCenter1: a.xCenterNorm, yCenter1: a.yCenterNorm, w1: a.widthNorm, h1: a.heightNorm,
            xCenter2: b.xCenterNorm, yCenter2: b.yCenterNorm, w2: b.widthNorm, h2: b.heightNorm
        )
    }

    static func iou(
        xCenter1: Double, yCenter1: Double, w1: Double, h1: Double,
        xCenter2: Double, yCenter2: Double, w2: Double, h2: Double
    ) -> Double {
        let a = rectFromPRDCenter(xCenter1, yCenter1, w1, h1)
        let b = rectFromPRDCenter(xCenter2, yCenter2, w2, h2)
        let ix0 = max(a.0, b.0)
        let iy0 = max(a.1, b.1)
        let ix1 = min(a.2, b.2)
        let iy1 = min(a.3, b.3)
        let iw = max(0, ix1 - ix0)
        let ih = max(0, iy1 - iy0)
        let inter = iw * ih
        let aArea = (a.2 - a.0) * (a.3 - a.1)
        let bArea = (b.2 - b.0) * (b.3 - b.1)
        let union = aArea + bArea - inter
        guard union > 1e-9 else { return 0 }
        return inter / union
    }

    /// PRD: center normalized, y top-down. Returns minX, minY, maxX, maxY in normalized coords.
    private static func rectFromPRDCenter(_ cx: Double, _ cy: Double, _ w: Double, _ h: Double) -> (Double, Double, Double, Double) {
        let x0 = cx - 0.5 * w
        let y0 = cy - 0.5 * h
        let x1 = cx + 0.5 * w
        let y1 = cy + 0.5 * h
        return (x0, y0, x1, y1)
    }
}
