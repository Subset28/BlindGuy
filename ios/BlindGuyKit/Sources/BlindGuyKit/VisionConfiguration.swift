import Foundation

/// Tuning aligned with `PRD.md` and Python `src/visual_engine/config.py`.
public struct VisionConfiguration: Sendable {
    public var confidenceThreshold: Float
    /// `intersection(bbox, image)) / area(bbox)` in PRD normalized coords. Drops mostly off-frame boxes.
    public var minBboxAreaFractionInFrame: Double
    public var targetClassNames: Set<String>
    public var knownHeightsM: [String: Double]
    public var focalLengthPixels: Double
    public var minEmitInterval: TimeInterval
    public var highPriorityDistanceM: Double
    public var enableLensCheck: Bool
    public var lensLaplacianThreshold: Double
    public var lensWarnConsecutive: Int
    public var lensCheckMaxSide: Int
    public var lensAnnouncementText: String

    public static let `default` = VisionConfiguration(
        confidenceThreshold: 0.58,
        minBboxAreaFractionInFrame: 0.7,
        targetClassNames: Set([
            "person", "car", "bicycle", "motorcycle", "truck", "bus",
            "dog", "cat", "chair", "couch", "dining table", "potted plant",
            "backpack", "handbag", "suitcase", "cell phone", "laptop",
            "bottle", "cup", "umbrella", "traffic light", "fire hydrant",
            "stop sign", "bench",
        ]),
        knownHeightsM: [
            "person": 1.7,
            "car": 1.5,
            "bicycle": 1.1,
            "motorcycle": 1.3,
            "truck": 3.5,
            "bus": 3.2,
            "dog": 0.6,
            "cat": 0.3,
            "chair": 0.9,
            "couch": 0.9,
            "dining table": 0.8,
            "potted plant": 0.6,
            "backpack": 0.5,
            "handbag": 0.3,
            "suitcase": 0.7,
            "cell phone": 0.15,
            "laptop": 0.3,
            "bottle": 0.25,
            "cup": 0.15,
            "umbrella": 1.0,
            "traffic light": 1.0,
            "fire hydrant": 0.8,
            "stop sign": 0.8,
            "bench": 0.9,
        ],
        focalLengthPixels: 850,
        minEmitInterval: 1.0 / 15.0,
        highPriorityDistanceM: 3.0,
        enableLensCheck: false,
        lensLaplacianThreshold: 100,
        lensWarnConsecutive: 4,
        lensCheckMaxSide: 400,
        lensAnnouncementText: ""
    )

    public init(
        confidenceThreshold: Float,
        minBboxAreaFractionInFrame: Double = 0.7,
        targetClassNames: Set<String>,
        knownHeightsM: [String: Double],
        focalLengthPixels: Double,
        minEmitInterval: TimeInterval,
        highPriorityDistanceM: Double,
        enableLensCheck: Bool = false,
        lensLaplacianThreshold: Double = 100,
        lensWarnConsecutive: Int = 4,
        lensCheckMaxSide: Int = 400,
        lensAnnouncementText: String = ""
    ) {
        self.confidenceThreshold = confidenceThreshold
        self.minBboxAreaFractionInFrame = minBboxAreaFractionInFrame
        self.targetClassNames = targetClassNames
        self.knownHeightsM = knownHeightsM
        self.focalLengthPixels = focalLengthPixels
        self.minEmitInterval = minEmitInterval
        self.highPriorityDistanceM = highPriorityDistanceM
        self.enableLensCheck = enableLensCheck
        self.lensLaplacianThreshold = lensLaplacianThreshold
        self.lensWarnConsecutive = lensWarnConsecutive
        self.lensCheckMaxSide = lensCheckMaxSide
        self.lensAnnouncementText = lensAnnouncementText
    }
}
