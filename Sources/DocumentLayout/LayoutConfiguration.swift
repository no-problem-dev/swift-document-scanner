import Foundation

/// 書類レイアウト検出の設定。
public struct LayoutConfiguration: Sendable {
    /// 検出に使用する最小信頼度しきい値（0.0〜1.0）。
    public var confidenceThreshold: Float

    /// 1 画像あたりの最大検出数。
    public var maximumDetections: Int

    /// モデルの入力画像サイズ（ピクセル、幅と高さ共通）。
    public var inputSize: Int

    public init(
        confidenceThreshold: Float = 0.25,
        maximumDetections: Int = 100,
        inputSize: Int = 640
    ) {
        self.confidenceThreshold = confidenceThreshold
        self.maximumDetections = maximumDetections
        self.inputSize = inputSize
    }
}

// MARK: - Presets

extension LayoutConfiguration {
    /// 一般的な書類レイアウト解析向けデフォルト設定。
    public static let `default` = LayoutConfiguration()

    /// 書籍ページからの図抽出向け最適化設定。信頼度しきい値を高くして誤検出を抑える。
    public static let bookPage = LayoutConfiguration(
        confidenceThreshold: 0.35,
        maximumDetections: 50
    )
}
