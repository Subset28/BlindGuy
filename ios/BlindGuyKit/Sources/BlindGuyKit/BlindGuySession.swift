import Combine
import CoreVideo
import ImageIO

/// SwiftUI-friendly wrapper: publish the latest `FramePayload` on the main actor.
@MainActor
public final class BlindGuySession: ObservableObject {
    @Published public private(set) var lastPayload: FramePayload?
    /// Safe to use from the camera buffer queue; vision work is off the main actor inside `OnDeviceVisionEngine`.
    public nonisolated let engine: OnDeviceVisionEngine
    #if os(iOS)
    public let lensAnnouncer: LensWarningAnnouncer?
    #endif

    public init(
        engine: OnDeviceVisionEngine,
        enableLensSpeech: Bool = false
    ) {
        self.engine = engine
        #if os(iOS)
        self.lensAnnouncer = enableLensSpeech ? LensWarningAnnouncer() : nil
        #endif
    }

    /// Called from the camera `AVCapture` buffer queue. Does not hop through `MainActor` (previous design scheduled every frame on main and caused UI hitches).
    nonisolated public func ingest(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) {
        engine.process(pixelBuffer: pixelBuffer, orientation: orientation) { [weak self] payload in
            guard let self, let payload else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                #if os(iOS)
                self.lensAnnouncer?.announceIfNeeded(camera: payload.camera)
                #endif
                self.lastPayload = payload
            }
        }
    }

    public func resetTracking() {
        engine.resetTracker()
    }

    public func clearPayload() {
        lastPayload = nil
    }
}
