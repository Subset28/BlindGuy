import CoreVideo
import Foundation
import ImageIO

#if os(iOS)
import AVFoundation
import CoreMedia
#endif

/// Wire `AVCaptureSession` → `BlindGuySession.ingest` on iOS. On macOS the type exists for
/// `swift build` but `start()` throws — use a USB camera + Python bridge, or a host app.
public enum CameraPipelineError: Error, Sendable, Equatable {
    case cameraPermissionDenied
    case noSuitableVideoDevice
    case cannotAddInput
    case cannotAddOutput
    case inputCreationFailed
    case unavailableOnThisPlatform
}

#if os(iOS)
/// Pushes BGRA frames from the back camera to `OnDeviceVisionEngine` via `BlindGuySession`.
public final class CameraPipeline: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let vision: BlindGuySession
    private let imageOrientation: CGImagePropertyOrientation
    private let session: AVCaptureSession
    private let sessionQueue: DispatchQueue
    private let bufferQueue: DispatchQueue
    private var configured = false

    @Published public private(set) var isRunning = false

    /// - Parameters:
    ///   - vision: Session that owns the vision engine; receives frames on the main actor.
    ///   - imageOrientation: Vision orientation for the rear camera in portrait. Tune for lanyard / landscape use.
    public init(vision: BlindGuySession, imageOrientation: CGImagePropertyOrientation = .right) {
        self.vision = vision
        self.imageOrientation = imageOrientation
        self.session = AVCaptureSession()
        self.sessionQueue = DispatchQueue(label: "com.blindguy.capture.session", qos: .userInitiated)
        self.bufferQueue = DispatchQueue(label: "com.blindguy.capture.buffer", qos: .userInitiated)
        super.init()
    }

    deinit {
        if session.isRunning {
            session.stopRunning()
        }
    }

    public func start() async throws {
        let ok = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .video) { c.resume(returning: $0) }
        }
        if !ok { throw CameraPipelineError.cameraPermissionDenied }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    if !self.configured {
                        try self.configureSession()
                        self.configured = true
                    }
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    DispatchQueue.main.async { [weak self] in
                        self?.isRunning = self?.session.isRunning ?? false
                    }
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    public func stop() {
        sessionQueue.async { [self] in
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        else {
            session.commitConfiguration()
            throw CameraPipelineError.noSuitableVideoDevice
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            session.commitConfiguration()
            throw CameraPipelineError.inputCreationFailed
        }
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            session.commitConfiguration()
            throw CameraPipelineError.cannotAddInput
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            session.commitConfiguration()
            throw CameraPipelineError.cannotAddOutput
        }

        output.setSampleBufferDelegate(self, queue: bufferQueue)
        session.commitConfiguration()
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let o = imageOrientation
        Task { @MainActor [weak self] in
            self?.vision.ingest(pixelBuffer: pixelBuffer, orientation: o)
        }
    }
}

#else

/// Placeholder: macOS has no in-package camera loop; use the Python service or a host app.
public final class CameraPipeline: ObservableObject {
    @Published public private(set) var isRunning = false

    public init(vision: BlindGuySession, imageOrientation: CGImagePropertyOrientation = .right) {
        _ = (vision, imageOrientation)
    }

    public func start() async throws {
        throw CameraPipelineError.unavailableOnThisPlatform
    }

    public func stop() {
        isRunning = false
    }
}

#endif
