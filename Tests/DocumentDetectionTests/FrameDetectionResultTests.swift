import CoreGraphics
import Testing
@testable import DocumentDetection

@Suite("FrameDetectionResult Tests")
struct FrameDetectionResultTests {
    @Test("No detection result")
    func noDetection() {
        let result = FrameDetectionResult(
            smoothedCorners: nil,
            stability: 0,
            shouldAutoCapture: false
        )
        #expect(result.smoothedCorners == nil)
        #expect(result.stability == 0)
        #expect(result.shouldAutoCapture == false)
    }

    @Test("Stable detection with auto-capture")
    func stableDetection() {
        let corners = RectangleCorners(
            topLeft: CGPoint(x: 0.1, y: 0.9),
            topRight: CGPoint(x: 0.9, y: 0.9),
            bottomLeft: CGPoint(x: 0.1, y: 0.1),
            bottomRight: CGPoint(x: 0.9, y: 0.1)
        )
        let result = FrameDetectionResult(
            smoothedCorners: corners,
            stability: 1.0,
            shouldAutoCapture: true
        )
        #expect(result.smoothedCorners != nil)
        #expect(result.stability == 1.0)
        #expect(result.shouldAutoCapture == true)
    }
}
