#if os(iOS)
import AVFoundation
import Combine
import Foundation
import QuartzCore

/// Speaks a short lens warning with cooldown so we do not spam VoiceOver / TTS.
@MainActor
public final class LensWarningAnnouncer: ObservableObject {
    public var minInterval: TimeInterval = 45
    private let synth = AVSpeechSynthesizer()
    private var lastSpoken: TimeInterval = 0

    public init() {}

    /// `UserDefaults` key `blindguy.feature.lensTTS` (default on). Shared with the app Settings screen.
    private static var isLensTTSFeatureEnabled: Bool {
        let d = UserDefaults.standard
        if d.object(forKey: "blindguy.feature.lensTTS") == nil { return true }
        return d.bool(forKey: "blindguy.feature.lensTTS")
    }

    public func announceIfNeeded(camera: CameraHealthDTO?) {
        guard Self.isLensTTSFeatureEnabled else { return }
        guard let camera else { return }
        guard camera.lensStatus == "warning" else { return }
        guard let text = camera.lensAnnounce, !text.isEmpty else { return }
        let now = CACurrentMediaTime()
        if now - lastSpoken < minInterval { return }
        lastSpoken = now
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synth.speak(u)
    }
}
#endif
