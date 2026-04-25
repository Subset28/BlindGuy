import AVFoundation
import Combine
import Foundation
import BlindGuyKit

/// Drives the “auditory twin” audio clones from **`FramePayload`**: on-device `BlindGuySession.$lastPayload`
/// or, if no on-device path, **GET `/frame`** on the Python bridge (default `http://127.0.0.1:8765`).
final class HearingEngine: ObservableObject {
    @Published private(set) var objectCount: Int = 0
    @Published private(set) var alertActive: Bool = false
    @Published private(set) var lastBridgeLatencyMs: Int?
    @Published private(set) var isUsingOnDevicePayload: Bool = false

    private let speechSynth = AVSpeechSynthesizer()
    private var lastSpoken: [String: Date] = [:]
    private let speakCooldownSeconds: TimeInterval = 3.0

    private let avEngine = AVAudioEngine()
    private var clones: [String: AudioClone] = [:]
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

    init() {
        avEngine.prepare()
    }

    /// Start the hearing engine. Call after audio session (if you configure it) and before `CameraPipeline` if used.
    func start(vision: BlindGuySession?) {
        self.vision = vision
        isUsingOnDevicePayload = vision != nil
        isRunning = true
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
        let ids = Set(frame.objects.map(\.objectId))
        for (id, clone) in clones where !ids.contains(id) {
            clone.stop()
            clones.removeValue(forKey: id)
        }
        for obj in frame.objects {
            if let clone = clones[obj.objectId] {
                clone.updatePosition(
                    pan: Float(obj.panValue),
                    distance: Float(obj.distanceM)
                )
                if obj.priority.uppercased() == "HIGH" {
                    speakIfAllowed(obj: obj)
                }
            } else {
                let freq = Self.frequency(for: obj.objectClass)
                let clone = AudioClone(engine: avEngine, id: obj.objectId, frequency: freq)
                clones[obj.objectId] = clone
                clone.start()
                clone.updatePosition(
                    pan: Float(obj.panValue),
                    distance: Float(obj.distanceM)
                )
                speakIfAllowed(obj: obj)
            }
        }
        let alert = frame.objects.contains { o in
            o.distanceM < 3.0 && abs(o.velocityMps) > 1.5
        }
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

// MARK: - Per-object tone

private final class AudioClone {
    let id: String
    let player = AVAudioPlayerNode()
    let varispeed = AVAudioUnitVarispeed()
    let buffer: AVAudioPCMBuffer
    weak var engine: AVAudioEngine?

    init(engine: AVAudioEngine, id: String, frequency: Double) {
        self.id = id
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
        engine.connect(varispeed, to: engine.mainMixerNode, format: buffer.format)
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

    func updatePosition(pan: Float, distance: Float) {
        let vol = max(0.05, min(1.0, 1.0 - (Double(distance) / 20.0)))
        let speed = max(0.8, min(1.5, 1.0 + (5.0 - Double(distance)) * 0.05))
        player.volume = vol
        varispeed.rate = Float(speed)
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
