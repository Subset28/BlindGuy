import BlindGuyKit
import Combine
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import AVFoundation
#endif

/// Owns the three runtime wires: on-device **vision** (optional), **camera**, **hearing**.
@MainActor
final class AppViewModel: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var modelAvailable: Bool = false

    let hearing: HearingEngine
    private(set) var session: BlindGuySession?
    private var camera: CameraPipeline?
    private var sessionSink: AnyCancellable?
    private var hearingSink: AnyCancellable?

    init() {
        hearing = HearingEngine()
        hearingSink = hearing.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        if let detector = try? CoreMLDetector(modelResourceName: "yolov8n", bundle: .main) {
            let eng = OnDeviceVisionEngine(detector: detector)
            let s = BlindGuySession(engine: eng)
            session = s
            modelAvailable = true
            sessionSink = s.$lastPayload
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
            applyVisionSpeechPolicy()
            hearing.start(vision: s)
        } else {
            modelAvailable = false
            session = nil
            applyVisionSpeechPolicy()
            hearing.start(vision: nil)
        }
    }

    private func applyVisionSpeechPolicy() {
        hearing.setVisionSpeechEnabled(!modelAvailable || isScanning)
    }

    func setScanning(_ on: Bool) {
        isScanning = on
        applyVisionSpeechPolicy()
        guard on else {
            camera?.stop()
            camera = nil
            session?.clearPayload()
            HapticManager.shared.triggerDiscovery()
            return
        }
        HapticManager.shared.triggerDiscovery()
        #if os(iOS)
        guard let s = session else { return }
        if camera == nil { camera = CameraPipeline(vision: s) }
        Task {
            try? await camera?.start()
        }
        #endif
    }

    #if os(iOS)
    /// Live camera preview; only non-`nil` while scanning with an on-device model (same graph as `BlindGuySession`).
    var captureSessionForPreview: AVCaptureSession? { camera?.captureSession }
    #endif
}

extension AppViewModel {
    /// For dashboard cards
    var threatLabel: String {
        if !modelAvailable {
            return hearing.alertActive ? "HIGH" : "LOW"
        }
        guard isScanning else { return "LOW" }
        guard let p = session?.lastPayload, !p.objects.isEmpty else { return "LOW" }
        if p.objects.contains(where: { $0.distanceM < 3.0 && abs($0.velocityMps) > 1.5 }) {
            return "HIGH"
        }
        if p.objects.contains(where: { $0.priority.uppercased() == "HIGH" }) {
            return "MED"
        }
        return "LOW"
    }

    var cloneCount: Int {
        if modelAvailable {
            guard isScanning else { return 0 }
            if let p = session?.lastPayload { return p.objects.count }
            return 0
        }
        return hearing.objectCount
    }

    var latencyLine: String {
        if modelAvailable, isScanning, let ms = session?.lastPayload?.visionDurationMs {
            return "\(ms) ms"
        }
        if let b = hearing.lastBridgeLatencyMs, !hearing.isUsingOnDevicePayload {
            return "∼\(b) ms"
        }
        return "—"
    }
}
