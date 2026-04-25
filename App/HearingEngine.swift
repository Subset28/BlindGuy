import AVFoundation
import AVFAudio
import Combine
import Foundation
import BlindGuyKit

/// Drives the “auditory twin” audio clones from **`FramePayload`**: on-device `BlindGuySession.$lastPayload`
/// or, if no on-device path, **GET `/frame`** on the Python bridge (default `http://127.0.0.1:8765`).
///
/// When **headphones, AirPods, or another stereo** output is active, tones are played through an
/// **`AVAudioEnvironmentNode`** 3D “audio bubble” (HRTF when available) so direction is easier to
/// place than raw stereo pan. TTS remains **on** as separate announcements; it uses system output
/// and does not route into this graph (iOS does not expose AVSpeech through AVAudioEngine out of the box).
final class HearingEngine: ObservableObject {
    @Published private(set) var objectCount: Int = 0
    @Published private(set) var alertActive: Bool = false
    @Published private(set) var lastBridgeLatencyMs: Int?
    @Published private(set) var isUsingOnDevicePayload: Bool = false
    /// True when a stereo/headphone-style route (wired, AirPods, most BT stereo) is active — 3D bubble + HRTF.
    @Published private(set) var isSpatialHeadphoneRouteActive: Bool = false

    private let speechSynth = AVSpeechSynthesizer()
    private var lastSpoken: [String: Date] = [:]
    private let speakCooldownSeconds: TimeInterval = 3.0

    private let avEngine = AVAudioEngine()
    private let environment3D = AVAudioEnvironmentNode()
    private var clones: [String: AudioClone] = [:]
    private var nextEnvironmentInputBus: AVAudioNodeBus = 0
    private var freeEnvironmentBuses: [AVAudioNodeBus] = []
    private let maxEnvironmentBuses: AVAudioNodeBus = 48
    private var lastFrame: FramePayload?
    private var suppressTTSDuringCloneRebuild = false
    private var routeObserver: NSObjectProtocol?
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 0.066
    private let engineQueue = DispatchQueue(label: "com.blindguy.hearing.engine")
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

    /// Attach on-device vision; pass `nil` to use only HTTP polling to **`/frame`**.
    func reconfigure(vision: BlindGuySession?) {
        self.vision = vision
        isUsingOnDevicePayload = vision != nil
        rewire()
    }

    /// Call when the user changes the Mac/PC base URL in Settings (e.g. `http://10.0.0.3:8765`). Ignored for payload routing if on-device **vision** is active.
    func reconfigure(bridgeBase: URL) {
        UserDefaults.standard.set(bridgeBase.absoluteString, forKey: Self.bridgeURLKey)
        if vision == nil {
            rewire()
        }
    }

    /// Re-apply 3D rendering and tone graph after **hearingTones** or **spatial3DBubble** toggles in Settings (avoids a global `UserDefaults` observer that would also fire for unrelated keys).
    func applyFeatureTogglesFromUserDefaults() {
        refreshHeadphoneStateAndRendering()
    }

    init() {
        avEngine.attach(environment3D)
        avEngine.connect(environment3D, to: avEngine.mainMixerNode, format: nil)
        environment3D.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        if #available(iOS 11.0, *) {
            environment3D.renderingAlgorithm = .HRTF
        }
        avEngine.prepare()
    }

    /// Start the hearing engine. Call after audio session (if you configure it) and before `CameraPipeline` if used.
    func start(vision: BlindGuySession?) {
        self.vision = vision
        isUsingOnDevicePayload = vision != nil
        isRunning = true
        startRouteObserver()
        configureAudioSessionThenRefresh()
        engineQueue.async { [weak self] in
            guard let self else { return }
            do {
                if !self.avEngine.isRunning {
                    try self.avEngine.start()
                }
            } catch {
                print("Hearing: AVAudioEngine start failed:", error)
            }
        }
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
        engineQueue.async { [weak self] in
            self?.clones.values.forEach { $0.stop() }
            self?.clones.removeAll()
            if self?.avEngine.isRunning == true {
                self?.avEngine.stop()
            }
        }
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
            self?.refreshHeadphoneStateAndRendering()
        }
    }

    private func startRouteObserver() {
        if routeObserver != nil { return }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshHeadphoneStateAndRendering()
        }
        refreshHeadphoneStateAndRendering()
    }

    private func refreshHeadphoneStateAndRendering() {
        let routeSpatial = Self.isImmersiveStereoOutputRoute
        let use3DBubbleHRTF = routeSpatial && BlindGuyFeatureFlags.spatial3DBubble
        DispatchQueue.main.async { [weak self] in
            self?.isSpatialHeadphoneRouteActive = routeSpatial
        }
        engineQueue.async { [weak self] in
            guard let self else { return }
            if #available(iOS 11.0, *) {
                self.environment3D.renderingAlgorithm = use3DBubbleHRTF ? .HRTF : .equalPowerPanning
            }
            self.replayClonesForRouteChangeLocked()
        }
    }

    /// Wired headphones, AirPods (BT A2DP), and most stereo BT devices — **not** the built-in speaker
    /// (still works, but 3D is optimized for binaural devices).
    private static var isImmersiveStereoOutputRoute: Bool {
        for out in AVAudioSession.sharedInstance().currentRoute.outputs {
            switch out.portType {
            case .headphones, .bluetoothA2DP, .airPlay, .HDMI, .thunderbolt:
                return true
            case .bluetoothLE:
                return true
            case .builtInSpeaker, .builtInReceiver:
                return false
            case .bluetoothHFP:
                // Narrow-band; still stereo-ish on some devices — treat as off-bubble
                return false
            default:
                continue
            }
        }
        return false
    }

    /// Must run on `engineQueue` so graph + TTS gating stay consistent.
    private func replayClonesForRouteChangeLocked() {
        guard lastFrame != nil else { return }
        suppressTTSDuringCloneRebuild = true
        for c in clones.values { c.stop() }
        clones.removeAll()
        freeEnvironmentBuses.removeAll()
        nextEnvironmentInputBus = 0
        if let f = lastFrame {
            handleFrame(f)
        }
        suppressTTSDuringCloneRebuild = false
    }

    private func takeEnvironmentBus() -> AVAudioNodeBus? {
        if !freeEnvironmentBuses.isEmpty {
            return freeEnvironmentBuses.removeLast()
        }
        if nextEnvironmentInputBus >= maxEnvironmentBuses {
            return nil
        }
        let b = nextEnvironmentInputBus
        nextEnvironmentInputBus += 1
        return b
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
                    .receive(on: self.engineQueue)
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
                self.engineQueue.async { self.handleFrame(frame) }
            } catch {
                // Service warming or no frame yet
            }
        }
        task.resume()
    }

    private func handleFrame(_ frame: FramePayload) {
        let routeSpatial = Self.isImmersiveStereoOutputRoute
        let use3DPos = routeSpatial && BlindGuyFeatureFlags.spatial3DBubble
        let tonesOn = BlindGuyFeatureFlags.hearingTones

        if !tonesOn {
            let toRemove = Array(clones.values)
            for clone in toRemove {
                freeEnvironmentBuses.append(clone.inputBus)
                clone.stop()
            }
            clones.removeAll()
            for obj in frame.objects where obj.priority.uppercased() == "HIGH" {
                speakIfAllowed(obj: obj)
            }
        } else {
            let ids = Set(frame.objects.map(\.objectId))
            for (id, clone) in clones where !ids.contains(id) {
                clone.stop()
                freeEnvironmentBuses.append(clone.inputBus)
                clones.removeValue(forKey: id)
            }
            for obj in frame.objects {
                if let clone = clones[obj.objectId] {
                    clone.updatePosition(
                        pan: Float(obj.panValue),
                        distance: Float(obj.distanceM),
                        use3D: use3DPos
                    )
                    if obj.priority.uppercased() == "HIGH" {
                        speakIfAllowed(obj: obj)
                    }
                } else {
                    let freq = Self.frequency(for: obj.objectClass)
                    guard let bus = takeEnvironmentBus() else { continue }
                    let clone = AudioClone(
                        engine: avEngine,
                        environment: environment3D,
                        inputBus: bus,
                        id: obj.objectId,
                        frequency: freq
                    )
                    clones[obj.objectId] = clone
                    clone.start()
                    clone.updatePosition(
                        pan: Float(obj.panValue),
                        distance: Float(obj.distanceM),
                        use3D: use3DPos
                    )
                    if obj.priority.uppercased() == "HIGH" {
                        speakIfAllowed(obj: obj)
                    }
                }
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

    private static func frequency(for className: String) -> Double {
        switch className {
        case "car", "truck", "bus": 100
        case "person": 440
        case "bicycle", "motorcycle": 300
        default: 600
        }
    }

    private func speakIfAllowed(obj: DetectedObjectDTO) {
        if !BlindGuyFeatureFlags.hearingTTS { return }
        if suppressTTSDuringCloneRebuild { return }
        let now = Date()
        if let last = lastSpoken[obj.objectId], now.timeIntervalSince(last) < speakCooldownSeconds { return }
        lastSpoken[obj.objectId] = now
        let m = Int(round(obj.distanceM))
        let cls = obj.objectClass.capitalized
        let phrase = "\(cls), \(m) meters away"
        DispatchQueue.main.async { [weak self] in
            let u = AVSpeechUtterance(string: phrase)
            u.voice = AVSpeechSynthesisVoice(language: "en-US")
            u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            self?.speechSynth.speak(u)
        }
    }
}

// MARK: - Per-object tone (3D “bubble” + stereo fallback for speaker)

/// One looping tone, mixed into a shared `AVAudioEnvironmentNode` so **head-tracked binaural**
/// rendering (HRTF) can place it in an arc around the listener. **Pan** + **distance** from vision
/// map to a point on a horizontal ring (virtual bubble).
private final class AudioClone {
    let id: String
    fileprivate let inputBus: AVAudioNodeBus
    let player = AVAudioPlayerNode()
    let varispeed = AVAudioUnitVarispeed()
    let buffer: AVAudioPCMBuffer
    weak var engine: AVAudioEngine?

    init(
        engine: AVAudioEngine,
        environment: AVAudioEnvironmentNode,
        inputBus: AVAudioNodeBus,
        id: String,
        frequency: Double
    ) {
        self.id = id
        self.inputBus = inputBus
        self.engine = engine
        let sampleRate = 44100.0
        self.buffer = AudioClone.makeToneBuffer(
            frequency: frequency,
            sampleRate: sampleRate,
            duration: 1.0
        )
        engine.attach(player)
        engine.attach(varispeed)
        engine.connect(player, to: varispeed, format: buffer.format)
        engine.connect(varispeed, to: environment, fromBus: 0, toBus: inputBus, format: buffer.format)
        // 3D placement uses `position` on `AVAudio3DMixing` below. `sourceMode` enum cases
        // differ across iOS SDKs, so we avoid hard-coding a case name here.
    }

    func start() {
        if !player.isPlaying {
            player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            player.play()
        }
    }

    func stop() {
        player.stop()
        if let engine = engine {
            engine.detach(player)
            engine.detach(varispeed)
        }
    }

    /// `pan` is horizontal stereo cue; `distance` is meters. Placed on a 2m-scale ring in front/around the user when `use3D`.
    func updatePosition(pan: Float, distance: Float, use3D: Bool) {
        let vol = Float(max(0.05, min(1.0, 1.0 - (Double(distance) / 20.0))))
        let speed = max(0.8, min(1.5, 1.0 + (5.0 - Double(distance)) * 0.05))
        player.volume = vol
        varispeed.rate = Float(speed)

        if use3D {
            let d = max(0.1, min(40.0, Double(distance)))
            // Virtual ring radius: farther objects sit slightly farther in the 3D stage (capped for stability).
            let ring = Float(min(2.0, 0.6 + 4.0 / d))
            let az = Double(pan) * (Double.pi * 0.5)
            let x = ring * sin(Float(az))
            let z = -ring * cos(Float(az))
            if let m = player as? AVAudio3DMixing {
                m.position = AVAudio3DPoint(x: x, y: 0, z: z)
            }
        } else {
            if let m = player as? AVAudio3DMixing {
                m.position = AVAudio3DPoint(x: 0, y: 0, z: 0)
            }
        }
        // Stereo pan: primary cue when 3D bubble is off (speaker) or user disabled HRTF bubble.
        player.pan = pan
    }

    private static func makeToneBuffer(
        frequency: Double,
        sampleRate: Double,
        duration: Double
    ) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let thetaInc = 2.0 * Double.pi * frequency / sampleRate
        var theta = 0.0
        let f = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            f[i] = Float(sin(theta) * 0.25)
            theta += thetaInc
            if theta > 2.0 * Double.pi { theta -= 2.0 * Double.pi }
        }
        return buffer
    }
}
