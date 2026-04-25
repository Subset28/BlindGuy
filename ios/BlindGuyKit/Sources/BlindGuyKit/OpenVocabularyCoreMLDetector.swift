import CoreML
import Foundation
import Vision

/// Open-vocabulary CoreML (e.g. YOLO-World: `yoloe-26n-seg.mlpackage` in app). Export must **bake the same `set_classes` list** as `openVocabularyClassListOrdered` (no runtime text encoder on device).
public final class OpenVocabularyCoreMLDetector: @unchecked Sendable {
    public let config: VisionConfiguration
    private let visionModel: VNCoreMLModel

    public init(modelURL: URL, config: VisionConfiguration = .default) throws {
        self.config = config
        do {
            let m = try MLModel(contentsOf: modelURL)
            self.visionModel = try VNCoreMLModel(for: m)
        } catch {
            throw ModelLoadError.modelLoadFailed(error)
        }
    }

    public convenience init(modelResourceName: String, bundle: Bundle, config: VisionConfiguration = .default) throws {
        var url = bundle.url(forResource: modelResourceName, withExtension: "mlmodelc")
        if url == nil {
            url = bundle.url(forResource: modelResourceName, withExtension: "mlpackage")
        }
        guard let u = url else { throw ModelLoadError.fileNotFound(modelResourceName) }
        try self.init(modelURL: u, config: config)
    }

    public func makeRequest(
        handler: @escaping VNRequestCompletionHandler
    ) -> VNCoreMLRequest {
        let r = VNCoreMLRequest(model: visionModel, completionHandler: handler)
        r.imageCropAndScaleOption = .scaleFill
        r.preferBackgroundProcessing = true
        return r
    }

    func buildObservations(
        from request: VNRequest,
        error: (any Error)?,
        imageWidth: Int,
        imageHeight: Int,
        intrinsics: CameraIntrinsics
    ) -> [RawDetection] {
        if let error {
            #if DEBUG
            print("BlindGuyKit OpenVocab CoreML: \(error.localizedDescription)")
            #endif
            return []
        }
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            return []
        }
        let confThresh = config.openVocabularyConfidenceThreshold
        var out: [RawDetection] = []
        for obs in results {
            guard let top = obs.labels.first else { continue }
            let conf = top.confidence
            guard conf >= confThresh else { continue }
            var t = top.identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            if let i = Int(t), i >= 0, i < config.openVocabularyClassListOrdered.count {
                t = config.openVocabularyClassListOrdered[i]
            }
            t = t.lowercased()
            guard config.isOpenVocabularyClass(t) else { continue }
            let (xc, yc, w, h) = VisionGeometry.prdBoxFromVisionBoundingBox(obs.boundingBox)
            let visFrac = VisionGeometry.prdBboxVisibleAreaFraction(
                xCenter: xc, yCenter: yc, w: w, h: h
            )
            guard visFrac >= config.minBboxAreaFractionInFrame else { continue }
            let (dRaw, _) = VisionGeometry.estimateMonocularDistanceM(
                widthNorm: w,
                heightNorm: h,
                frameWidth: imageWidth,
                frameHeight: imageHeight,
                intrinsics: intrinsics,
                knownHeightM: config.knownHeightMeters(for: t),
                knownWidthM: config.knownWidthMeters(for: t)
            )
            let dist = dRaw.isFinite && dRaw > 0.05 ? dRaw : MonocularDistance.unmeasurableMeters
            let pan = VisionGeometry.panValue(xCenterNorm: xc)
            out.append(
                RawDetection(
                    className: t,
                    confidence: Double(conf),
                    xCenterNorm: xc,
                    yCenterNorm: yc,
                    widthNorm: w,
                    heightNorm: h,
                    distanceM: dist,
                    panValue: pan
                )
            )
        }
        return out
    }
}
