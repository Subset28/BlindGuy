import Combine
import CoreVideo
import ImageIO

/// SwiftUI-friendly wrapper: publish the latest `FramePayload` on the main actor.
@MainActor
public final class BlindGuySession: ObservableObject {
    @Published public private(set) var lastPayload: FramePayload?
    public let engine: OnDeviceVisionEngine
    #if os(iOS)
    public let lensAnnouncer: LensWarningAnnouncer?
    #endif

    public init(
        engine: OnDeviceVisionEngine,
        enableLensSpeech: Bool = true
    ) {
        self.engine = engine
        #if os(iOS)
        self.lensAnnouncer = enableLensSpeech ? LensWarningAnnouncer() : nil
        #endif
    }

    public func ingest(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) {
        engine.process(pixelBuffer: pixelBuffer, orientation: orientation) { [weak self] payload in
            guard let payload else { return }
            #if os(iOS)
            self?.lensAnnouncer?.announceIfNeeded(camera: payload.camera)
            #endif
            self?.lastPayload = payload
        }
    }

    public func resetTracking() {
        engine.resetTracker()
    }
}
