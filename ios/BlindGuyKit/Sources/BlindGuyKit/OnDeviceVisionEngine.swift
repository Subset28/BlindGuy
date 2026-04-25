import CoreVideo
import Foundation
import ImageIO
import QuartzCore
import Vision

/// Runs YOLO (CoreML) on-device, maps to PRD `FramePayload`, with drops + ~15Hz emit cap.
public final class OnDeviceVisionEngine: @unchecked Sendable {
    public let config: VisionConfiguration
    private let detector: CoreMLDetector
    private var tracker: ObjectTracker
    private let workQueue: DispatchQueue
    private let stateLock = NSLock()
    private var frameId: Int = 0
    private var lastEmitTime: TimeInterval = 0
    private let inferenceGate = FrameGate()
    private let lensState = LensStreakState()
    /// Single shared timer for the app pipeline (optional for tests / headless).
    public var pipelineTimer: PipelineTimer?
    /// Fired when `inferenceGate.tryAcquire` fails — another frame is still in CoreML.
    public var onInferenceGateDrop: (() -> Void)?
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
        completion: @escaping (FramePayload?) -> Void
    ) {
        workQueue.async { [weak self] in
            self?.processOnWorkQueue(
                pixelBuffer: pixelBuffer,
                orientation: orientation,
                intrinsics: intrinsics,
                completion: completion
            )
        }
    }

    private func processOnWorkQueue(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        intrinsics: CameraIntrinsics?,
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
            let t1 = CACurrentMediaTime()
            let mapped = self.tracker.update(detections: raw, now: t1)
            self.frameId += 1
            self.lastEmitTime = t1
            let visionMs = max(0, min(1_000_000, Int((t1 - t0) * 1000)))
            let fid = self.frameId

            var dtos: [DetectedObjectDTO] = []
            for o in mapped {
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
                        distanceM: o.distanceM,
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
