# DocumentScanner

Swift package for iOS document scanning

English | [日本語](./README.ja.md)

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

```swift
// Real-time rectangle detection via camera
let stream = await cameraService.startRunning()
for await result in stream {
    if result.shouldAutoCapture {
        let imageData = try await cameraService.captureFrame()
    }
}

// Text recognition via OCR
let ocrResult = try await ocrService.recognizeText(from: imageData)
print(ocrResult.text)

// Document layout analysis (YOLOv12n-DocLayNet)
let layout = try await layoutService.analyze(cgImage)
print(layout.tables) // retrieve table elements
```

- **4 independent modules** — DocumentCamera / DocumentDetection / DocumentOCR / DocumentLayout
- **Real-time rectangle detection** — stable detection with EMA smoothing
- **Auto-capture** — automatic shutter trigger via stability tracking
- **Multi-language OCR** — Japanese, English, Chinese, and more
- **AI layout analysis** — 11-category document element detection with YOLOv12n-DocLayNet
- **Protocol-based design** — dependency injection for easy testing
- **Swift Concurrency** — thread-safe design using actor, AsyncStream, and Sendable
- **Preset configurations** — optimized presets for documents, receipts, books, and more

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-document-scanner.git", .upToNextMajor(from: "0.3.1"))
]
```

Import only the modules you need:

```swift
// All modules
.product(name: "DocumentCamera", package: "swift-document-scanner"),
.product(name: "DocumentDetection", package: "swift-document-scanner"),
.product(name: "DocumentOCR", package: "swift-document-scanner"),
.product(name: "DocumentLayout", package: "swift-document-scanner"),

// Or just the ones you need
.product(name: "DocumentOCR", package: "swift-document-scanner"),
```

Or in Xcode: File > Add Package Dependencies > enter the URL above.

## Module Overview

| Module | Description | Dependencies |
|--------|-------------|--------------|
| **DocumentDetection** | Rectangle detection and stability tracking | Vision |
| **DocumentCamera** | Camera control and live detection stream | DocumentDetection, AVFoundation |
| **DocumentOCR** | Text recognition (multi-language) | Vision |
| **DocumentLayout** | AI layout analysis (YOLOv12n) | CoreML, Vision |

## Usage

### 1. Document Rectangle Detection

```swift
import DocumentDetection

// Initialize with a preset configuration
let detectionService = RectangleDetectionServiceImpl(
    configuration: .default
)

// Process a camera frame
let result = detectionService.process(pixelBuffer)
if let corners = result.smoothedCorners {
    // corners.topLeft, .topRight, .bottomLeft, .bottomRight
    print("stability: \(result.stability)")  // 0.0–1.0
    if result.shouldAutoCapture {
        // Auto-capture condition met
    }
}

// Single-shot detection on a static image
if let observation = detectionService.detect(in: cgImage) {
    print("detected: confidence=\(observation.confidence)")
}
```

#### Detection Presets

```swift
DetectionConfiguration.default    // General document scanning
DetectionConfiguration.receipt    // Receipt (narrow document)
DetectionConfiguration.bookPage   // Book page (large document, faster capture)
DetectionConfiguration.bookSpread // Book spread (relaxed detection)
```

### 2. Camera + Live Detection

```swift
import DocumentCamera
import DocumentDetection

let detectionService = RectangleDetectionServiceImpl(
    configuration: .default
)
let cameraService = DocumentCameraServiceImpl(
    rectangleDetectionService: detectionService,
    configuration: .a4Document
)

// Camera preview (SwiftUI)
CameraPreviewView(session: cameraService.captureSession)

// Start camera and stream detection results
let stream = await cameraService.startRunning()
for await result in stream {
    if let corners = result.smoothedCorners {
        // Update overlay
        updateOverlay(corners: corners)
    }
    if result.shouldAutoCapture {
        let imageData = try await cameraService.captureFrame()
        // Capture complete
    }
}

// Stop camera
await cameraService.stopRunning()
```

#### Camera Presets

```swift
CameraConfiguration.receipt     // Receipt (100mm width, 80% fill)
CameraConfiguration.bookPage    // Book page (200mm width, 90% fill, high quality)
CameraConfiguration.a4Document  // A4 document (210mm width, 90% fill)
```

### 3. OCR Text Recognition

```swift
import DocumentOCR

// Japanese + English OCR service
let ocrService = OCRServiceImpl(
    configuration: .japanese
)

// Recognize text from image data
let result = try await ocrService.recognizeText(from: jpegData)
print(result.text)
print("confidence: \(result.confidence ?? 0)")

// Also works with CGImage
let result2 = try await ocrService.recognizeText(from: cgImage)
```

#### OCR Presets

```swift
OCRConfiguration.japanese  // Japanese + English, accurate mode
OCRConfiguration.english   // English only, accurate mode
```

#### Custom Configuration

```swift
let config = OCRConfiguration(
    recognitionLanguages: ["zh-Hans", "en-US"],  // Chinese + English
    recognitionLevel: .fast,                      // Fast mode
    usesLanguageCorrection: false                  // No language correction
)
```

### 4. Document Layout Analysis

```swift
import DocumentLayout

// Layout analysis with the YOLOv12n-DocLayNet model
let layoutService = try DocumentLayoutServiceImpl()

let result = try await layoutService.analyze(cgImage)

// All detected elements
for element in result.elements {
    print("\(element.category.rawValue): \(element.confidence)")
    print("position: \(element.boundingBox)")
}

// Filter by category
let tables = result.tables      // Table elements
let pictures = result.pictures  // Image/figure elements
let headers = result.elements(ofCategory: .sectionHeader)
```

#### Detected Categories (DocLayNet 11 Classes)

| Category | Description |
|----------|-------------|
| `caption` | Caption |
| `footnote` | Footnote |
| `formula` | Formula |
| `listItem` | List item |
| `pageFooter` | Page footer |
| `pageHeader` | Page header |
| `picture` | Image / figure |
| `sectionHeader` | Section header |
| `table` | Table |
| `text` | Text paragraph |
| `title` | Title |

#### Using an External Model

```swift
// Compile a custom model and use it
let compiledURL = try DocumentLayoutServiceImpl.compileModel(at: modelPackageURL)
let service = try DocumentLayoutServiceImpl(
    compiledModelURL: compiledURL,
    configuration: .init(confidenceThreshold: 0.3, inputSize: 640)
)
```

## Architecture

```
DocumentCamera ──depends──▶ DocumentDetection
       │                           │
       │ AVCaptureSession          │ Vision framework
       │ AsyncStream               │ EMA smoothing
       ▼                           ▼
  Camera control          Rectangle detection & tracking

DocumentOCR                DocumentLayout
       │                           │
       │ Vision framework          │ CoreML (YOLOv12n)
       │ Multi-language            │ NMS post-processing
       ▼                           ▼
  Text recognition         Layout analysis
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## License

MIT License — see [LICENSE](LICENSE) for details.

## Developer Resources

- [Release Process](RELEASE_PROCESS.md) — how to release a new version
- [Changelog](CHANGELOG.md) — full version history

## Support

- [Issue Tracker](https://github.com/no-problem-dev/swift-document-scanner/issues)
- [Discussions](https://github.com/no-problem-dev/swift-document-scanner/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
