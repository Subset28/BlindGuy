import AVFoundation
import Combine
import Foundation
import BlindGuyKit

/// Consumes **`FramePayload`** from on-device **`BlindGuySession`** or **GET `/frame`** on the bridge.
/// Object **names** are spoken with `AVSpeechSynthesizer` (system TTS). Vision already estimates depth with a pinhole
/// / similar-triangles model (`known height × focal ÷ bbox height` in `BlindGuyKit`). Here we **rank** detections by
/// closeness + class (similar in spirit to threat ordering in [OmniSight](https://github.com/Subset28/OmniSight)), speak **at
/// most once per frame**, and dedupe by track id *and* coarse position so unstable IDs do not cause “person…person…person.”
final class HearingEngine: ObservableObject {
    @Published private(set) var objectCount: Int = 0
    @Published private(set) var alertActive: Bool = false
    @Published private(set) var lastBridgeLatencyMs: Int?
    @Published private(set) var isUsingOnDevicePayload: Bool = false
    /// Headphone / stereo route — for UI hints (spatial audio UX is TTS-only here).
    @Published private(set) var isSpatialHeadphoneRouteActive: Bool = false

    private let speechSynth = AVSpeechSynthesizer()
    private var lastSpokenByObjectId: [String: Date] = [:]
    private var lastSpokenBySpatialKey: [String: Date] = [:]
    private var lastSpeechAt: Date?
    /// Same physical object should not re-announce every frame; also enforced via spatial grid when `object_id` jitters.
    private let cooldownSameTrackSeconds: TimeInterval = 6.0
    private let cooldownSameSpatialCellSeconds: TimeInterval = 5.0
    /// Prevents TTS from queueing dozens of lines in one runloop tick.
    private let minIntervalAnySpeechSeconds: TimeInterval = 0.55
    private let maxNameAnnouncementsPerFrame: Int = 1

    private let workQueue = DispatchQueue(label: "com.blindguy.hearing.work", qos: .userInitiated)
    private var lastFrame: FramePayload?
    private var routeObserver: NSObjectProtocol?
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 0.066
    private var cancellable: AnyCancellable?
    private weak var vision: BlindGuySession?
    private var isRunning: Bool = false
    /// On-device: only true while the camera is running (`!modelAvailable` bridge mode stays on). Synchronized.
    private let speechGateLock = NSLock()
    private var allowsFrameSpeech: Bool = false
    /// Keeps TTS in line with the vision filter; bridge JSON may be unfiltered, so this still helps.
    private static let minConfidenceForSpeech: Double = 0.62

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

    /// Stops TTS and gates speech. Call with `!modelAvailable || isScanning` for on-device (bridge-only keeps speech on).
    /// Updates the gate **synchronously** so no frame is spoken before this returns.
    func setVisionSpeechEnabled(_ enabled: Bool) {
        speechGateLock.lock()
        allowsFrameSpeech = enabled
        speechGateLock.unlock()
        if !enabled {
            workQueue.async { [weak self] in
                self?.lastSpokenByObjectId.removeAll()
                self?.lastSpokenBySpatialKey.removeAll()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.objectCount = 0
                self.alertActive = false
                self.speechSynth.stopSpeaking(at: .immediate)
            }
        }
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
            self?.speechSynth.stopSpeaking(at: .immediate)
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
        speechGateLock.lock()
        let allow = allowsFrameSpeech
        speechGateLock.unlock()
        guard allow else { return }

        let announceEach = BlindGuyFeatureFlags.hearingTones
        let includeDistance = BlindGuyFeatureFlags.hearingTTS
        pruneStaleSpeechHistory(now: Date())

        let pool = frame.objects
            .filter { $0.confidence >= Self.minConfidenceForSpeech }
            .sorted { Self.interestScore($0) > Self.interestScore($1) }

        if announceEach {
            var n = 0
            for obj in pool {
                if n >= maxNameAnnouncementsPerFrame { break }
                if trySpeakObjectNameIfAllowed(obj: obj, includeDistance: includeDistance) {
                    n += 1
                }
            }
        } else {
            var n = 0
            let high = pool.filter { $0.priority.uppercased() == "HIGH" }
            for obj in high {
                if n >= maxNameAnnouncementsPerFrame { break }
                if trySpeakPriorityObjectIfAllowed(obj: obj) { n += 1 }
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

    /// **Class** + optional **distance**; returns `true` if a line was queued.
    private func trySpeakObjectNameIfAllowed(obj: DetectedObjectDTO, includeDistance: Bool) -> Bool {
        let now = Date()
        if !passesGlobalAndDedupeGates(obj: obj, now: now, useSpatialGrid: true) { return false }
        let name = Self.humanizeClassName(obj.objectClass)
        let phrase: String
        if includeDistance {
            let m = max(0, Int(round(obj.distanceM)))
            phrase = "\(name), \(m) meters"
        } else {
            phrase = name
        }
        markSpoken(obj: obj, now: now)
        enqueueSpeech(phrase, at: now)
        return true
    }

    /// **High-priority** only, distance in phrase (requires distance TTS on).
    private func trySpeakPriorityObjectIfAllowed(obj: DetectedObjectDTO) -> Bool {
        if !BlindGuyFeatureFlags.hearingTTS { return false }
        let now = Date()
        if !passesGlobalAndDedupeGates(obj: obj, now: now, useSpatialGrid: true) { return false }
        let m = Int(round(obj.distanceM))
        let name = Self.humanizeClassName(obj.objectClass)
        let phrase = "\(name), \(m) meters away"
        markSpoken(obj: obj, now: now)
        enqueueSpeech(phrase, at: now)
        return true
    }

    private func passesGlobalAndDedupeGates(
        obj: DetectedObjectDTO,
        now: Date,
        useSpatialGrid: Bool
    ) -> Bool {
        if let t = lastSpeechAt, now.timeIntervalSince(t) < minIntervalAnySpeechSeconds { return false }
        if let last = lastSpokenByObjectId[obj.objectId], now.timeIntervalSince(last) < cooldownSameTrackSeconds {
            return false
        }
        if useSpatialGrid {
            let k = Self.spatialDedupeKey(obj: obj)
            if let last = lastSpokenBySpatialKey[k], now.timeIntervalSince(last) < cooldownSameSpatialCellSeconds {
                return false
            }
        }
        return true
    }

    private func markSpoken(obj: DetectedObjectDTO, now: Date) {
        lastSpokenByObjectId[obj.objectId] = now
        lastSpokenBySpatialKey[Self.spatialDedupeKey(obj: obj)] = now
    }

    private static func spatialDedupeKey(obj: DetectedObjectDTO) -> String {
        let c = obj.objectClass.lowercased()
        let x = Int((obj.bbox.xCenterNorm * 15.0).rounded())
        let y = Int((obj.bbox.yCenterNorm * 15.0).rounded())
        return "\(c)|\(x)|\(y)"
    }

    /// Closer, heavier classes, and `HIGH` priority win (same idea as OmniSight `get_threat` ordering).
    private static func interestScore(_ o: DetectedObjectDTO) -> Double {
        let d = max(0.1, o.distanceM)
        let pri = o.priority.uppercased() == "HIGH" ? 1.5 : 1.0
        let w = classImportance(o.objectClass)
        return w * pri * (1.0 / d) * (0.55 + 0.45 * min(1.0, o.confidence))
    }

    private static func classImportance(_ raw: String) -> Double {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t == "truck" || t == "bus" || t == "car" { return 3.0 }
        if t == "person" { return 1.5 }
        if t == "bicycle" || t == "motorcycle" { return 1.2 }
        return 1.0
    }

    private func pruneStaleSpeechHistory(now: Date) {
        let cap: TimeInterval = 45
        lastSpokenByObjectId = lastSpokenByObjectId.filter { now.timeIntervalSince($0.value) < cap }
        lastSpokenBySpatialKey = lastSpokenBySpatialKey.filter { now.timeIntervalSince($0.value) < cap }
    }

    private func enqueueSpeech(_ phrase: String, at now: Date) {
        lastSpeechAt = now
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
