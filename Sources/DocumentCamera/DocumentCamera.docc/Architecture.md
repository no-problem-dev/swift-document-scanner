# Architecture

How the four products relate, what each one costs you in dependencies, and the internal target
they quietly share.

## Overview

The package ships four independent products. Only one pair depends on the other, so a target that
just wants to read text off a photograph never links AVFoundation, and a target that just wants a
live outline never links CoreML.

| Product | What it does | Frameworks | Depends on |
|---|---|---|---|
| `DocumentDetection` | Finds a rectangular page in a frame or a still, smooths the corners, tracks stability | Vision | — |
| `DocumentCamera` | Drives an `AVCaptureSession`, streams detection results, captures JPEG | AVFoundation, UIKit | `DocumentDetection` |
| `DocumentOCR` | Recognises text and returns it per cluster with geometry | Vision, ImageIO | `DocumentImaging` |
| `DocumentLayout` | Classifies page elements with a bundled CoreML model | CoreML, Vision | `DocumentImaging` |

`DocumentCamera` is the only composition: it takes a `RectangleDetectionService` as an argument
rather than constructing one, so the camera preset and the detection preset are chosen
independently.

`DocumentOCR` and `DocumentLayout` do not depend on each other or on detection. Running OCR over a
still image needs nothing from the camera, which is what makes the package usable from a share
extension or a batch job.

## The shared target you cannot import

`DocumentImaging` is a target but deliberately **not** a product. It decodes image data once and
carries the EXIF orientation alongside the pixels, and both `DocumentOCR` and `DocumentLayout` go
through it.

It exists because getting orientation wrong fails silently: a camera stores an upright sensor image
plus an orientation tag, and code that ignores the tag hands Vision a sideways page that still
recognises *something*. Duplicating that handling in two modules would eventually leave one copy
fixed and the other not. Keeping it in one internal target makes the two paths incapable of
disagreeing — and keeping it out of the product list means it is a guarantee, not API.

## Platform reach

The package declares iOS 17 and macOS 14, but the reach is not uniform.

**`DocumentCamera`'s capture pipeline is iOS only.** `DocumentCameraService`,
`DocumentCameraServiceImpl`, ``CameraPreviewView`` and ``RectangleOverlayView`` compile only where
UIKit is available, which means iOS and Mac Catalyst. On macOS the module builds down to
``CameraConfiguration`` and ``CameraError`` alone — no camera, no preview, no overlay.

`DocumentDetection`, `DocumentOCR` and `DocumentLayout` are fully available on both. A macOS client
supplies its own capture source and feeds frames to `DocumentDetection` directly.

## Concurrency

Each service is a protocol with an injectable implementation, so a use case can be tested against a
stub without a camera or a model.

`DocumentCameraServiceImpl` is an `actor`; the capture session and the retained frame live behind
it, and live detection results reach the caller as an `AsyncStream`. The other services do their
work in `async` calls and hand back `Sendable` value types, so results cross task boundaries
without copying rules to remember.

## Model resources

`DocumentLayout` processes a `Resources` directory into its bundle, which is where the
YOLOv12n-DocLayNet model lives. That is the only product carrying a binary asset, and the reason it
is the largest of the four. A custom model can be compiled and injected instead, so an app that
needs a different label set does not pay for the bundled one twice.
