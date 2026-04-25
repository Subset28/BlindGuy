import Foundation

/// `UserDefaults` keys for the Settings menu. All features default **on** (first launch).
/// Settings writes these; engines read them (Hearing, haptics, HUD).
enum BlindGuyFeatureKey {
    static let hearingTones = "blindguy.feature.hearingTones"
    static let hearingTTS = "blindguy.feature.hearingTTS"
    static let ttsCriticalOnly = "blindguy.feature.ttsCriticalOnly"
    static let distanceUnits = "blindguy.feature.distanceUnits"
    static let ttsVoiceStyle = "blindguy.feature.ttsVoiceStyle"
    static let ttsVerbosity = "blindguy.feature.ttsVerbosity"
    static let ttsTelemetryEnabled = "blindguy.feature.ttsTelemetryEnabled"
    static let suppressedClassesCSV = "blindguy.feature.suppressedClassesCSV"
    static let haptics = "blindguy.feature.haptics"
    static let payloadHUD = "blindguy.feature.payloadHUD"
}

enum BlindGuyFeatureFlags {
    private static let d = UserDefaults.standard

    static var hearingTones: Bool {
        d.object(forKey: BlindGuyFeatureKey.hearingTones) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.hearingTones)
    }

    static var hearingTTS: Bool {
        d.object(forKey: BlindGuyFeatureKey.hearingTTS) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.hearingTTS)
    }

    static var ttsCriticalOnly: Bool {
        d.object(forKey: BlindGuyFeatureKey.ttsCriticalOnly) == nil ? false : d.bool(forKey: BlindGuyFeatureKey.ttsCriticalOnly)
    }

    /// "metric" (default) or "imperial"
    static var distanceUnits: String {
        let raw = d.string(forKey: BlindGuyFeatureKey.distanceUnits)?.lowercased()
        return (raw == "imperial") ? "imperial" : "metric"
    }

    /// "calm" (default), "clear", "compact"
    static var ttsVoiceStyle: String {
        let raw = d.string(forKey: BlindGuyFeatureKey.ttsVoiceStyle)?.lowercased()
        switch raw {
        case "clear", "compact":
            return raw ?? "calm"
        default:
            return "calm"
        }
    }

    /// "low" (default), "normal"
    static var ttsVerbosity: String {
        let raw = d.string(forKey: BlindGuyFeatureKey.ttsVerbosity)?.lowercased()
        return (raw == "normal") ? "normal" : "low"
    }

    static var ttsTelemetryEnabled: Bool {
        d.object(forKey: BlindGuyFeatureKey.ttsTelemetryEnabled) == nil ? false : d.bool(forKey: BlindGuyFeatureKey.ttsTelemetryEnabled)
    }

    static var suppressedClasses: Set<String> {
        let raw = d.string(forKey: BlindGuyFeatureKey.suppressedClassesCSV)
            ?? "clock,vase,wine glass,teddy bear,toothbrush"
        return Set(
            raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }

    static var haptics: Bool {
        d.object(forKey: BlindGuyFeatureKey.haptics) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.haptics)
    }

    static var payloadHUD: Bool {
        d.object(forKey: BlindGuyFeatureKey.payloadHUD) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.payloadHUD)
    }
}
