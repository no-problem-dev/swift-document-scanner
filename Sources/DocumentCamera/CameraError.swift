import Foundation

/// The failures a capture can report.
///
/// There is only one, and it is not raised for a missing camera or refused permission — those
/// stay silent, and the session simply produces no frames.
public enum CameraError: Error, LocalizedError, Sendable {
    /// No frame could be turned into image data.
    ///
    /// It covers three different situations that the caller cannot tell apart: no frame has
    /// arrived from the camera yet, the frame could not be rendered, or JPEG encoding failed.
    /// In practice the first is by far the most common, and it also means the camera never
    /// started — check authorisation before assuming the capture itself went wrong.
    case imageDataNotAvailable

    public var errorDescription: String? {
        switch self {
        case .imageDataNotAvailable:
            "Image data not available"
        }
    }
}
