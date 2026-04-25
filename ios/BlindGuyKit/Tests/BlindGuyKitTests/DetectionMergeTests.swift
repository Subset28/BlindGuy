import XCTest
@testable import BlindGuyKit

final class DetectionMergeTests: XCTestCase {
    func testIouIdentical() {
        let a = RawDetection(
            className: "x",
            confidence: 1,
            xCenterNorm: 0.5, yCenterNorm: 0.5,
            widthNorm: 0.2, heightNorm: 0.2,
            distanceM: 1, panValue: 0
        )
        let iou = DetectionMerge.iou(a, a)
        XCTAssertEqual(iou, 1, accuracy: 0.0001)
    }

    func testMergeDropsOpenWhenCocoOverlaps() {
        let coco = [RawDetection(
            className: "dining table",
            confidence: 0.8,
            xCenterNorm: 0.5, yCenterNorm: 0.5,
            widthNorm: 0.4, heightNorm: 0.3,
            distanceM: 2, panValue: 0
        )]
        let open = [RawDetection(
            className: "obstacle",
            confidence: 0.7,
            xCenterNorm: 0.51, yCenterNorm: 0.5,
            widthNorm: 0.4, heightNorm: 0.3,
            distanceM: 2, panValue: 0
        )]
        let m = DetectionMerge.mergeCocoWins(coco: coco, open: open, iouSuppressionThreshold: 0.4)
        XCTAssertEqual(m.count, 1)
        XCTAssertEqual(m[0].className, "dining table")
    }
}
