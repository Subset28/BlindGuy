import AVFoundation
import Combine
import Foundation
import BlindGuyKit

/// Consumes **`FramePayload`** from on-device **`BlindGuySession`** or **GET `/frame`** on the bridge.
/// Object **names** are spoken with `AVSpeechSynthesizer` (system TTS), with throttling per track. No beeps.
final class HearingEngine: ObservableObject {
    @Published private(set) var objectCount: Int = 0
    @Published private(set) var alertActive: Bool = false
    @Published private(set) var lastBridgeLatencyMs: Int?
    @Published private(set) var isUsingOnDevicePayload: Bool = false
    /// Headphone / stereo route — for UI hints (spatial audio UX is TTS-only here).
    @Published private(set) var isSpatialHeadphoneRouteActive: Bool = false

    private let speechSynth = AVSpeechSynthesizer()
    private var lastSpokenByObject: [String: Date] = [:]
    /// Per-object cooldown so the list doesn’t spam every frame.
    private let nameSpeakCooldownSeconds: TimeInterval = 2.2

    private let workQueue = DispatchQueue(label: "com.blindguy.hearing.work", qos: .userInitiated)
    private var lastFrame: FramePayload?
    private var routeObserver: NSObjectProtocol?
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 0.066
    private var cancellable: AnyCancellable?
    private weak var vision: BlindGuySession?
    private var isRunning: Bool = false

    private static let bridgeURLKey = "blindguy.visionBridgeBaseURLString"

    static var defaultBridgeBaseURL: URL { URL(string: "http://127.0.0.1:8765")! }

    private static func loadBridgeBaseFromDefaults() -> URL {
        if let s = UserDefaults.standard.string(forKey: bridgeURLKey), !s.isEmpty, let u = URL(string: s) {
            return u
        }
        return defaultBridgeBaseURL
    }

    func reconfigure(vision: BlindGuySession?) {
        self.vision = vision
        isUsingOnDevicePayload = vision != nil
        rewire()
    }

    func reconfigure(bridgeBase: URL) {
        UserDefaults.standard.set(bridgeBase.absoluteString, forKey: Self.bridgeURLKey)
        if vision == nil {
            rewire()
        }
    }

    func applyFeatureTogglesFromUserDefaults() {
        refreshHeadphoneStateForUI()
    }

    init() {}

    func start(vision: BlindGuySession?) {
        self.vision = vision
        isUsingOnDevicePayload = vision != nil
        isRunning = true
        startRouteObserver()
        configureAudioSessionThenRefresh()
        rewire()
    }

    func stop() {
        isRunning = false
        if let o = routeObserver {
            NotificationCenter.default.removeObserver(o)
            routeObserver = nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = nil
        }
        cancellable = nil
    }

    deinit { stop() }

    private func configureAudioSessionThenRefresh() {
        DispatchQueue.main.async { [weak self] in
            let s = AVAudioSession.sharedInstance()
            do {
                try s.setCategory(
                    .playback,
                    mode: .default,
                    options: [.allowBluetoothA2DP, .allowBluetooth, .mixWithOthers, .defaultToSpeaker]
                )
                try s.setActive(true, options: [])
            } catch {
                print("Hearing: AVAudioSession config:", error)
            }
            self?.refreshHeadphoneStateForUI()
        }
    }

    private func startRouteObserver() {
        if routeObserver != nil { return }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshHeadphoneStateForUI()
        }
        refreshHeadphoneStateForUI()
    }

    private func refreshHeadphoneStateForUI() {
        let spatial = Self.isImmersiveStereoOutputRoute
        DispatchQueue.main.async { [weak self] in
            self?.isSpatialHeadphoneRouteActive = spatial
        }
    }

    private static var isImmersiveStereoOutputRoute: Bool {
        for out in AVAudioSession.sharedInstance().currentRoute.outputs {
            switch out.portType {
            case .headphones, .bluetoothA2DP, .airPlay, .HDMI, .thunderbolt, .bluetoothLE:
                return true
            case .builtInSpeaker, .builtInReceiver, .bluetoothHFP:
                return false
            default:
                continue
            }
        }
        return false
    }

    private func rewire() {
        pollTimer?.invalidate()
        pollTimer = nil
        cancellable = nil

        if let v = vision {
            isUsingOnDevicePayload = true
            DispatchQueue.main.async { [weak self, weak v] in
                guard let self, let v else { return }
                self.cancellable = v.$lastPayload
                    .compactMap { $0 }
                    .receive(on: self.workQueue)
                    .sink { [weak self] p in
                        self?.handleFrame(p)
                    }
            }
        } else {
            isUsingOnDevicePayload = false
            guard isRunning else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pollTimer = Timer.scheduledTimer(
                    withTimeInterval: self.pollInterval,
                    repeats: true
                ) { [weak self] _ in
                    self?.fetchFrameFromBridge()
                }
                if let t = self.pollTimer {
                    RunLoop.main.add(t, forMode: .common)
                }
            }
        }
    }

    private func fetchFrameFromBridge() {
        let base = Self.loadBridgeBaseFromDefaults()
        let u = base.appendingPathComponent("frame", isDirectory: false)
        let t0 = Date()
        let task = URLSession.shared.dataTask(with: u) { [weak self] data, _, _ in
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            DispatchQueue.main.async { self?.lastBridgeLatencyMs = ms }
            guard let data, let self else { return }
            do {
                let dec = JSONDecoder()
                let frame = try dec.decode(FramePayload.self, from: data)
                self.workQueue.async { self.handleFrame(frame) }
            } catch {}
        }
        task.resume()
    }

    private func handleFrame(_ frame: FramePayload) {
        let announceEach = BlindGuyFeatureFlags.hearingTones
        let includeDistance = BlindGuyFeatureFlags.hearingTTS

        if announceEach {
            for obj in frame.objects {
                speakObjectNameIfAllowed(obj: obj, includeDistance: includeDistance)
            }
        } else {
            for obj in frame.objects where obj.priority.uppercased() == "HIGH" {
                speakPriorityObjectIfAllowed(obj: obj)
            }
        }

        let alert = frame.objects.contains { o in
            o.distanceM < 3.0 && abs(o.velocityMps) > 1.5
        }
        lastFrame = frame
        DispatchQueue.main.async { [weak self] in
            self?.objectCount = frame.objects.count
            self?.alertActive = alert
        }
    }

    /// Spoken when “announce each object” is on: **class** name, optional **distance** if TTS is on.
    private func speakObjectNameIfAllowed(obj: DetectedObjectDTO, includeDistance: Bool) {
        let now = Date()
        if let last = lastSpokenByObject[obj.objectId], now.timeIntervalSince(last) < nameSpeakCooldownSeconds { return }
        lastSpokenByObject[obj.objectId] = now
        let name = Self.humanizeClassName(obj.objectClass)
        let phrase: String
        if includeDistance {
            let m = max(0, Int(round(obj.distanceM)))
            phrase = "\(name), \(m) meters"
        } else {
            phrase = name
        }
        enqueueSpeech(phrase)
    }

    /// When “announce each object” is off: only **high-priority** lines with distance (needs distance TTS on).
    private func speakPriorityObjectIfAllowed(obj: DetectedObjectDTO) {
        if !BlindGuyFeatureFlags.hearingTTS { return }
        let now = Date()
        if let last = lastSpokenByObject["prio:\(obj.objectId)"], now.timeIntervalSince(last) < nameSpeakCooldownSeconds { return }
        lastSpokenByObject["prio:\(obj.objectId)"] = now
        let m = Int(round(obj.distanceM))
        let name = Self.humanizeClassName(obj.objectClass)
        let phrase = "\(name), \(m) meters away"
        enqueueSpeech(phrase)
    }

    private func enqueueSpeech(_ phrase: String) {
        DispatchQueue.main.async { [weak self] in
            let u = AVSpeechUtterance(string: phrase)
            u.voice = AVSpeechSynthesisVoice(language: "en-US")
            u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
            self?.speechSynth.speak(u)
        }
    }

    private static func humanizeClassName(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "Unknown" }
        if t.contains("_") { return t.replacingOccurrences(of: "_", with: " ") }
        return t.prefix(1).uppercased() + t.dropFirst().lowercased()
    }
}
