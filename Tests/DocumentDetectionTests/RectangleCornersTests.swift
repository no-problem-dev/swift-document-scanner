import CoreGraphics
import Foundation
import Testing
@testable import DocumentDetection

@Suite("RectangleCorners Tests")
struct RectangleCornersTests {
    @Test("Initialization preserves values")
    func initPreservesValues() {
        let corners = RectangleCorners(
            topLeft: CGPoint(x: 0.1, y: 0.9),
            topRight: CGPoint(x: 0.9, y: 0.9),
            bottomLeft: CGPoint(x: 0.1, y: 0.1),
            bottomRight: CGPoint(x: 0.9, y: 0.1)
        )
        #expect(corners.topLeft == CGPoint(x: 0.1, y: 0.9))
        #expect(corners.topRight == CGPoint(x: 0.9, y: 0.9))
        #expect(corners.bottomLeft == CGPoint(x: 0.1, y: 0.1))
        #expect(corners.bottomRight == CGPoint(x: 0.9, y: 0.1))
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = RectangleCorners(
            topLeft: .zero, topRight: .zero, bottomLeft: .zero, bottomRight: .zero
        )
        let b = RectangleCorners(
            topLeft: .zero, topRight: .zero, bottomLeft: .zero, bottomRight: .zero
        )
        #expect(a == b)
    }

    @Test("Sendable conformance compiles")
    func sendable() async {
        let corners = RectangleCorners(
            topLeft: .zero, topRight: .zero, bottomLeft: .zero, bottomRight: .zero
        )
        let task = Task { corners }
        let result = await task.value
        #expect(result == corners)
    }
}
