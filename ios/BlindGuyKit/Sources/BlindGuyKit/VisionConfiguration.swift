import Foundation

/// Tuning for on-device YOLO + monocular range. **Distance:** iPhone only — `CameraIntrinsics` from `AVCaptureDevice`
/// supplies focal lengths; there is no fixed `f` in this struct.
public struct VisionConfiguration: Sendable {
    public var confidenceThreshold: Float
    public var minBboxAreaFractionInFrame: Double
    public var targetClassNames: Set<String>
    public var knownHeightsM: [String: Double]
    public var knownWidthsM: [String: Double]
    public var minEmitInterval: TimeInterval
    public var highPriorityDistanceM: Double
    public var enableLensCheck: Bool
    public var lensLaplacianThreshold: Double
    public var lensWarnConsecutive: Int
    public var lensCheckMaxSide: Int
    public var lensAnnouncementText: String
    // MARK: - Open vocabulary (text prompts baked into CoreML at export). Shipped model: YOLOv8s-Worldv2 (YOLOE-26 CoreML export is broken in ultralytics 8.4.x); see `scripts/export_yoloe_open_vocab.py`.
    public var openVocabularyClassListOrdered: [String]
    public var openVocabularyConfidenceThreshold: Float
    /// Run the open-vocab model every N vision frames (1 = every frame, 2 = half rate). When no OV model, ignored.
    public var openVocabularyRunInterval: Int
    /// If IoU( COCO, open ) ≥ this, drop the open-vocab box and keep COCO.
    public var openVocabularySuppressIfCocoIou: Double

    public static let `default` = VisionConfiguration(
        confidenceThreshold: 0.58,
        minBboxAreaFractionInFrame: 0.7,
        targetClassNames: Set([
            "person", "car", "bicycle", "motorcycle", "truck", "bus",
            "dog", "cat", "chair", "couch", "dining table", "potted plant",
            "backpack", "handbag", "suitcase", "cell phone", "laptop",
            "tv", "keyboard", "mouse", "remote",
            "bottle", "cup", "umbrella", "traffic light", "fire hydrant",
            "stop sign", "bench",
        ]),
        knownHeightsM: [
            "person": 1.70,
            "car": 1.50,
            "truck": 3.20,
            "bus": 3.50,
            "motorcycle": 1.20,
            "bicycle": 1.10,
            "dog": 0.50,
            "cat": 0.30,
            "chair": 0.90,
            "couch": 0.90,
            "dining table": 0.75,
            "laptop": 0.24,
            "tv": 0.50,
            "keyboard": 0.05,
            "mouse": 0.04,
            "remote": 0.03,
            "cell phone": 0.15,
            "bottle": 0.25,
            "cup": 0.12,
            "backpack": 0.55,
            "suitcase": 0.65,
            "traffic light": 0.90,
            "stop sign": 0.75,
            "fire hydrant": 0.60,
            "bench": 0.90,
            "umbrella": 1.00,
            "potted plant": 0.6,
            "handbag": 0.3,
            "stairs": 0.25,
            "trash can": 0.9,
            "computer": 0.45,
        ],
        knownWidthsM: [
            "person": 0.50,
            "car": 1.80,
            "truck": 2.40,
            "bus": 2.50,
            "motorcycle": 1.00,
            "bicycle": 1.70,
            "couch": 1.80,
            "dining table": 1.20,
            "laptop": 0.32,
            "tv": 0.90,
            "keyboard": 0.45,
            "mouse": 0.10,
            "remote": 0.08,
            "dog": 0.60,
            "cat": 0.40,
            "bench": 1.50,
            "suitcase": 0.45,
            "chair": 0.55,
            "potted plant": 0.45,
            "backpack": 0.4,
            "handbag": 0.4,
            "cell phone": 0.08,
            "bottle": 0.08,
            "cup": 0.1,
            "umbrella": 0.9,
            "traffic light": 0.4,
            "fire hydrant": 0.45,
            "stop sign": 0.6,
            "trash can": 0.45,
            "computer": 0.55,
        ],
        minEmitInterval: 1.0 / 15.0,
        highPriorityDistanceM: 3.0,
        enableLensCheck: false,
        lensLaplacianThreshold: 100,
        lensWarnConsecutive: 4,
        lensCheckMaxSide: 400,
        lensAnnouncementText: "",
        openVocabularyClassListOrdered: [
            "computer", "trash can", "stairs"
        ],
        openVocabularyConfidenceThreshold: 0.42,
        openVocabularyRunInterval: 1,
        openVocabularySuppressIfCocoIou: 0.5
    )

    public init(
        confidenceThreshold: Float,
        minBboxAreaFractionInFrame: Double = 0.7,
        targetClassNames: Set<String>,
        knownHeightsM: [String: Double],
        knownWidthsM: [String: Double]? = nil,
        minEmitInterval: TimeInterval,
        highPriorityDistanceM: Double,
        enableLensCheck: Bool = false,
        lensLaplacianThreshold: Double = 100,
        lensWarnConsecutive: Int = 4,
        lensCheckMaxSide: Int = 400,
        lensAnnouncementText: String = "",
        openVocabularyClassListOrdered: [String] = VisionConfiguration.default.openVocabularyClassListOrdered,
        openVocabularyConfidenceThreshold: Float = 0.45,
        openVocabularyRunInterval: Int = 2,
        openVocabularySuppressIfCocoIou: Double = 0.5
    ) {
        self.confidenceThreshold = confidenceThreshold
        self.minBboxAreaFractionInFrame = minBboxAreaFractionInFrame
        self.targetClassNames = targetClassNames
        self.knownHeightsM = knownHeightsM
        self.knownWidthsM = knownWidthsM ?? VisionConfiguration.default.knownWidthsM
        self.minEmitInterval = minEmitInterval
        self.highPriorityDistanceM = highPriorityDistanceM
        self.enableLensCheck = enableLensCheck
        self.lensLaplacianThreshold = lensLaplacianThreshold
        self.lensWarnConsecutive = lensWarnConsecutive
        self.lensCheckMaxSide = lensCheckMaxSide
        self.lensAnnouncementText = lensAnnouncementText
        self.openVocabularyClassListOrdered = openVocabularyClassListOrdered
        self.openVocabularyConfidenceThreshold = openVocabularyConfidenceThreshold
        self.openVocabularyRunInterval = openVocabularyRunInterval
        self.openVocabularySuppressIfCocoIou = openVocabularySuppressIfCocoIou
    }

    public func knownHeightMeters(for className: String) -> Double? {
        let k = className.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return knownHeightsM[k]
    }

    public func knownWidthMeters(for className: String) -> Double? {
        let k = className.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return knownWidthsM[k]
    }

    public func hasKnownPhysicalSize(for className: String) -> Bool {
        knownHeightMeters(for: className) != nil || knownWidthMeters(for: className) != nil
    }

    public func isOpenVocabularyClass(_ className: String) -> Bool {
        let k = className.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return openVocabularyClassListOrdered.contains { $0.lowercased() == k }
    }

    public func shouldRunOpenVocabularyPass(forFrameIndex frameId: Int) -> Bool {
        openVocabularyRunInterval > 0 && frameId % openVocabularyRunInterval == 0
    }
}
