import CoreGraphics
import Foundation

/// Vision 座標系（原点: 左下、0.0〜1.0 正規化）で表した矩形の四隅。
public struct RectangleCorners: Sendable, Equatable {
    /// 左上の頂点（Vision 座標系: 原点左下のため y 値が大きい）。
    public let topLeft: CGPoint
    /// 右上の頂点（Vision 座標系: 原点左下のため y 値が大きい）。
    public let topRight: CGPoint
    /// 左下の頂点（Vision 座標系: 原点左下のため y 値が小さい）。
    public let bottomLeft: CGPoint
    /// 右下の頂点（Vision 座標系: 原点左下のため y 値が小さい）。
    public let bottomRight: CGPoint

    public init(
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}
