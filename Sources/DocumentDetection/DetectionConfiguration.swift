import Foundation

/// Configuration for rectangle detection behavior.
public struct DetectionConfiguration: Sendable {
    /// Time (seconds) the rectangle must remain stable before auto-capture triggers.
    public var stabilityThreshold: TimeInterval

    /// Maximum corner movement (0.0-1.0 normalized) to still count as "stable".
    public var positionThreshold: CGFloat

    /// Minimum consecutive stable frames before the stability timer starts.
    public var minimumStableFrameCount: Int

    /// Rectangles larger than this ratio of the full image are rejected as "entire frame".
    public var maximumRectangleAreaRatio: CGFloat

    /// Minimum distance from edges (0.0-0.5) for a valid rectangle.
    public var minimumEdgeMargin: CGFloat

    /// Minimum Vision confidence (0.0-1.0) for a valid detection.
    public var minimumConfidence: Float

    /// EMA smoothing factor (0.0 = very smooth, 1.0 = no smoothing).
    public var smoothingFactor: CGFloat

    public init(
        stabilityThreshold: TimeInterval,
        positionThreshold: CGFloat,
        minimumStableFrameCount: Int,
        maximumRectangleAreaRatio: CGFloat,
        minimumEdgeMargin: CGFloat,
        minimumConfidence: Float,
        smoothingFactor: CGFloat
    ) {
        precondition(stabilityThreshold > 0, "stabilityThreshold must be > 0")
        self.stabilityThreshold = stabilityThreshold
        self.positionThreshold = positionThreshold
        self.minimumStableFrameCount = minimumStableFrameCount
        self.maximumRectangleAreaRatio = maximumRectangleAreaRatio
        self.minimumEdgeMargin = minimumEdgeMargin
        self.minimumConfidence = minimumConfidence
        self.smoothingFactor = smoothingFactor
    }
}

// MARK: - Presets

extension DetectionConfiguration {
    /// Default configuration for general document scanning.
    public static let `default` = DetectionConfiguration(
        stabilityThreshold: 2.0,
        positionThreshold: 0.03,
        minimumStableFrameCount: 8,
        maximumRectangleAreaRatio: 0.85,
        minimumEdgeMargin: 0.02,
        minimumConfidence: 0.5,
        smoothingFactor: 0.3
    )

    /// Optimized for receipt scanning (narrower documents).
    public static let receipt = DetectionConfiguration(
        stabilityThreshold: 2.0,
        positionThreshold: 0.03,
        minimumStableFrameCount: 8,
        maximumRectangleAreaRatio: 0.85,
        minimumEdgeMargin: 0.02,
        minimumConfidence: 0.5,
        smoothingFactor: 0.3
    )

    /// Optimized for book page scanning (larger documents, faster capture).
    public static let bookPage = DetectionConfiguration(
        stabilityThreshold: 1.5,
        positionThreshold: 0.04,
        minimumStableFrameCount: 6,
        maximumRectangleAreaRatio: 0.95,
        minimumEdgeMargin: 0.01,
        minimumConfidence: 0.4,
        smoothingFactor: 0.3
    )
}
