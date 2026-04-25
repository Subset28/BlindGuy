import Foundation

/// `UserDefaults` keys for the Settings menu. All features default **on** (first launch).
/// Settings writes these; engines read them (Hearing, haptics, lens, HUD).
enum BlindGuyFeatureKey {
    static let spatial3DBubble = "blindguy.feature.spatial3DBubble"
    static let hearingTones = "blindguy.feature.hearingTones"
    static let hearingTTS = "blindguy.feature.hearingTTS"
    static let haptics = "blindguy.feature.haptics"
    static let payloadHUD = "blindguy.feature.payloadHUD"
    static let lensTTS = "blindguy.feature.lensTTS"
}

enum BlindGuyFeatureFlags {
    private static let d = UserDefaults.standard

    /// 3D HRTF “bubble” vs stereo pan (audio UX label in UI; speech uses system TTS).
    static var spatial3DBubble: Bool {
        d.object(forKey: BlindGuyFeatureKey.spatial3DBubble) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.spatial3DBubble)
    }

    static var hearingTones: Bool {
        d.object(forKey: BlindGuyFeatureKey.hearingTones) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.hearingTones)
    }

    static var hearingTTS: Bool {
        d.object(forKey: BlindGuyFeatureKey.hearingTTS) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.hearingTTS)
    }

    static var haptics: Bool {
        d.object(forKey: BlindGuyFeatureKey.haptics) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.haptics)
    }

    static var payloadHUD: Bool {
        d.object(forKey: BlindGuyFeatureKey.payloadHUD) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.payloadHUD)
    }

    static var lensTTS: Bool {
        d.object(forKey: BlindGuyFeatureKey.lensTTS) == nil ? true : d.bool(forKey: BlindGuyFeatureKey.lensTTS)
    }
}
