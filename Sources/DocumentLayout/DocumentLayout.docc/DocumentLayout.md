# ``DocumentLayout``

バンドル済みの YOLOv12n-DocLayNet CoreML モデルを使用して、タイトル・テキストブロック・テーブル・図など書類レイアウト要素を解析する。

## Overview

`DocumentLayout` は DocLayNet データセット（11 要素カテゴリ）でファインチューニングした YOLOv12n モデルを実行する。Swift 側でテンソル推論・信頼度フィルタリング・クラス別 NMS 後処理を行う。

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

``LayoutCropper`` を使って個々の要素をソース画像から切り抜き、OCR などの下流処理に渡す。

## Topics

### 設定

- ``LayoutConfiguration``
- ``ModelVariant``

### レイアウトサービス

- ``DocumentLayoutService``
- ``DocumentLayoutServiceImpl``

### 結果

- ``LayoutResult``
- ``LayoutElement``

### ユーティリティ

- ``LayoutCropper``

### エラー

- ``LayoutError``
