#if canImport(UIKit)
@preconcurrency import AVFoundation
import CoreImage
import DocumentDetection
import Foundation
import UIKit

// MARK: - Protocol

/// Camera service for document scanning with live rectangle detection.
public protocol DocumentCameraService: Sendable {
    /// The underlying capture session for preview display.
    nonisolated var captureSession: AVCaptureSession { get }

    /// Async stream of detection results from each camera frame.
    var detectionResults: AsyncStream<FrameDetectionResult> { get async }

    func startRunning() async
    func stopRunning() async

    /// Reset the rectangle detection stability tracking state.
    func resetDetectionState() async

    func toggleFlash() async -> Bool

    /// Capture the current video frame as JPEG data.
    func captureFrame() async throws -> Data
}

// MARK: - Implementation

/// Default camera implementation using AVCaptureSession + DocumentDetection.
public actor DocumentCameraServiceImpl: NSObject, DocumentCameraService {
    // MARK: - Properties

    public nonisolated let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "document.camera.videoOutput")

    nonisolated let rectangleDetectionService: any RectangleDetectionService
    private let configuration: CameraConfiguration

    private var isSessionConfigured = false
    private var isFlashOn = false

    // MARK: - Frame Capture

    nonisolated(unsafe) private var latestPixelBuffer: CVPixelBuffer?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - AsyncStream

    private let detectionStream: AsyncStream<FrameDetectionResult>
    nonisolated let detectionContinuation: AsyncStream<FrameDetectionResult>.Continuation

    // MARK: - Initialization

    public init(
        rectangleDetectionService: any RectangleDetectionService,
        configuration: CameraConfiguration = CameraConfiguration()
    ) {
        self.rectangleDetectionService = rectangleDetectionService
        self.configuration = configuration

        (detectionStream, detectionContinuation) = AsyncStream.makeStream(
            of: FrameDetectionResult.self
        )

        super.init()
    }

    // MARK: - Public Interface

    public var detectionResults: AsyncStream<FrameDetectionResult> {
        detectionStream
    }

    // MARK: - Session Control

    public func startRunning() {
        if !isSessionConfigured {
            setupCameraSession()
        }

        configureForScanning()

        captureSession.startRunning()
    }

    public func stopRunning() {
        captureSession.stopRunning()
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
        guard let pixelBuffer = latestPixelBuffer else {
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

        latestPixelBuffer = pixelBuffer
        detectionContinuation.yield(frameResult)
    }
}
#endif
