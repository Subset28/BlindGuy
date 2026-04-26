import CoreVideo
import Foundation
import ImageIO
import QuartzCore
import Vision
#if canImport(ARKit)
import ARKit
#endif

/// Runs YOLO (CoreML) on-device, maps to PRD `FramePayload`, with drops + ~15Hz emit cap.
public final class OnDeviceVisionEngine: @unchecked Sendable {
    public let config: VisionConfiguration
    private let detector: CoreMLDetector
    private var tracker: ObjectTracker
    private let workQueue: DispatchQueue
    private let stateLock = NSLock()
    private var frameId: Int = 0
    private var inFlight: Bool = false
    private var lastEmitTime: TimeInterval = 0
    private let lensState = LensStreakState()
    /// Single shared timer for the app pipeline (optional for tests / headless).
    public var pipelineTimer: PipelineTimer?
    /// Called on the vision work queue after each successfully built `FramePayload` (for perf rollups).
    public var onFrameEmittedForPerf: (() -> Void)?
    /// Stale track ids pruned from the object tracker (see `ObjectTracker`).
    public var onStaleObjectPrune: ((Int) -> Void)?
    #if os(iOS)
    private var lastIntrinsics: CameraIntrinsics?
    #endif

    public init(detector: CoreMLDetector) {
        self.detector = detector
        self.config = detector.config
        let tr = ObjectTracker(
            highPriorityDistanceM: detector.config.highPriorityDistanceM
        )
        self.tracker = tr
        self.workQueue = DispatchQueue(
            label: "com.blindguy.vision",
            qos: .userInitiated
        )
        tr.onStalePrune = { [weak self] count in
            self?.onStaleObjectPrune?(count)
        }
    }

    deinit {
        workQueue.sync { }
    }

    /// Process one camera frame. `completion` is called on the **main** queue **only** when a `FramePayload` is emitted.
    /// Dropped frames (in-flight, rate limit) and handler errors do **not** call `completion` — avoids main-queue storms.
    public func process(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        intrinsics: CameraIntrinsics? = nil,
        arFrame: Any? = nil,
        completion: @escaping (FramePayload?) -> Void
    ) {
        workQueue.async { [weak self] in
            self?.processOnWorkQueue(
                pixelBuffer: pixelBuffer,
                orientation: orientation,
                intrinsics: intrinsics,
                arFrame: arFrame,
                completion: completion
            )
        }
    }

    private var consecutiveLidarFallbacks: [String: Int] = [:]

    private func processOnWorkQueue(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        intrinsics: CameraIntrinsics?,
        arFrame: Any?,
        completion: @escaping (FramePayload?) -> Void
    ) {
        let captured = pixelBuffer
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        #if os(iOS)
        if let i = intrinsics { lastIntrinsics = i }
        guard let merged = intrinsics ?? lastIntrinsics else {
            return
        }
        lastIntrinsics = merged
        #else
        let merged = intrinsics
            ?? CameraIntrinsics.evalOnlyFromFrameDimensions(width: w, height: h, horizontalFOVDeg: 63)
        #endif

        stateLock.lock()
        if inFlight {
            stateLock.unlock()
            return
        }
        let now = CACurrentMediaTime()
        if now - lastEmitTime < config.minEmitInterval * 0.9 {
            stateLock.unlock()
            return
        }
        inFlight = true
        stateLock.unlock()

        let t0 = CACurrentMediaTime()

        let request = detector.makeRequest { [weak self] request, err in
            guard let self else { return }
            self.stateLock.lock()
            defer { self.inFlight = false; self.stateLock.unlock() }
            let raw = self.detector.buildObservations(
                from: request,
                error: err,
                imageWidth: w,
                imageHeight: h,
                intrinsics: merged
            )
            self.frameId += 1
            let fid = self.frameId
            let t1 = CACurrentMediaTime()
            let mapped = self.tracker.update(detections: raw, now: t1, frameIndex: fid)
            self.lastEmitTime = t1
            let visionMs = max(0, min(1_000_000, Int((t1 - t0) * 1000)))

            var dtos: [DetectedObjectDTO] = []
            let capability = detectDepthCapability()
            for o in mapped {
                var distanceM = o.distanceM
                var distanceConf: DistanceConfidence? = nil

                #if canImport(ARKit)
                if capability == .lidar, let frame = arFrame as? ARFrame {
                    // convert center-based bbox to top-left normalized rect
                    let minX = o.xCenterNorm - 0.5 * o.widthNorm
                    let minY = o.yCenterNorm - 0.5 * o.heightNorm
                    let bboxRect = CGRect(x: minX, y: minY, width: o.widthNorm, height: o.heightNorm)
                    let sample = sampleDepth(from: frame, bbox: bboxRect)
                    if sample.isValid {
                        distanceM = Double(sample.distanceM)
                        distanceConf = sample.distanceConfidence
                        // reset consecutive fallback counter
                        consecutiveLidarFallbacks[o.objectId] = 0
                    } else {
                        // LiDAR invalid — fall back to monocular but force low confidence and log
                        distanceConf = .low
                        consecutiveLidarFallbacks[o.objectId, default: 0] += 1
                        TelemetryRecorder.shared.record("lidar_fallback", objectID: o.objectId, className: o.className)
                        if consecutiveLidarFallbacks[o.objectId]! >= 5 {
                            TelemetryRecorder.shared.record("lidar_persistent_failure", objectID: o.objectId, className: o.className)
                        }
                    }
                }
                #endif

                dtos.append(
                    DetectedObjectDTO(
                        objectId: o.objectId,
                        objectClass: o.className,
                        confidence: (o.confidence * 100).rounded() / 100,
                        bbox: BBoxNorm(
                            xCenterNorm: o.xCenterNorm,
                            yCenterNorm: o.yCenterNorm,
                            widthNorm: o.widthNorm,
                            heightNorm: o.heightNorm
                        ),
                        distanceM: distanceM,
                        distanceConfidence: distanceConf,
                        panValue: o.panValue,
                        velocityMps: (o.velocityMps * 100).rounded() / 100,
                        priority: o.priority
                    )
                )
            }
            let cam: CameraHealthDTO? = {
                guard self.config.enableLensCheck else { return nil }
                let lap = LensQualityAnalyzer.laplacianVariance(
                    pixelBuffer: captured,
                    maxSide: self.config.lensCheckMaxSide
                )
                return self.lensState.update(lapVar: lap, config: self.config)
            }()
            let payload = FramePayload(
                frameId: fid,
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                visionDurationMs: visionMs,
                objects: dtos,
                camera: cam
            )
            DispatchQueue.main.async { completion(payload) }
        }

        // `VNCoreMLRequest.preferBackgroundProcessing` is set in `CoreMLDetector.makeRequest`.
        // (Do not use `VNImageOption` for this — the symbol is not available on all iOS SDKs.)
        do {
            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: orientation,
                options: [:]
            )
            try handler.perform([request])
        } catch {
            stateLock.lock()
            inFlight = false
            stateLock.unlock()
            #if DEBUG
            print("BlindGuyKit perform: \(error)")
            #endif
        }
    }

    public func resetTracker() {
        workQueue.async { [self] in
            self.stateLock.lock()
            self.tracker = ObjectTracker(
                highPriorityDistanceM: self.config.highPriorityDistanceM
            )
            self.stateLock.unlock()
            self.lensState.reset()
        }
    }
}
