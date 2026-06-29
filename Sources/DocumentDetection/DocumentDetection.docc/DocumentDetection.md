# ``DocumentDetection``

Vision フレームワークを使用してカメラフレームおよび静止画像から矩形書類を検出し、EMA スムージングと安定性追跡による自動キャプチャをサポートする。

## Overview

`DocumentDetection` は AVFoundation からのライブ `CVPixelBuffer` フレームを処理し、指数移動平均（EMA）によるコーナースムージングを適用し、矩形の静止時間を追跡する。矩形が設定した ``DetectionConfiguration/stabilityThreshold`` の間安定すると、``FrameDetectionResult/shouldAutoCapture`` が `true` になる。

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

## Topics

### 設定

- ``DetectionConfiguration``

### 検出

- ``RectangleDetectionService``
- ``RectangleDetectionServiceImpl``

### 結果

- ``FrameDetectionResult``
- ``RectangleCorners``

### ユーティリティ

- ``PerspectiveCorrection``
