#if canImport(UIKit)
import DocumentDetection
import SwiftUI

/// SwiftUI overlay that draws detected document corners with stability indicator.
public struct RectangleOverlayView: View {
    public let corners: RectangleCorners
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
