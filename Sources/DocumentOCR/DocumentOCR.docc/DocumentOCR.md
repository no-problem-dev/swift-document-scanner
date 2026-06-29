# ``DocumentOCR``

Vision の `VNRecognizeTextRequest` を使用して書類画像からテキストを認識し、多言語サポートと言語補正を提供する。

## Overview

`DocumentOCR` は `VNRecognizeTextRequest` に対する薄い非同期ラッパーを提供する。JPEG/PNG データまたは `CGImage` を渡すと、認識されたテキスト全文と平均信頼度スコアを返す。

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

日本語 + 英語は ``OCRConfiguration/japanese``、英語のみは ``OCRConfiguration/english``、その他の言語はカスタム設定を使う。

## Topics

### 設定

- ``OCRConfiguration``

### テキスト認識

- ``OCRService``
- ``OCRServiceImpl``

### 結果とエラー

- ``OCRResult``
- ``OCRError``
