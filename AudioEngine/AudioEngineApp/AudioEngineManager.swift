import Foundation
import AVFoundation
import Combine

final class AudioEngineManager: ObservableObject {
    @Published private(set) var objectCount: Int = 0
    @Published private(set) var alertActive: Bool = false
    @Published private(set) var lastBridgeLatencyMs: Int?

    private let speechSynth = AVSpeechSynthesizer()
    private var lastSpoken: [String: Date] = [:]
    private let speakCooldownSeconds: TimeInterval = 3.0

    private let engine = AVAudioEngine()
    // Use stereo panning for reliable cross-device behavior

    private var clones: [String: AudioClone] = [:]
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 0.066 // ~15Hz
    private let engineQueue = DispatchQueue(label: "audio.engine.queue")

    init() {
        setupEngine()
    }

    private func setupEngine() {
        // nothing to attach; nodes will connect to main mixer
        engine.prepare()
    }

    func start() {
        engineQueue.async {
            do {
                try self.engine.start()
            } catch {
                print("Audio engine failed to start:", error)
            }
            self.startPolling()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        engineQueue.async {
            self.engine.stop()
        }
    }

    private func startPolling() {
        DispatchQueue.main.async {
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: self.pollInterval, repeats: true) { _ in
                self.fetchFrame()
            }
            RunLoop.current.add(self.pollTimer!, forMode: .common)
        }
    }

    private func fetchFrame() {
        guard let url = URL(string: "http://127.0.0.1:8765/payload") else { return }
        let t0 = Date()
        let task = URLSession.shared.dataTask(with: url) { data, resp, err in
            let bridgeMs = Int(Date().timeIntervalSince(t0) * 1000)
            DispatchQueue.main.async {
                self.lastBridgeLatencyMs = bridgeMs
            }
            guard let data = data else { return }
            do {
                let frame = try JSONDecoder().decode(FramePayload.self, from: data)
                self.engineQueue.async {
                    self.handleFrame(frame)
                }
            } catch {
                print("Failed to decode frame:", error)
            }
        }
        task.resume()
    }

    private func handleFrame(_ frame: FramePayload) {
        let ids = Set(frame.objects.map { $0.object_id })
        // Remove clones not present
        for (id, clone) in clones where !ids.contains(id) {
            clone.stop()
            clones.removeValue(forKey: id)
        }

        for obj in frame.objects {
            if let clone = clones[obj.object_id] {
                clone.updatePosition(pan: obj.pan_value, distance: obj.distance_m)
                if obj.priority == "HIGH" {
                    speakIfAllowed(obj: obj)
                }
            } else {
                // create new clone
                let freq = AudioEngineManager.frequency(for: obj.`class`)
                let clone = AudioClone(engine: engine, id: obj.object_id, frequency: freq)
                clones[obj.object_id] = clone
                clone.start()
                clone.updatePosition(pan: obj.pan_value, distance: obj.distance_m)
                speakIfAllowed(obj: obj)
            }
        }

        DispatchQueue.main.async {
            self.objectCount = frame.objects.count
            self.alertActive = frame.objects.contains { $0.distance_m < 3.0 && ($0.velocity_mps ?? 0.0) > 1.5 }
        }
    }

    static func frequency(for className: String) -> Double {
        switch className {
        case "car", "truck", "bus": return 100
        case "person": return 440
        case "bicycle", "motorcycle": return 300
        default: return 600
        }
    }

    private func speakIfAllowed(obj: ObjectPayload) {
        let now = Date()
        if let last = lastSpoken[obj.object_id], now.timeIntervalSince(last) < speakCooldownSeconds {
            return
        }
        lastSpoken[obj.object_id] = now
        let distanceMeters = Int(round(Double(obj.distance_m)))
        let cls = obj.`class`.capitalized
        let phrase = "\(cls), \(distanceMeters) meters away"
        DispatchQueue.main.async {
            let utterance = AVSpeechUtterance(string: phrase)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            self.speechSynth.speak(utterance)
        }
    }
}

private class AudioClone {
    let id: String
    let player = AVAudioPlayerNode()
    let varispeed = AVAudioUnitVarispeed()
    let buffer: AVAudioPCMBuffer
    weak var engine: AVAudioEngine?

    init(engine: AVAudioEngine, id: String, frequency: Double) {
        self.id = id
        self.engine = engine
        let sampleRate = 44100.0
        self.buffer = AudioClone.makeToneBuffer(frequency: frequency, sampleRate: sampleRate, duration: 1.0)

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

        player.volume = Float(vol)
        varispeed.rate = Float(speed)
        player.pan = pan
    }

    static func makeToneBuffer(frequency: Double, sampleRate: Double, duration: Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let thetaIncrement = 2.0 * Double.pi * frequency / sampleRate
        var theta = 0.0
        let floatChannelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            floatChannelData[i] = Float(sin(theta) * 0.25)
            theta += thetaIncrement
            if theta > 2.0 * Double.pi { theta -= 2.0 * Double.pi }
        }

        return buffer
    }
}
