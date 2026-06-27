# ``DocumentOCR``

Recognize text in document images using Vision's `VNRecognizeTextRequest`, with multi-language support and language correction.

## Overview

`DocumentOCR` provides a thin, async-friendly wrapper around `VNRecognizeTextRequest`. Pass JPEG/PNG data or a `CGImage` and receive the full recognized text along with an average confidence score.

```swift
import DocumentOCR

let service = OCRServiceImpl(configuration: .japanese)

// From JPEG data (e.g., captured by DocumentCamera)
let result = try await service.recognizeText(from: jpegData)
print(result.text)
if let confidence = result.confidence {
    print("avg confidence: \(confidence)")
}

// From a CGImage
let result2 = try await service.recognizeText(from: cgImage)
```

Use ``OCRConfiguration/japanese`` for Japanese + English, ``OCRConfiguration/english`` for English-only, or build a custom configuration for other languages.

## Topics

### Configuration

- ``OCRConfiguration``

### Recognition

- ``OCRService``
- ``OCRServiceImpl``

### Results and Errors

- ``OCRResult``
- ``OCRError``
