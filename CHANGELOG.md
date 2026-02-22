# 変更履歴

このプロジェクトの全ての重要な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/lang/ja/spec/v2.0.0.html) に準拠しています。

## [未リリース]

なし

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
