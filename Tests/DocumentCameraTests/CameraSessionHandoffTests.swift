#if canImport(UIKit)
import AVFoundation
import Testing
@testable import DocumentCamera
@testable import DocumentDetection

/// Guards that the capture session **can still be handed to the screen**.
///
/// ## Why this test exists
///
/// `captureSession` is the README's usage example verbatim
/// (`CameraPreviewView(session: service.captureSession)`), which means **it is an API meant to be
/// read from outside the actor**. Swift 6's concurrency checking, though, will not let a
/// non-Sendable value held in a `nonisolated let` cross out of the isolation.
///
/// Looking only inside the package will never show this — in here the session is always touched
/// from the actor's own context, so it compiles. **What breaks is the consumer's build, and only
/// when building for iOS** (plenty of macOS-facing code never reaches that line at all). It went
/// unnoticed until an Xcode Cloud archive failed.
///
/// This test reproduces **the same hand-off a consumer writes**. If it stops compiling, so does
/// the build of anyone who followed the README.
@Suite("カメラのセッションを画面へ渡す")
struct CameraSessionHandoffTests {
    private func makeService() -> DocumentCameraServiceImpl {
        DocumentCameraServiceImpl(
            rectangleDetectionService: RectangleDetectionServiceImpl(configuration: .receipt),
            configuration: .receipt
        )
    }

    /// The point of this test is that it compiles at all; the assertion is almost incidental.
    @MainActor
    @Test("画面（MainActor）から captureSession を受け取れる")
    func handsSessionToMainActor() {
        let service = makeService()
        let session: AVCaptureSession = service.captureSession
        #expect(session.isRunning == false)
    }

    /// The same hand-off through the protocol, so callers that avoid the concrete type keep working.
    @MainActor
    @Test("protocol 越しでも渡せる")
    func handsSessionThroughProtocol() {
        let service: any DocumentCameraService = makeService()
        let session: AVCaptureSession = service.captureSession
        #expect(session.inputs.isEmpty)
    }
}
#endif
