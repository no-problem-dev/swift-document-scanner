# ``DocumentCamera``

Control an AVCaptureSession for document scanning, streaming live ``FrameDetectionResult`` values as an `AsyncStream` and capturing JPEG frames on demand.

## Overview

`DocumentCamera` wraps AVFoundation session management and integrates with `DocumentDetection` to deliver a ready-to-use camera pipeline. Set up the preview with ``CameraPreviewView`` and start the detection stream with ``DocumentCameraService/startRunning()``.

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

### Configuration

- ``CameraConfiguration``

### Camera Service

- ``DocumentCameraService``
- ``DocumentCameraServiceImpl``

### Errors

- ``CameraError``

### SwiftUI Views

- ``CameraPreviewView``
- ``RectangleOverlayView``
