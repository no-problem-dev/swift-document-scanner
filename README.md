English | [日本語](./README.ja.md)

# DocumentScanner

Camera capture, rectangle detection, OCR, and layout analysis for scanning documents on iOS.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

Four modules you can adopt one at a time: point a camera at a page and get a stable outline, take
the shot when it settles, read the text off it, and find out where the tables and figures are.

## Features

- **Live rectangle detection** — Vision-backed, smoothed with an EMA so the outline does not jitter,
  with a stability score you can show the user
- **Auto-capture** — the shutter fires on its own once the outline has held still long enough
- **Multi-language OCR** — Japanese, English, Chinese and whatever else Vision supports on the
  running OS, with per-line geometry kept so column layouts survive
- **AI layout analysis** — a bundled YOLOv12n-DocLayNet CoreML model classifies page elements into
  11 categories, so you can pull out just the tables or just the figures
- **Presets that encode hard-won settings** — receipts turn language correction off and lower the
  minimum text height, because dictionary correction quietly rewrites half-width katakana product
  names into plausible-looking nonsense
- **Protocol-first, actor-isolated** — every service is a protocol with an injectable
  implementation, built on `actor`, `AsyncStream` and `Sendable`

## Quick Start

Stream detection results from the camera and capture when the frame settles:

```swift
import DocumentCamera
import DocumentDetection

let camera = DocumentCameraServiceImpl(
    rectangleDetectionService: RectangleDetectionServiceImpl(configuration: .default),
    configuration: .a4Document
)

for await result in await camera.startRunning() where result.shouldAutoCapture {
    let jpeg = try await camera.captureFrame()
    await camera.stopRunning()
    break
}
```

Then read the page:

```swift
import DocumentOCR

let result = try await OCRServiceImpl(configuration: .japanese).recognizeText(from: jpeg)
print(result.text)
```

Add `NSCameraUsageDescription` to the host app's `Info.plist`; the system terminates the app without
it.

## Documentation

API reference and guides, one site per module:

- [**DocumentCamera**](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentcamera/) —
  capture session, live stream, preview and overlay, plus the
  [module map](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentcamera/architecture/)
  for the package as a whole
- [**DocumentDetection**](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentdetection/) —
  rectangle detection, smoothing, stability, perspective correction
- [**DocumentOCR**](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentocr/) —
  text recognition and what the result does and does not guarantee
- [**DocumentLayout**](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentlayout/) —
  layout analysis, the 11 DocLayNet categories, custom models

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-document-scanner.git", .upToNextMajor(from: "0.5.0"))
]
```

Depend only on the modules you use — they are separate products for that reason:

```swift
.product(name: "DocumentCamera",    package: "swift-document-scanner"),
.product(name: "DocumentDetection", package: "swift-document-scanner"),
.product(name: "DocumentOCR",       package: "swift-document-scanner"),
.product(name: "DocumentLayout",    package: "swift-document-scanner"),
```

Or in Xcode: File > Add Package Dependencies, and enter the URL above.

## Requirements

- iOS 17.0+ / macOS 14.0+ — the capture pipeline in `DocumentCamera` is iOS only; detection, OCR and
  layout analysis run on both
- Swift 6.2+
- Xcode 16.0+

## License

MIT — see [LICENSE](LICENSE).
