import Foundation

/// How close the camera is asked to focus, and how hard the captured frame is compressed.
public struct CameraConfiguration: Sendable {
    /// The width of the smallest document you intend to scan, in millimetres.
    ///
    /// It filters nothing. Together with the fill percentage it works out how near the subject
    /// has to be, and the camera zooms in when that distance is closer than the lens can focus.
    public var minimumDocumentWidth: Float

    /// How much of the frame that smallest document should fill, from 0 to 1.
    ///
    /// Raising it brings the working distance closer, which makes the automatic zoom more likely
    /// to kick in and leaves less room around the page.
    public var previewFillPercentage: Float

    /// The JPEG quality captured frames are encoded at, from 0 to 1.
    ///
    /// Every capture is JPEG; there is no lossless way out of this service, so text that has to
    /// survive recognition wants a high value here.
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
    /// Receipts: a 100 mm document filling 80% of the frame, encoded at 0.9.
    ///
    /// These are also the values a default-initialised configuration already has, so it is a name
    /// for the default rather than a change to it.
    public static let receipt = CameraConfiguration(
        minimumDocumentWidth: 100,
        previewFillPercentage: 0.8,
        jpegCompressionQuality: 0.9
    )

    /// Book pages: a 200 mm page filling 90% of the frame, encoded at 0.95 to keep small type.
    public static let bookPage = CameraConfiguration(
        minimumDocumentWidth: 200,
        previewFillPercentage: 0.9,
        jpegCompressionQuality: 0.95
    )

    /// A4 documents: a 210 mm page filling 90% of the frame, encoded at 0.9.
    public static let a4Document = CameraConfiguration(
        minimumDocumentWidth: 210,
        previewFillPercentage: 0.9,
        jpegCompressionQuality: 0.9
    )
}
