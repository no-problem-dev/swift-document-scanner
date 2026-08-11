# ``DocumentOCR``

Recognizes text in document images and returns each block with its position and confidence, alongside the joined full text.

## Overview

`DocumentOCR` is an async wrapper around Vision's `VNRecognizeTextRequest`. Give it JPEG, PNG, or HEIC data, or a `CGImage`, and it returns an ``OCRResult``.

The result is not just a string. Vision reports one observation per layout cluster, and on a receipt the item name and its price are two separate clusters sitting side by side. Flattening everything into one newline-joined string throws away both the pairing and the ordering — observations do not arrive in reading order. So ``OCRResult/lines`` keeps every cluster as an ``OCRLine`` carrying its text, its confidence, and its bounding box in Vision's normalized coordinates, and leaves the column matching to you. ``OCRResult/text`` and ``OCRResult/confidence`` are derived from those lines, so the three can never disagree.

```swift
import DocumentOCR

let service = OCRServiceImpl(configuration: .japanese)

// From JPEG data (e.g., captured by DocumentCamera)
let result = try await service.recognizeText(from: jpegData)
print(result.text)
if let confidence = result.confidence {
    print("avg confidence: \(confidence)")
}

// Keep the geometry when the layout matters
for line in result.lines {
    print("\(line.text) @ \(line.boundingBox) (\(line.confidence))")
}

// From a CGImage whose orientation you already know
let result2 = try await service.recognizeText(from: cgImage, orientation: .right)
```

When you pass `Data`, the service reads the EXIF orientation and forwards it to Vision instead of rotating the pixels — cameras store an upright sensor image plus an orientation tag, and ignoring the tag hands Vision a sideways page. When you pass a `CGImage`, supply the orientation yourself through ``OCRService/recognizeText(from:orientation:)``; the single-argument convenience overload assumes `.up`.

### Choosing a configuration

``OCRConfiguration/japanese`` recognizes Japanese and English, ``OCRConfiguration/english`` only English; both use the accurate recognition level with language correction on. For anything else, build an ``OCRConfiguration`` with the language codes you need.

``OCRConfiguration/receipt`` is deliberately different, and worth understanding before you reuse the other presets on small print. It turns ``OCRConfiguration/usesLanguageCorrection`` off and lowers ``OCRConfiguration/minimumTextHeight`` to `0.008`. Language correction pulls recognized strings toward dictionary words, which helps prose and actively harms anything that is written correctly but is not a word — half-width katakana abbreviations on a receipt, part numbers, SKUs. And Vision's default minimum text height is sized for documents, so thermal-printer output falls below it and whole lines vanish.

### Platform availability

This module uses Vision and ImageIO only, with no UIKit or AVFoundation. Every symbol below is available on both iOS 17 and macOS 14. Recognition-language support is determined by Vision on the running OS, not by this package.

## Topics

### Configuring recognition

- ``OCRConfiguration``

### Recognizing text

- ``OCRService``
- ``OCRServiceImpl``

### Reading results

- ``OCRResult``
- ``OCRLine``

### Handling errors

- ``OCRError``
