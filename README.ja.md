[English](./README.md) | 日本語

# DocumentScanner

iOS で書類をスキャンするための、カメラ撮影・矩形検出・OCR・レイアウト解析。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

必要なものだけを 1 つずつ採用できる 4 モジュール構成です。紙にカメラを向けると安定した枠が出て、
落ち着いたところで自動的に撮り、そこから文字を読み、表や図がどこにあるかを取り出せます。

## 特徴

- **リアルタイム矩形検出** — Vision ベース。EMA で平滑化するので枠が震えず、安定度を数値で
  ユーザーに見せられます
- **自動キャプチャ** — 枠が十分に止まったところでシャッターが自分で切れます
- **多言語 OCR** — 日本語・英語・中国語ほか、動作中の OS の Vision が対応する言語。
  かたまりごとの位置を残すので、列のある紙面でも対応付けができます
- **AI レイアウト解析** — 同梱の YOLOv12n-DocLayNet CoreML モデルが紙面の要素を 11 カテゴリに
  分類するので、表だけ・図だけを取り出せます
- **踏んだ地雷が入っているプリセット** — レシート用は言語補正を切り、最小文字高を下げます。
  辞書補正は半角カナの品名を「それらしい別の言葉」に静かに書き換えてしまうためです
- **プロトコル優先・actor 分離** — 各サービスはプロトコル + 差し替え可能な実装で、
  `actor`・`AsyncStream`・`Sendable` の上に載っています

## クイックスタート

カメラの検出結果を流し、枠が落ち着いたら撮ります。

```swift
import DocumentCamera
import DocumentDetection

let camera = DocumentCameraServiceImpl(
    rectangleDetectionService: RectangleDetectionServiceImpl(configuration: .default),
    configuration: .a4Document
)

for await result in await camera.startRunning() where result.shouldAutoCapture {
    let jpeg = try await camera.captureFrame()
    await camera.stopRunning()
    break
}
```

撮ったものを読みます。

```swift
import DocumentOCR

let result = try await OCRServiceImpl(configuration: .japanese).recognizeText(from: jpeg)
print(result.text)
```

ホストアプリの `Info.plist` に `NSCameraUsageDescription` が要ります。無いとシステムがアプリを終了させます。

## ドキュメント

API リファレンスとガイド（モジュールごとに 1 サイト）:

- [**DocumentCamera**](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentcamera/) —
  キャプチャセッション・ライブストリーム・プレビューとオーバーレイ。
  パッケージ全体の[モジュール地図](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentcamera/architecture/)もここにあります
- [**DocumentDetection**](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentdetection/) —
  矩形検出・平滑化・安定性・射影変換
- [**DocumentOCR**](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentocr/) —
  テキスト認識と、結果が保証すること・しないこと
- [**DocumentLayout**](https://no-problem-dev.github.io/swift-document-scanner/documentation/documentlayout/) —
  レイアウト解析・DocLayNet の 11 カテゴリ・外部モデル

## 導入

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-document-scanner.git", .upToNextMinor(from: "0.5.0"))
]
```

使うモジュールだけに依存してください。product を分けてあるのはそのためです。

```swift
.product(name: "DocumentCamera",    package: "swift-document-scanner"),
.product(name: "DocumentDetection", package: "swift-document-scanner"),
.product(name: "DocumentOCR",       package: "swift-document-scanner"),
.product(name: "DocumentLayout",    package: "swift-document-scanner"),
```

Xcode からは File > Add Package Dependencies に上記 URL を入力します。

## 動作環境

- iOS 17.0+ / macOS 14.0+ — `DocumentCamera` のキャプチャ部分は iOS 専用です。
  検出・OCR・レイアウト解析は両方で動きます
- Swift 6.2+
- Xcode 16.0+

## ライセンス

MIT — [LICENSE](LICENSE) を参照してください。
