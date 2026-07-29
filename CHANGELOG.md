# 変更履歴

このプロジェクトの全ての重要な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/lang/ja/spec/v2.0.0.html) に準拠しています。

## [未リリース]

### 追加
- **`OCRLine`** - 認識できたかたまりを、テキスト・信頼度・位置（Vision の正規化座標）で 1 件ずつ表す型
- **`OCRResult.lines`** - 上記の配列。`init(lines:)` から `text` と `confidence` を導出するので 3 つが食い違わない
- **`OCRConfiguration.receipt`** プリセット - 日本語 + 英語・高精度・**言語補正なし**・小さい印字向けの `minimumTextHeight`
- **`OCRConfiguration.minimumTextHeight`** - 認識対象とする文字の最小の高さ。`nil` なら Vision の既定値
- **`DocumentImaging`**（内部ターゲット・product ではない）と `DecodedImage` - 画像データを開き、EXIF の向きを値として持つ

### 修正
- **画像の向きを読むようにした** - `CIImage(data:)` は EXIF の向きを見ないため、カメラで撮った写真が
  横倒しのまま Vision にかかる経路があった。ImageIO で開いて向きを読み、`VNImageRequestHandler` に渡す
  （画素は回さない）。文字の向きが結果を左右するレシートでは、これがそのまま読み取り失敗になっていた
- **`createCGImage(from:)` の重複を解消** - DocumentOCR と DocumentLayout に同じ実装が 2 つあり、
  向きの対応を入れると片方だけ直る事故になるため、`DocumentImaging` に寄せた

### 変更（破壊的）
- `OCRService.recognizeText(from:)` の CGImage 版が `orientation:` を取るようになった。
  既存の呼び出し（`recognizeText(from: cgImage)`）はプロトコル拡張の既定実装（`.up`）で通るが、
  **`OCRService` を自前で実装している場合は追従が要る**
- `OCRResult` にプロパティが増えた。既存の `init(text:confidence:)` は `lines` の既定値で通る

## [0.4.0] - 2026-07-19

### 修正
- **`maximumDetections` が適用されていなかった** - 設定値が検出結果の絞り込みに反映されていなかった

### 変更
- DocC を全 library の統合ドキュメントとして生成するように変更、ランディングと GitHub Pages のルートリダイレクトを追加
- doc コメント・DocC を日本語へリライトし、README を英日の二本立てに統一
- CI ワークフローを SSOT テンプレートへ同期（tests + release-on-tag、旧 auto-release を撤去）

### 追加
- README / CHANGELOG / リリース手順 / CI・CD ワークフロー

## [0.3.1] - 2026-02-21

### 修正
- **デバッグ出力の削除** - DocumentLayoutモジュールからデバッグ用print文を除去

## [0.3.0] - 2026-02-21

### 変更
- **YOLOv12nモデルへアップグレード** - YOLOv8nからYOLOv12n-DocLayNetモデルに更新し、検出精度を向上
- **YOLO出力パーサーの刷新** - Vision VNCoreMLRequestベースの検出からraw YOLOテンソル直接パース + NMS後処理に変更

### 追加
- **マルチモデルサポート** - 外部コンパイル済みモデルを読み込むイニシャライザを追加
- **モデルコンパイルAPI** - `compileModel(at:)` でmlpackageをランタイムコンパイル可能に

## [0.2.0] - 2026-02-21

### 追加
- **DocumentLayoutモジュール** - YOLOv8n-DocLayNetモデルによるドキュメントレイアウト解析機能
  - 11カテゴリの文書要素検出（テキスト、テーブル、画像、見出し等）
  - CoreMLによるオンデバイス推論
  - `LayoutElement`、`LayoutResult`、`LayoutConfiguration` 型

## [0.1.0] - 2026-02-21

### 追加
- **DocumentDetectionモジュール** - Vision frameworkによるドキュメント矩形検出
  - EMAスムージングによる安定したコーナー追跡
  - 自動キャプチャのための安定性追跡
  - 用途別プリセット設定（default、receipt、bookPage、bookSpread）
- **DocumentCameraモジュール** - AVCaptureSessionベースのカメラ制御
  - AsyncStreamによるリアルタイム検出結果ストリーミング
  - フラッシュ制御、フレームキャプチャ
  - WWDC21方式のオートフォーカス距離計算
  - カメラプリセット（receipt、bookPage、a4Document）
- **DocumentOCRモジュール** - Vision frameworkによるテキスト認識
  - 多言語サポート（日本語、英語、中国語等）
  - 精度/速度のトレードオフ設定
  - 言語補正オプション
  - プリセット設定（japanese、english）
- **SwiftUIサポート** - CameraPreviewView、RectangleOverlayView

[未リリース]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/no-problem-dev/swift-document-scanner/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/no-problem-dev/swift-document-scanner/releases/tag/v0.1.0
