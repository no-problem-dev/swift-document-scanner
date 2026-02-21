import Foundation

/// Errors from camera capture operations.
public enum CameraError: Error, LocalizedError, Sendable {
    case imageDataNotAvailable

    public var errorDescription: String? {
        switch self {
        case .imageDataNotAvailable:
            "Image data not available"
        }
    }
}
