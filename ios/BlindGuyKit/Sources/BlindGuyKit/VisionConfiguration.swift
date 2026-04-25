import Foundation

/// Tuning aligned with `PRD.md` and Python `src/visual_engine/config.py`.
public struct VisionConfiguration: Sendable {
    public var confidenceThreshold: Float
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
        confidenceThreshold: 0.62,
        targetClassNames: [
            "person", "car", "bicycle", "motorcycle", "truck", "bus",
        ],
        knownHeightsM: [
            "person": 1.7,
            "car": 1.5,
            "bicycle": 1.1,
            "motorcycle": 1.3,
            "truck": 3.5,
            "bus": 3.2,
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
