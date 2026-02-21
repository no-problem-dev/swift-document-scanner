import Foundation

/// Configuration for the document camera capture service.
public struct CameraConfiguration: Sendable {
    /// Minimum document width in millimeters (used for auto-zoom calculation).
    public var minimumDocumentWidth: Float

    /// Target percentage of the preview the document should fill (0.0-1.0).
    public var previewFillPercentage: Float

    /// JPEG compression quality for captured frames (0.0-1.0).
    public var jpegCompressionQuality: CGFloat

    public init(
        minimumDocumentWidth: Float = 100,
        previewFillPercentage: Float = 0.8,
        jpegCompressionQuality: CGFloat = 0.9
    ) {
        self.minimumDocumentWidth = minimumDocumentWidth
        self.previewFillPercentage = previewFillPercentage
        self.jpegCompressionQuality = jpegCompressionQuality
    }
}

// MARK: - Presets

extension CameraConfiguration {
    /// Optimized for receipt scanning (100mm width, 80% fill).
    public static let receipt = CameraConfiguration(
        minimumDocumentWidth: 100,
        previewFillPercentage: 0.8,
        jpegCompressionQuality: 0.9
    )

    /// Optimized for book page scanning (200mm width, 90% fill, higher quality).
    public static let bookPage = CameraConfiguration(
        minimumDocumentWidth: 200,
        previewFillPercentage: 0.9,
        jpegCompressionQuality: 0.95
    )

    /// Optimized for A4 document scanning (210mm width, 90% fill).
    public static let a4Document = CameraConfiguration(
        minimumDocumentWidth: 210,
        previewFillPercentage: 0.9,
        jpegCompressionQuality: 0.9
    )
}
