# ``DocumentLayout``

Finds the structural elements of a document page — titles, text blocks, tables, and figures — using a bundled on-device model.

## Overview

`DocumentLayout` runs a YOLOv12n model fine-tuned on DocLayNet, whose eleven categories are exposed as ``LayoutElement/Category``. The model ships inside the package as a Core ML package of roughly 6 MB, so ``DocumentLayoutServiceImpl/init(configuration:)`` needs no download and no network.

The model emits a raw prediction tensor with no post-processing baked in, so this module does the rest in Swift: it decodes the tensor, drops boxes below ``LayoutConfiguration/confidenceThreshold``, applies per-class non-maximum suppression at an IoU of 0.45, and then keeps the ``LayoutConfiguration/maximumDetections`` highest-confidence survivors. Suppression is per class on purpose — a caption sitting inside a figure's box is a correct result, not a duplicate.

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

``LayoutResult`` sorts its elements top to bottom on construction, which is reading order for most single-column pages but not for multi-column ones — use the bounding boxes if column order matters. Those boxes are normalized to `0.0–1.0` with a **top-left origin**, matching Core Graphics image space rather than the bottom-left Vision coordinates used by `DocumentDetection`. Feed them straight to ``LayoutCropper`` to cut individual elements out of the source image for downstream work such as OCR.

The image is resized to ``LayoutConfiguration/inputSize`` (640×640) before inference, so aspect ratio is not preserved during detection; boxes are mapped back to normalized coordinates afterwards. ``LayoutConfiguration/bookPage`` raises the confidence threshold to suppress the false positives that dense book pages tend to produce.

### Using a larger model

``ModelVariant`` catalogs the four published sizes with their approximate footprints and DocLayNet mAP scores. It is a reference table, not a switch: nothing in this module selects a model from it, and ``LayoutConfiguration`` has no variant field. Only ``ModelVariant/nano`` is bundled. To run a larger one, obtain the `.mlpackage` yourself, pass it through ``DocumentLayoutServiceImpl/compileModel(at:)``, and hand the resulting URL to ``DocumentLayoutServiceImpl/init(compiledModelURL:configuration:)``.

### Platform availability

Detection is built on Core ML and Core Graphics and runs on both iOS 17 and macOS 14. The one exception is ``LayoutCropper/cropToPNG(from:boundingBox:padding:)``, which encodes through UIKit and therefore exists only on iOS and Mac Catalyst. On macOS, use ``LayoutCropper/crop(from:boundingBox:padding:)`` and encode the returned `CGImage` yourself.

## Topics

### Configuring analysis

- ``LayoutConfiguration``

### Analyzing layout

- ``DocumentLayoutService``
- ``DocumentLayoutServiceImpl``

### Reading results

- ``LayoutResult``
- ``LayoutElement``

### Cropping elements

- ``LayoutCropper``

### Choosing a model

- ``ModelVariant``

### Handling errors

- ``LayoutError``
