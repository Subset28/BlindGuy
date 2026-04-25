import Foundation

enum DetectionConfig {
    /// Classes treated as immediate mobility hazards for speech escalation.
    static let highPriorityClasses: Set<String> = [
        "person", "car", "truck", "bus", "motorcycle", "bicycle"
    ]

    /// Classes that should never be spoken even if detected.
    static let defaultSuppressedClasses: Set<String> = [
        "clock", "vase", "wine glass", "teddy bear", "toothbrush"
    ]

    /// Reasonable operating range for monocular distance.
    static let minDistanceM: Double = 0.1
    static let maxDistanceM: Double = 60.0
}
