# DocumentScanner

iOS向けのドキュメントスキャニング Swift パッケージ

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 特徴

```swift
// カメラでリアルタイム矩形検出
let stream = await cameraService.startRunning()
for await result in stream {
    if result.shouldAutoCapture {
        let imageData = try await cameraService.captureFrame()
    }
}

// OCRでテキスト認識
let ocrResult = try await ocrService.recognizeText(from: imageData)
print(ocrResult.text)

// ドキュメントレイアウト解析（YOLOv12n-DocLayNet）
let layout = try await layoutService.analyze(cgImage)
print(layout.tables) // テーブル要素を取得
```

- **4つの独立モジュール** - DocumentCamera / DocumentDetection / DocumentOCR / DocumentLayout
- **リアルタイム矩形検出** - EMAスムージングによる安定した検出
- **自動キャプチャ** - 安定性追跡による自動撮影トリガー
- **多言語OCR** - 日本語・英語・中国語など多言語テキスト認識
- **AIレイアウト解析** - YOLOv12n-DocLayNetモデルによる11カテゴリの文書要素検出
- **プロトコルベース設計** - テスト容易な依存性注入パターン
- **Swift Concurrency対応** - actor・AsyncStream・Sendableによるスレッドセーフ設計
- **プリセット設定** - 書類・レシート・書籍など用途別の最適化プリセット

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-document-scanner.git", .upToNextMajor(from: "0.3.0"))
]
```

必要なモジュールだけを選択してインポート:

```swift
// 全モジュール
.product(name: "DocumentCamera", package: "swift-document-scanner"),
.product(name: "DocumentDetection", package: "swift-document-scanner"),
.product(name: "DocumentOCR", package: "swift-document-scanner"),
.product(name: "DocumentLayout", package: "swift-document-scanner"),

// または必要なモジュールだけ
.product(name: "DocumentOCR", package: "swift-document-scanner"),
```

または Xcode: File > Add Package Dependencies > URL入力

## モジュール構成

| モジュール | 説明 | 依存 |
|-----------|------|------|
| **DocumentDetection** | 矩形検出・安定性追跡 | Vision |
| **DocumentCamera** | カメラ制御・ライブ検出ストリーム | DocumentDetection, AVFoundation |
| **DocumentOCR** | テキスト認識（多言語） | Vision |
| **DocumentLayout** | AIレイアウト解析（YOLOv12n） | CoreML, Vision |

## 基本的な使い方

### 1. ドキュメント矩形検出

```swift
import DocumentDetection

// 検出サービスを初期化（プリセット設定を使用）
let detectionService = RectangleDetectionServiceImpl(
    configuration: .default
)

// カメラフレームを処理
let result = detectionService.process(pixelBuffer)
if let corners = result.smoothedCorners {
    // corners.topLeft, .topRight, .bottomLeft, .bottomRight
    print("安定度: \(result.stability)")  // 0.0〜1.0
    if result.shouldAutoCapture {
        // 自動キャプチャ条件達成
    }
}

// 静止画像での単発検出
if let observation = detectionService.detect(in: cgImage) {
    print("検出: confidence=\(observation.confidence)")
}
```

#### 検出プリセット

```swift
DetectionConfiguration.default    // 一般的な書類スキャン
DetectionConfiguration.receipt    // レシート（狭い文書）
DetectionConfiguration.bookPage   // 書籍ページ（大きい文書、高速キャプチャ）
DetectionConfiguration.bookSpread // 見開きページ（緩やかな検出）
```

### 2. カメラ + リアルタイム検出

```swift
import DocumentCamera
import DocumentDetection

// サービスを初期化
let detectionService = RectangleDetectionServiceImpl(
    configuration: .default
)
let cameraService = DocumentCameraServiceImpl(
    rectangleDetectionService: detectionService,
    configuration: .a4Document
)

// カメラプレビュー（SwiftUI）
CameraPreviewView(session: cameraService.captureSession)

// カメラ開始 → 検出結果をストリーミング
let stream = await cameraService.startRunning()
for await result in stream {
    if let corners = result.smoothedCorners {
        // オーバーレイを更新
        updateOverlay(corners: corners)
    }
    if result.shouldAutoCapture {
        let imageData = try await cameraService.captureFrame()
        // 撮影完了
    }
}

// カメラ停止
await cameraService.stopRunning()
```

#### カメラプリセット

```swift
CameraConfiguration.receipt     // レシート（100mm幅、80%フィル）
CameraConfiguration.bookPage    // 書籍ページ（200mm幅、90%フィル、高画質）
CameraConfiguration.a4Document  // A4書類（210mm幅、90%フィル）
```

### 3. OCRテキスト認識

```swift
import DocumentOCR

// 日本語+英語のOCRサービス
let ocrService = OCRServiceImpl(
    configuration: .japanese
)

// 画像データからテキスト認識
let result = try await ocrService.recognizeText(from: jpegData)
print(result.text)
print("信頼度: \(result.confidence ?? 0)")

// CGImageからも認識可能
let result2 = try await ocrService.recognizeText(from: cgImage)
```

#### OCRプリセット

```swift
OCRConfiguration.japanese  // 日本語 + 英語、高精度モード
OCRConfiguration.english   // 英語のみ、高精度モード
```

#### カスタム設定

```swift
let config = OCRConfiguration(
    recognitionLanguages: ["zh-Hans", "en-US"],  // 中国語 + 英語
    recognitionLevel: .fast,                      // 高速モード
    usesLanguageCorrection: false                  // 言語補正なし
)
```

### 4. ドキュメントレイアウト解析

```swift
import DocumentLayout

// YOLOv12n-DocLayNetモデルでレイアウト解析
let layoutService = try DocumentLayoutServiceImpl()

let result = try await layoutService.analyze(cgImage)

// 検出されたすべての要素
for element in result.elements {
    print("\(element.category.rawValue): \(element.confidence)")
    print("位置: \(element.boundingBox)")
}

// カテゴリ別フィルタリング
let tables = result.tables      // テーブル要素
let pictures = result.pictures  // 画像要素
let headers = result.elements(ofCategory: .sectionHeader)
```

#### 検出カテゴリ（DocLayNet 11クラス）

| カテゴリ | 説明 |
|---------|------|
| `caption` | キャプション |
| `footnote` | 脚注 |
| `formula` | 数式 |
| `listItem` | リスト項目 |
| `pageFooter` | ページフッター |
| `pageHeader` | ページヘッダー |
| `picture` | 画像・図 |
| `sectionHeader` | セクション見出し |
| `table` | テーブル |
| `text` | テキスト段落 |
| `title` | タイトル |

#### 外部モデルの使用

```swift
// カスタムモデルをコンパイルして使用
let compiledURL = try DocumentLayoutServiceImpl.compileModel(at: modelPackageURL)
let service = try DocumentLayoutServiceImpl(
    compiledModelURL: compiledURL,
    configuration: .init(confidenceThreshold: 0.3, inputSize: 640)
)
```

## アーキテクチャ

```
DocumentCamera ──depends──▶ DocumentDetection
       │                           │
       │ AVCaptureSession          │ Vision framework
       │ AsyncStream               │ EMA smoothing
       ▼                           ▼
  カメラ制御              矩形検出・安定性追跡

DocumentOCR                DocumentLayout
       │                           │
       │ Vision framework          │ CoreML (YOLOv12n)
       │ Multi-language            │ NMS post-processing
       ▼                           ▼
  テキスト認識             レイアウト解析
```

## 要件

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

## 開発者向け情報

- [リリースプロセス](RELEASE_PROCESS.md) - 新バージョンをリリースする手順
- [変更履歴](CHANGELOG.md) - 全バージョンの変更記録

## サポート

- [Issue報告](https://github.com/no-problem-dev/swift-document-scanner/issues)
- [ディスカッション](https://github.com/no-problem-dev/swift-document-scanner/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
