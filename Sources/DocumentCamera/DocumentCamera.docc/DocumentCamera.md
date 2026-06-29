# ``DocumentCamera``

`AVCaptureSession` を制御して書類スキャンを行い、ライブの ``FrameDetectionResult`` を `AsyncStream` として配信し、フレームをオンデマンドで JPEG キャプチャする。

## Overview

`DocumentCamera` は AVFoundation のセッション管理をラップし、`DocumentDetection` と統合してすぐに使えるカメラパイプラインを提供する。``CameraPreviewView`` でプレビューを表示し、``DocumentCameraService/startRunning()`` で検出ストリームを開始する。

```swift
import DocumentCamera
import DocumentDetection

let detection = RectangleDetectionServiceImpl(configuration: .default)
let camera = DocumentCameraServiceImpl(
    rectangleDetectionService: detection,
    configuration: .a4Document
)

// SwiftUI preview
CameraPreviewView(session: camera.captureSession)

// Start streaming
let stream = await camera.startRunning()
for await result in stream {
    if result.shouldAutoCapture {
        let jpeg = try await camera.captureFrame()
        await camera.stopRunning()
        break
    }
}
```

## Topics

### 設定

- ``CameraConfiguration``

### カメラサービス

- ``DocumentCameraService``
- ``DocumentCameraServiceImpl``

### エラー

- ``CameraError``

### SwiftUI ビュー

- ``CameraPreviewView``
- ``RectangleOverlayView``
