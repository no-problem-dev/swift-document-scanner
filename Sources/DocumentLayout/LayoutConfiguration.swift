import Foundation

/// Configuration for document layout detection.
public struct LayoutConfiguration: Sendable {
    /// Minimum confidence threshold for detections (0.0-1.0).
    public var confidenceThreshold: Float

    /// Maximum number of detections to return per image.
    public var maximumDetections: Int

    /// Input image size for the model (width and height in pixels).
    public var inputSize: Int

    public init(
        confidenceThreshold: Float = 0.25,
        maximumDetections: Int = 100,
        inputSize: Int = 640
    ) {
        self.confidenceThreshold = confidenceThreshold
        self.maximumDetections = maximumDetections
        self.inputSize = inputSize
    }
}

// MARK: - Presets

extension LayoutConfiguration {
    /// Default configuration for general document layout analysis.
    public static let `default` = LayoutConfiguration()

    /// Configuration optimized for figure extraction from book pages.
    /// Uses a higher confidence threshold to reduce false positives.
    public static let bookPage = LayoutConfiguration(
        confidenceThreshold: 0.35,
        maximumDetections: 50
    )
}
