#if canImport(UIKit)
import AVFoundation
import Testing
@testable import DocumentCamera
@testable import DocumentDetection

/// カメラのセッションを**画面へ渡せること**を守る。
///
/// ## なぜこのテストが要るのか
///
/// `captureSession` は README の使用例そのもの（`CameraPreviewView(session: service.captureSession)`）で、
/// **actor の外＝画面側から読む前提の API**。ところが Swift 6 の並行性検査では、
/// `nonisolated let` に置いた非 Sendable な値を隔離の外へ出せない。
///
/// パッケージの中だけを見ていると気づけない —— 中では常に actor 自身の文脈から触るので通ってしまう。
/// **落ちるのは利用側のビルドで、しかも iOS 向けにビルドしたときだけ**（macOS 向けの `swift build` では
/// この行に到達しない書き方も多い）。実際、ストックレーダーで Xcode Cloud のアーカイブが落ちるまで
/// 誰も気づかなかった。
///
/// このテストは**利用側と同じ渡し方**を再現する。ここが通らなくなったら、README のとおりに書いた人の
/// ビルドが壊れている。
@Suite("カメラのセッションを画面へ渡す")
struct CameraSessionHandoffTests {
    private func makeService() -> DocumentCameraServiceImpl {
        DocumentCameraServiceImpl(
            rectangleDetectionService: RectangleDetectionServiceImpl(configuration: .receipt),
            configuration: .receipt
        )
    }

    /// ★これがコンパイルできることが、このテストの本体。
    @MainActor
    @Test("画面（MainActor）から captureSession を受け取れる")
    func handsSessionToMainActor() {
        let service = makeService()
        let session: AVCaptureSession = service.captureSession
        #expect(session.isRunning == false)
    }

    /// protocol 越しでも同じように渡せること（具体型に依存しない使い方の担保）。
    @MainActor
    @Test("protocol 越しでも渡せる")
    func handsSessionThroughProtocol() {
        let service: any DocumentCameraService = makeService()
        let session: AVCaptureSession = service.captureSession
        #expect(session.inputs.isEmpty)
    }
}
#endif
