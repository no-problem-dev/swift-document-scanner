import Foundation

/// Result of processing a single camera frame for document detection.
public struct FrameDetectionResult: Sendable {
    /// EMA-smoothed corners for UI display, nil if no rectangle detected.
    public let smoothedCorners: RectangleCorners?

    /// Stability score (0.0-1.0) indicating how long the rectangle has been stationary.
    public let stability: Double

    /// Whether stability threshold has been exceeded and auto-capture should trigger.
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
