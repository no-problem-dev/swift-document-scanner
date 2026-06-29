import Foundation

/// 書類検出のための単一カメラフレームの処理結果。
public struct FrameDetectionResult: Sendable {
    /// UI 表示用の EMA スムージング済み四隅。矩形未検出時は nil。
    public let smoothedCorners: RectangleCorners?

    /// 矩形が静止している時間を示す安定度スコア（0.0〜1.0）。
    public let stability: Double

    /// 安定度のしきい値を超え、自動キャプチャを発動すべき状態かどうか。
    public let shouldAutoCapture: Bool

    public init(
        smoothedCorners: RectangleCorners?,
        stability: Double,
        shouldAutoCapture: Bool
    ) {
        self.smoothedCorners = smoothedCorners
        self.stability = stability
        self.shouldAutoCapture = shouldAutoCapture
    }
}
