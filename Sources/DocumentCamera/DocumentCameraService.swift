#if canImport(UIKit)
@preconcurrency import AVFoundation
import CoreImage
import DocumentDetection
import Foundation
import os
import UIKit

// MARK: - Protocol

/// 矩形検出付きドキュメントスキャン用カメラサービス。
public protocol DocumentCameraService: Sendable {
    /// プレビュー表示に使用する AVCaptureSession。
    nonisolated var captureSession: AVCaptureSession { get }

    /// カメラセッションを開始し、検出結果を流す AsyncStream を返す。
    ///
    /// 前のストリームが存在する場合は完了させてから新しいストリームを生成する。
    func startRunning() async -> AsyncStream<FrameDetectionResult>

    /// カメラセッションを停止し、アクティブなストリームを完了させる。
    func stopRunning() async

    /// 矩形検出の安定性追跡状態をリセットする。
    func resetDetectionState() async

    /// カメラのトーチを切り替え、変更後の有効状態を返す。
    ///
    /// - Returns: トーチがオンの場合 `true`、オフの場合 `false`。
    func toggleFlash() async -> Bool

    /// 現在のビデオフレームを JPEG データとしてキャプチャする。
    ///
    /// - Returns: JPEG 画像データ。
    /// - Throws: フレームが利用できない場合は ``CameraError/imageDataNotAvailable``。
    func captureFrame() async throws -> Data
}

// MARK: - Implementation

/// AVCaptureSession と DocumentDetection を使用するデフォルト実装。
public actor DocumentCameraServiceImpl: NSObject, DocumentCameraService {
    // MARK: - Properties

    public nonisolated let captureSession = AVCaptureSession()
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

    /// DocumentCameraServiceImpl を初期化する。
    ///
    /// - Parameter rectangleDetectionService: 外部で構築した矩形検出サービス。`RectangleDetectionServiceImpl` を使用する場合は呼び出し元で生成して渡す。
    /// - Parameter configuration: フォーカス計算（最小被写体距離・ズーム係数）および JPEG 品質などのカメラ設定。省略時はデフォルト値を使用。
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
