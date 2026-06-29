#if canImport(UIKit)
import DocumentDetection
import SwiftUI

/// 検出した書類の四隅と安定度インジケータを描画する SwiftUI オーバーレイ。
///
/// 安定度が 1.0 に達すると緑色の太枠を表示する。安定進行中は各コーナーに進捗サークルを表示する。
public struct RectangleOverlayView: View {
    /// Vision 座標系で表された四隅（0.0〜1.0、原点は左下）。
    public let corners: RectangleCorners
    /// 安定度スコア（0.0〜1.0）。1.0 で自動キャプチャ条件達成。
    public let stability: Double

    public init(corners: RectangleCorners, stability: Double) {
        self.corners = corners
        self.stability = stability
    }

    public var body: some View {
        GeometryReader { geometry in
            let path = createPath(in: geometry.size)

            path.stroke(
                stability >= 1.0 ? Color.green : Color.yellow,
                lineWidth: stability >= 1.0 ? 4 : 2
            )

            if stability > 0 && stability < 1.0 {
                let cornerPoints = getCorners(in: geometry.size)
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .trim(from: 0, to: stability)
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 20, height: 20)
                        .position(cornerPoints[index])
                }
            }
        }
    }

    private func createPath(in size: CGSize) -> Path {
        Path { path in
            // Convert from Vision coordinate system (bottom-left origin) to SwiftUI (top-left origin)
            let topLeft = CGPoint(
                x: corners.topLeft.x * size.width,
                y: (1 - corners.topLeft.y) * size.height
            )
            let topRight = CGPoint(
                x: corners.topRight.x * size.width,
                y: (1 - corners.topRight.y) * size.height
            )
            let bottomRight = CGPoint(
                x: corners.bottomRight.x * size.width,
                y: (1 - corners.bottomRight.y) * size.height
            )
            let bottomLeft = CGPoint(
                x: corners.bottomLeft.x * size.width,
                y: (1 - corners.bottomLeft.y) * size.height
            )

            path.move(to: topLeft)
            path.addLine(to: topRight)
            path.addLine(to: bottomRight)
            path.addLine(to: bottomLeft)
            path.closeSubpath()
        }
    }

    private func getCorners(in size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: corners.topLeft.x * size.width, y: (1 - corners.topLeft.y) * size.height),
            CGPoint(x: corners.topRight.x * size.width, y: (1 - corners.topRight.y) * size.height),
            CGPoint(x: corners.bottomRight.x * size.width, y: (1 - corners.bottomRight.y) * size.height),
            CGPoint(x: corners.bottomLeft.x * size.width, y: (1 - corners.bottomLeft.y) * size.height),
        ]
    }
}
#endif
