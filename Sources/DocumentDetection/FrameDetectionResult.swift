import Foundation

/// What one camera frame told the detector about the document in front of it.
public struct FrameDetectionResult: Sendable {
    /// The corners after smoothing, ready to draw, or nil when this frame held no usable document.
    ///
    /// Smoothing makes them lag the real edges slightly, which is the point: it keeps the outline
    /// from jittering. They are meant for display rather than for cropping.
    public let smoothedCorners: RectangleCorners?

    /// How far the document has got towards firing the shutter, from 0 to 1.
    ///
    /// It only starts climbing once the corners have held still for the configured number of
    /// consecutive frames, and it drops straight back to 0 on any frame that moves too far.
    public let stability: Double

    /// Whether the document has now held still long enough for an automatic capture.
    ///
    /// It stays true on every stable frame after the first, so a caller that keeps consuming the
    /// stream will see it repeatedly — stop the session or reset the detector after capturing.
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
