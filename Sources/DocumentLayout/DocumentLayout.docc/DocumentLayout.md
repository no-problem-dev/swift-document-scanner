# ``DocumentLayout``

Analyze document layout elements — titles, text blocks, tables, figures, and more — using a bundled YOLOv12n-DocLayNet CoreML model.

## Overview

`DocumentLayout` runs a YOLOv12n model fine-tuned on the DocLayNet dataset (11 element categories). The implementation performs raw tensor inference in Swift, applies confidence filtering, and runs per-class Non-Maximum Suppression (NMS).

```swift
import DocumentLayout

// Initialize with the bundled nano model
let service = try DocumentLayoutServiceImpl()

// Analyze a CGImage (e.g., captured and perspective-corrected by DocumentDetection)
let result = try await service.analyze(cgImage)

// Iterate elements sorted by vertical position (top → bottom)
for element in result.elements {
    print("\(element.category.rawValue): conf=\(element.confidence), box=\(element.boundingBox)")
}

// Convenience accessors
let tables = result.tables
let pictures = result.pictures
let headers = result.elements(ofCategory: .sectionHeader)
```

Use ``LayoutCropper`` to cut individual elements out of the source image for downstream processing such as OCR.

## Topics

### Configuration

- ``LayoutConfiguration``
- ``ModelVariant``

### Layout Service

- ``DocumentLayoutService``
- ``DocumentLayoutServiceImpl``

### Results

- ``LayoutResult``
- ``LayoutElement``

### Utilities

- ``LayoutCropper``

### Errors

- ``LayoutError``
