#if canImport(UIKit)
@preconcurrency import AVFoundation
import CoreImage
import DocumentDetection
import Foundation
import os
import UIKit

// MARK: - Protocol

/// Runs the back camera and streams a document detection for every frame it produces.
///
/// **Available only where UIKit is, so not on macOS** — on macOS this module offers only its
/// configuration and error types.
///
/// ## What it does not do
///
/// **Camera authorisation is never requested and never reported.** Starting without permission
/// is silent: the call returns a stream, no frames arrive, nothing is ever yielded, and a capture
/// throws ``CameraError/imageDataNotAvailable``. Ask for access yourself before starting, or a
/// refusal looks exactly like a camera pointed at nothing.
///
/// A device with no back wide-angle camera fails the same silent way — configuration gives up
/// part-way and the session produces nothing.
public protocol DocumentCameraService: Sendable {
    /// The session to hand to the preview view, and the only thing it should be used for.
    ///
    /// **It is meant to cross to the main actor and be attached to `CameraPreviewView`.**
    /// Everything that mutates it — adding inputs and outputs, starting, stopping — happens
    /// inside the service, and letting it out of the isolation is only sound while that stays
    /// true (see the note on the implementation's `nonisolated(unsafe)` property).
    nonisolated var captureSession: AVCaptureSession { get }

    /// Starts the camera and returns a stream carrying one detection per frame.
    ///
    /// Calling it again finishes the previous stream before making a new one, so only the newest
    /// stream ever receives frames. The session is configured on the first call only.
    ///
    /// The stream never fails and never ends by itself; it finishes when the camera is stopped or
    /// when this is called again.
    func startRunning() async -> AsyncStream<FrameDetectionResult>

    /// Stops the camera and finishes the active stream, dropping the last frame it held.
    ///
    /// A capture attempted after this throws until the camera has been started again and a new
    /// frame has arrived.
    func stopRunning() async

    /// Restarts stability tracking without stopping the camera, as you would after a capture.
    ///
    /// Without it, the frames right after a capture still count as the same held-still document
    /// and immediately meet the auto-capture condition again.
    func resetDetectionState() async

    /// Turns the torch on or off and reports the state it now believes it is in.
    ///
    /// - Returns: True when the torch is meant to be on. It is the service's own flag rather than
    ///   the hardware's: it flips even on a device with no torch, and even when the device
    ///   refuses the change.
    func toggleFlash() async -> Bool

    /// Encodes the most recent video frame as JPEG.
    ///
    /// It is the frame the video output last delivered, not a fresh full-resolution still — there
    /// is no photo output in this session, so the size is the session preset's and the quality is
    /// whatever the configuration asked for.
    ///
    /// - Returns: JPEG data for that frame.
    /// - Throws: ``CameraError/imageDataNotAvailable`` when no frame has arrived yet, or when the
    ///   frame could not be rendered or encoded.
    func captureFrame() async throws -> Data
}

// MARK: - Implementation

/// The default service, driving a capture session and detecting on the video output queue.
///
/// Detection runs synchronously inside the video output callback, on a private serial queue, so a
/// slow detector costs frames rather than memory — the output is set to discard late frames. The
/// video connection is pinned to portrait, so the frames detection and capture see do not rotate
/// with the device.
public actor DocumentCameraServiceImpl: NSObject, DocumentCameraService {
    // MARK: - Properties

    /// The live session, held outside the actor's isolation so a view can take it.
    ///
    /// **This exemption from concurrency checking is deliberate.** Apple does not mark
    /// `AVCaptureSession` as `Sendable`, so as a plain `nonisolated let` it cannot leave the
    /// actor, and **consumers fail to build** — the README's
    /// `CameraPreviewView(session: service.captureSession)` is exactly that line.
    ///
    /// It is sound because **every mutation of this session is serialised inside the actor**
    /// (`startRunning`, `stopRunning`, `setupCameraSession` and `configureForScanning` are all
    /// actor-isolated). The reference that escapes is used only to attach an
    /// `AVCaptureVideoPreviewLayer`, which is Apple's own main-thread pattern.
    /// **A consumer that changes the configuration invalidates all of that.**
    ///
    /// With the check switched off, something has to notice when the guarantee breaks:
    /// `CameraSessionHandoffTests` compiles the same hand-off a consumer writes.
    public nonisolated(unsafe) let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "document.camera.videoOutput")

    nonisolated let rectangleDetectionService: any RectangleDetectionService
    private let configuration: CameraConfiguration

    private var isSessionConfigured = false
    private var isFlashOn = false

    // MARK: - Thread-safe State (accessed from videoOutputQueue + actor)

    private let streamContinuation = OSAllocatedUnfairLock<AsyncStream<FrameDetectionResult>.Continuation?>(
        initialState: nil
    )

    /// CVPixelBuffer is non-Sendable; wrap in @unchecked Sendable to use with OSAllocatedUnfairLock.
    private struct PixelBufferBox: @unchecked Sendable {
        var buffer: CVPixelBuffer?
    }

    private let frameBuffer = OSAllocatedUnfairLock(initialState: PixelBufferBox())

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Initialization

    /// Creates a service around a detector you have already built.
    ///
    /// - Parameters:
    ///   - rectangleDetectionService: The detector every frame is fed to. It is injected rather
    ///     than created here so its thresholds and the camera's framing can be chosen together —
    ///     the receipt presets in the two modules are meant to be used as a pair.
    ///   - configuration: The document width and fill percentage the focus distance is worked out
    ///     from, plus the JPEG quality of captures.
    public init(
        rectangleDetectionService: any RectangleDetectionService,
        configuration: CameraConfiguration = CameraConfiguration()
    ) {
        self.rectangleDetectionService = rectangleDetectionService
        self.configuration = configuration
        super.init()
    }

    // MARK: - Session Control

    public func startRunning() -> AsyncStream<FrameDetectionResult> {
        // Finish any previous stream
        streamContinuation.withLock { $0?.finish(); $0 = nil }
        frameBuffer.withLockUnchecked { $0.buffer = nil }

        if !isSessionConfigured {
            setupCameraSession()
        }

        configureForScanning()

        let (stream, continuation) = AsyncStream.makeStream(of: FrameDetectionResult.self)
        streamContinuation.withLock { $0 = continuation }

        captureSession.startRunning()
        return stream
    }

    public func stopRunning() {
        captureSession.stopRunning()
        streamContinuation.withLock { $0?.finish(); $0 = nil }
        frameBuffer.withLockUnchecked { $0.buffer = nil }
    }

    public func resetDetectionState() {
        rectangleDetectionService.reset()
    }

    public func toggleFlash() -> Bool {
        isFlashOn.toggle()

        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else {
            return isFlashOn
        }

        do {
            try device.lockForConfiguration()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Ignore torch configuration failure
        }

        return isFlashOn
    }

    public func captureFrame() async throws -> Data {
        let pixelBuffer: CVPixelBuffer? = frameBuffer.withLockUnchecked { $0.buffer }
        guard let pixelBuffer else {
            throw CameraError.imageDataNotAvailable
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw CameraError.imageDataNotAvailable
        }

        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: configuration.jpegCompressionQuality) else {
            throw CameraError.imageDataNotAvailable
        }

        return jpegData
    }

    // MARK: - Private Methods

    private func setupCameraSession() {
        captureSession.beginConfiguration()

        if captureSession.canSetSessionPreset(.hd4K3840x2160) {
            captureSession.sessionPreset = .hd4K3840x2160
        } else {
            captureSession.sessionPreset = .hd1920x1080
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            captureSession.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            captureSession.commitConfiguration()
            return
        }

        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                connection.videoOrientation = .portrait
            }
        }

        captureSession.commitConfiguration()
        isSessionConfigured = true
    }

    private func configureForScanning() {
        guard let input = captureSession.inputs.first as? AVCaptureDeviceInput else {
            return
        }

        let device = input.device

        do {
            try device.lockForConfiguration()

            device.videoZoomFactor = 1.0

            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }

            let minimumSubjectDistance = calculateMinimumSubjectDistance(
                fieldOfView: device.activeFormat.videoFieldOfView
            )

            let deviceMinimumFocusDistance = Float(device.minimumFocusDistance)
            if minimumSubjectDistance < deviceMinimumFocusDistance, deviceMinimumFocusDistance > 0 {
                let zoomFactor = deviceMinimumFocusDistance / minimumSubjectDistance
                let clampedZoomFactor = min(CGFloat(zoomFactor), device.maxAvailableVideoZoomFactor)
                device.videoZoomFactor = clampedZoomFactor
            }

            device.unlockForConfiguration()
        } catch {
            // Ignore focus configuration failure
        }
    }

    /// Calculate minimum subject distance using WWDC21 approach.
    private func calculateMinimumSubjectDistance(fieldOfView: Float) -> Float {
        let radians = fieldOfView / 2.0 * .pi / 180.0
        let filledSize = configuration.minimumDocumentWidth / configuration.previewFillPercentage
        return filledSize / tan(radians)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension DocumentCameraServiceImpl: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let frameResult = rectangleDetectionService.process(pixelBuffer)
        frameBuffer.withLockUnchecked { $0.buffer = pixelBuffer }
        _ = streamContinuation.withLock { $0?.yield(frameResult) }
    }
}
#endif
