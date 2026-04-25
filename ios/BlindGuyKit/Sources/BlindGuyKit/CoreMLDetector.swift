import CoreML
import Foundation
import Vision

public enum ModelLoadError: Error {
    case fileNotFound(String)
    case modelLoadFailed(Error)
}

/// Wraps a CoreML YOLO (Ultralytics export with NMS) for Vision. Prefer an export with `nms=True` so
/// `VNRecognizedObjectObservation` is produced.
public final class CoreMLDetector: @unchecked Sendable {
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

    /// Bundle resource name without extension, e.g. `yolov8n` for `yolov8n.mlpackage`.
    public convenience init(modelResourceName: String, bundle: Bundle, config: VisionConfiguration = .default) throws {
        var url = bundle.url(forResource: modelResourceName, withExtension: "mlmodelc")
        if url == nil {
            url = bundle.url(forResource: modelResourceName, withExtension: "mlpackage")
        }
        guard let u = url else {
            throw ModelLoadError.fileNotFound(modelResourceName)
        }
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
            print("BlindGuyKit CoreML: \(error.localizedDescription)")
            #endif
            return []
        }
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            return []
        }

        var out: [RawDetection] = []
        for obs in results {
            guard let top = obs.labels.first else { continue }
            let conf = top.confidence
            guard conf >= config.confidenceThreshold else { continue }

            let rawName = labelString(from: top.identifier)
            let t = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard config.targetClassNames.contains(t) else { continue }

            let (xc, yc, w, h) = VisionGeometry.prdBoxFromVisionBoundingBox(obs.boundingBox)
            let visFrac = VisionGeometry.prdBboxVisibleAreaFraction(
                xCenter: xc,
                yCenter: yc,
                w: w,
                h: h
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
            // Unmeasurable distance: keep finite sentinel so tracking priority does not treat "unknown" as 0m (high-priority).
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

    private func labelString(from identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = Int(trimmed), i >= 0, i < COCOMapping.classNames.count {
            return COCOMapping.classNames[i].lowercased()
        }
        return trimmed.lowercased()
    }
}
