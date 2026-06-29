import Foundation

/// 矩形検出の動作設定。
public struct DetectionConfiguration: Sendable {
    /// 自動キャプチャが発動するまでに矩形が安定し続ける必要がある時間（秒）。
    public var stabilityThreshold: TimeInterval

    /// 「安定」とみなす最大コーナー移動量（0.0〜1.0 正規化座標）。
    public var positionThreshold: CGFloat

    /// 安定タイマーを開始するまでに必要な連続安定フレーム数。
    public var minimumStableFrameCount: Int

    /// フレーム全体の書類として除外する矩形の最大面積比率。
    public var maximumRectangleAreaRatio: CGFloat

    /// 有効な矩形の端からの最小マージン（0.0〜0.5）。
    public var minimumEdgeMargin: CGFloat

    /// 有効な検出とみなす Vision の最小信頼度（0.0〜1.0）。
    public var minimumConfidence: Float

    /// EMA スムージング係数（0.0 = 最大平滑化、1.0 = スムージングなし）。
    public var smoothingFactor: CGFloat

    public init(
        stabilityThreshold: TimeInterval,
        positionThreshold: CGFloat,
        minimumStableFrameCount: Int,
        maximumRectangleAreaRatio: CGFloat,
        minimumEdgeMargin: CGFloat,
        minimumConfidence: Float,
        smoothingFactor: CGFloat
    ) {
        precondition(stabilityThreshold > 0, "stabilityThreshold must be > 0")
        self.stabilityThreshold = stabilityThreshold
        self.positionThreshold = positionThreshold
        self.minimumStableFrameCount = minimumStableFrameCount
        self.maximumRectangleAreaRatio = maximumRectangleAreaRatio
        self.minimumEdgeMargin = minimumEdgeMargin
        self.minimumConfidence = minimumConfidence
        self.smoothingFactor = smoothingFactor
    }
}

// MARK: - Presets

extension DetectionConfiguration {
    /// 一般的な書類スキャン向けデフォルト設定。
    public static let `default` = DetectionConfiguration(
        stabilityThreshold: 2.0,
        positionThreshold: 0.03,
        minimumStableFrameCount: 8,
        maximumRectangleAreaRatio: 0.85,
        minimumEdgeMargin: 0.02,
        minimumConfidence: 0.5,
        smoothingFactor: 0.3
    )

    /// レシート（縦長の狭い書類）向け最適化設定。
    public static let receipt = DetectionConfiguration(
        stabilityThreshold: 2.0,
        positionThreshold: 0.03,
        minimumStableFrameCount: 8,
        maximumRectangleAreaRatio: 0.85,
        minimumEdgeMargin: 0.02,
        minimumConfidence: 0.5,
        smoothingFactor: 0.3
    )

    /// 書籍ページ（大きな書類、高速キャプチャ）向け最適化設定。
    public static let bookPage = DetectionConfiguration(
        stabilityThreshold: 1.5,
        positionThreshold: 0.04,
        minimumStableFrameCount: 6,
        maximumRectangleAreaRatio: 0.95,
        minimumEdgeMargin: 0.01,
        minimumConfidence: 0.4,
        smoothingFactor: 0.3
    )

    /// 見開きページスキャン向け最適化設定（緩やかな検出・広いエッジ許容範囲）。
    public static let bookSpread = DetectionConfiguration(
        stabilityThreshold: 1.2,
        positionThreshold: 0.05,
        minimumStableFrameCount: 6,
        maximumRectangleAreaRatio: 0.98,
        minimumEdgeMargin: 0.005,
        minimumConfidence: 0.3,
        smoothingFactor: 0.25
    )
}
