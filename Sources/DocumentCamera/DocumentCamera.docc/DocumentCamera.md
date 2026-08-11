# ``DocumentCamera``

Drives an AVFoundation capture session for document scanning, streaming live detection results and capturing frames as JPEG data.

## Overview

`DocumentCamera` wires an `AVCaptureSession` to `DocumentDetection` so you do not have to. It configures the back wide-angle camera, forwards every video frame to a rectangle detector, publishes each ``FrameDetectionResult`` as an `AsyncStream`, and hands back JPEG data for the frame you decide to keep.

``DocumentCameraServiceImpl`` is an actor. It takes the detector as an argument rather than creating one, so the detection preset and the camera preset are chosen independently — ``CameraConfiguration/a4Document`` paired with `DetectionConfiguration.default`, for example, or ``CameraConfiguration/receipt`` with `DetectionConfiguration.receipt`.

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

``DocumentCameraService/startRunning()`` finishes any stream it handed out earlier before creating a new one, so calling it twice cannot leave a stale consumer attached. ``DocumentCameraService/stopRunning()`` stops the session, finishes the stream, and drops the retained frame.

The session prefers a 4K preset and falls back to 1080p, and pins the video connection to portrait. On each start, the service also focuses for close work: it restricts autofocus to the near range and, when the document would have to sit closer than the lens can focus, zooms in far enough to compensate. That calculation is what ``CameraConfiguration/minimumDocumentWidth`` and ``CameraConfiguration/previewFillPercentage`` describe — the physical width of the paper in millimetres and how much of the preview it should fill.

``DocumentCameraService/captureFrame()`` encodes the most recent video frame at ``CameraConfiguration/jpegCompressionQuality``. There is no separate photo output: the JPEG comes from the same video stream the detector reads, at whatever resolution the session preset settled on. If no frame has arrived yet, it throws ``CameraError/imageDataNotAvailable``.

``CameraPreviewView`` puts the session on screen and ``RectangleOverlayView`` draws the detected outline over it, turning the stroke green and thickening it once stability reaches `1.0`, with a per-corner progress ring while it climbs. The overlay converts Vision's bottom-left origin to SwiftUI's top-left for you.

The host app must declare `NSCameraUsageDescription` in its `Info.plist`; without it the system terminates the app when the session opens the device.

### Platform availability

**The capture pipeline is iOS only.** ``DocumentCameraService``, ``DocumentCameraServiceImpl``, ``CameraPreviewView``, and ``RectangleOverlayView`` are compiled only where UIKit is available, which means iOS and Mac Catalyst.

The package declares macOS 14 support, but on macOS this module builds down to just ``CameraConfiguration`` and ``CameraError`` — there is no camera, no preview, and no overlay. A macOS client should use `DocumentDetection` directly with its own capture source; `DocumentDetection`, `DocumentOCR`, and `DocumentLayout` are fully available there.

## Topics

### Essentials

- <doc:Architecture>

### Configuring the camera

- ``CameraConfiguration``

### Capturing documents

- ``DocumentCameraService``
- ``DocumentCameraServiceImpl``

### Presenting the camera

- ``CameraPreviewView``
- ``RectangleOverlayView``

### Handling errors

- ``CameraError``
