# ``DocumentDetection``

Detect rectangular documents in camera frames and static images using the Vision framework, with EMA smoothing and stability tracking for auto-capture.

## Overview

`DocumentDetection` processes live `CVPixelBuffer` frames from AVFoundation, applies exponential moving-average (EMA) corner smoothing, and tracks how long a rectangle has been stationary. When the rectangle stays stable for the configured ``DetectionConfiguration/stabilityThreshold``, ``FrameDetectionResult/shouldAutoCapture`` becomes `true`.

```swift
import DocumentDetection

let service = RectangleDetectionServiceImpl(configuration: .default)

// Per-frame call from AVCaptureVideoDataOutputSampleBufferDelegate
let result = service.process(pixelBuffer)
if let corners = result.smoothedCorners {
    // corners use Vision coordinates: bottom-left origin, 0.0–1.0
    print("stability: \(result.stability)")
}
if result.shouldAutoCapture {
    // Trigger capture
}

// Single-shot detection on a CGImage
if let observation = service.detect(in: cgImage) {
    let corrected = PerspectiveCorrection.correct(cgImage: cgImage, observation: observation)
}
```

## Topics

### Configuration

- ``DetectionConfiguration``

### Detection

- ``RectangleDetectionService``
- ``RectangleDetectionServiceImpl``

### Results

- ``FrameDetectionResult``
- ``RectangleCorners``

### Utilities

- ``PerspectiveCorrection``
