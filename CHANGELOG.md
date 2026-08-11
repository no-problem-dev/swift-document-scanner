# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

None

## [0.5.1] - 2026-07-29

### Fixed
- **`captureSession` could not be handed to a view (the consumer's build failed)** - A non-Sendable
  `AVCaptureSession` held in a `nonisolated let` cannot leave its isolation under Swift 6 concurrency
  checking, so the README's usage example `CameraPreviewView(session: service.captureSession)` failed
  exactly as written, with `non-Sendable type 'AVCaptureSession' ... cannot exit nonisolated context`.
  It is now `nonisolated(unsafe)`, and the grounds for calling that safe (every configuration change
  is serialized inside the actor; the reference that escapes is only mounted on the preview) are
  stated on the type itself

### Added
- **`CameraSessionHandoffTests`** - A regression test that compiles the same hand-off a consumer writes
- **An iOS job in CI** - `DocumentCamera` is wrapped entirely in `#if canImport(UIKit)`, so
  **not one line of it was being compiled by `swift test` on macOS**.
  This ends the state where the module was never built in CI at all

## [0.5.0] - 2026-07-29

### Added
- **`OCRLine`** - A type that represents each recognized chunk on its own, with its text, confidence, and position (Vision's normalized coordinates)
- **`OCRResult.lines`** - An array of the above. `init(lines:)` derives `text` and `confidence` from it, so the three cannot disagree
- **`OCRConfiguration.receipt`** preset - Japanese + English, accurate recognition, **no language correction**, and a `minimumTextHeight` for small print
- **`OCRConfiguration.minimumTextHeight`** - The minimum height of text to recognize. `nil` uses Vision's default
- **`DocumentImaging`** (an internal target, not a product) and `DecodedImage` - Opens image data and carries the EXIF orientation as a value

### Fixed
- **Image orientation is now read** - `CIImage(data:)` does not look at EXIF orientation, so there was a path
  where a photo taken with the camera reached Vision still lying on its side. It is now opened with ImageIO,
  its orientation read and passed to `VNImageRequestHandler` (the pixels are not rotated). On receipts, where the
  orientation of the text decides the outcome, this was a straight recognition failure
- **The duplicate `createCGImage(from:)` is resolved** - DocumentOCR and DocumentLayout each held the same
  implementation, so adding orientation handling would have been an accident where only one of them got fixed.
  Both now go through `DocumentImaging`

### Changed (breaking)
- The CGImage overload of `OCRService.recognizeText(from:)` now takes `orientation:`.
  Existing calls (`recognizeText(from: cgImage)`) still compile via the protocol extension's default (`.up`), but
  **anyone implementing `OCRService` themselves has to follow**
- `OCRResult` gained a property. The existing `init(text:confidence:)` still compiles, using the default value for `lines`

## [0.4.0] - 2026-07-19

### Fixed
- **`maximumDetections` was not being applied** - The configured value was not reflected when narrowing the detection results

### Changed
- DocC is now generated as unified documentation across all libraries, with a landing page and a root redirect for GitHub Pages
- Doc comments and DocC were rewritten in Japanese, and the README was standardized as an English/Japanese pair
- CI workflows were synced to the SSOT templates (tests + release-on-tag; the old auto-release was removed)

### Added
- README, CHANGELOG, release procedure, and CI/CD workflows

## [0.3.1] - 2026-02-21

### Fixed
- **Debug output removed** - The debug `print` statements were taken out of the DocumentLayout module

## [0.3.0] - 2026-02-21

### Changed
- **Upgraded to the YOLOv12n model** - Moved from YOLOv8n to YOLOv12n-DocLayNet, improving detection accuracy
- **Reworked the YOLO output parser** - Replaced Vision `VNCoreMLRequest`-based detection with direct parsing of the raw YOLO tensor plus NMS post-processing

### Added
- **Multi-model support** - Added an initializer that loads an externally compiled model
- **Model compilation API** - `compileModel(at:)` compiles an mlpackage at runtime

## [0.2.0] - 2026-02-21

### Added
- **The DocumentLayout module** - Document layout analysis using the YOLOv8n-DocLayNet model
  - Detection of 11 categories of document element (text, table, picture, title, and so on)
  - On-device inference with CoreML
  - The `LayoutElement`, `LayoutResult`, and `LayoutConfiguration` types

## [0.1.0] - 2026-02-21

### Added
- **The DocumentDetection module** - Document rectangle detection with the Vision framework
  - Stable corner tracking with EMA smoothing
  - Stability tracking for automatic capture
  - Presets per use case (default, receipt, bookPage, bookSpread)
- **The DocumentCamera module** - Camera control built on AVCaptureSession
  - Real-time streaming of detection results via AsyncStream
  - Flash control and frame capture
  - WWDC21-style autofocus distance calculation
  - Camera presets (receipt, bookPage, a4Document)
- **The DocumentOCR module** - Text recognition with the Vision framework
  - Multi-language support (Japanese, English, Chinese, and others)
  - An accuracy/speed trade-off setting
  - A language-correction option
  - Presets (japanese, english)
- **SwiftUI support** - CameraPreviewView, RectangleOverlayView

[Unreleased]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/no-problem-dev/swift-document-scanner/compare/0.4.0...v0.5.0
[0.4.0]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.3.1...0.4.0
[0.3.1]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/no-problem-dev/swift-document-scanner/releases/tag/v0.1.0
