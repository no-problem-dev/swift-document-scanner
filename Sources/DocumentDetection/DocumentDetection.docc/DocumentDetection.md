# ``DocumentDetection``

Finds document rectangles in live camera frames and still images, and reports when the frame has been steady long enough to capture.

## Overview

`DocumentDetection` runs Vision's `VNDetectDocumentSegmentationRequest` over a `CVPixelBuffer` or a `CGImage`. Beyond the raw detection it adds the two things a scanning UI needs: corners that are calm enough to draw, and a signal that says "now".

Feed each camera frame to ``RectangleDetectionService/process(_:)``. The service first rejects observations that would make poor scans — those below ``DetectionConfiguration/minimumConfidence``, those covering more of the frame than ``DetectionConfiguration/maximumRectangleAreaRatio``, and those with a corner closer to the edge than ``DetectionConfiguration/minimumEdgeMargin``. A rejected or missing rectangle clears all tracking state.

Surviving observations drive two separate outputs:

- ``FrameDetectionResult/smoothedCorners`` blends the new corners into the previous ones with an exponential moving average, weighted by ``DetectionConfiguration/smoothingFactor``. These are for drawing. A factor of `1.0` disables smoothing entirely.
- ``FrameDetectionResult/stability`` and ``FrameDetectionResult/shouldAutoCapture`` are computed from the *unsmoothed* observations. A frame counts as stable when all four corners moved less than ``DetectionConfiguration/positionThreshold`` from the previous frame. Once ``DetectionConfiguration/minimumStableFrameCount`` consecutive stable frames have accumulated, a timer starts; `stability` is the elapsed time divided by ``DetectionConfiguration/stabilityThreshold``, clamped to `1.0`, and `shouldAutoCapture` turns `true` when the threshold is reached. A single unsteady frame resets the counter and the timer.

Because `stability` only begins to climb after the frame-count gate has been cleared, it stays at `0.0` for the first moments of a fresh detection even while corners are already being drawn.

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

``RectangleDetectionService/detect(in:)`` is stateless and leaves the tracking state alone, so you can run it on a captured still while the live stream keeps going. It returns the Vision observation rather than ``RectangleCorners`` because ``PerspectiveCorrection`` needs the observation: the smoothed corners describe what the user was shown, not what the pixels actually contain.

Presets cover the common paper sizes. ``DetectionConfiguration/default`` and ``DetectionConfiguration/receipt`` are tuned for ordinary handheld scanning, while ``DetectionConfiguration/bookPage`` and ``DetectionConfiguration/bookSpread`` progressively relax the area, margin, and confidence limits so that a page filling nearly the whole frame is still accepted.

### Platform availability

This module is built on Vision and Core Image only — no UIKit, no AVFoundation. Everything it declares is available on both iOS 17 and macOS 14, and every symbol below compiles on both. On macOS you supply the pixel buffers yourself; the capture session in `DocumentCamera` is iOS-only.

## Topics

### Configuring detection

- ``DetectionConfiguration``

### Detecting rectangles

- ``RectangleDetectionService``
- ``RectangleDetectionServiceImpl``

### Reading results

- ``FrameDetectionResult``
- ``RectangleCorners``

### Correcting perspective

- ``PerspectiveCorrection``
