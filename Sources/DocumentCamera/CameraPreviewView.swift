#if canImport(UIKit)
import AVFoundation
import SwiftUI

/// Puts a capture session's live preview on screen, filled to the view and cropped at the edges.
///
/// **Available only where UIKit is, so not on macOS.** The layer is a capture preview layer built
/// by SwiftUI on the main actor, and the session handed in is only ever read here — this view
/// never starts, stops, or reconfigures it.
///
/// The preview fills the view and crops whatever does not fit, which means what the user sees is
/// not the whole frame that detection and capture work on.
public struct CameraPreviewView: UIViewRepresentable {
    public let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public func makeUIView(context: Context) -> UIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session else { return }
            previewLayer.session = session
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.videoGravity = .resizeAspectFill
    }
}
#endif
