import Foundation

/// Failures that stop text recognition before it can return a result.
public enum OCRError: Error, LocalizedError, Sendable {
    /// The data could not be opened as an image at all, so nothing was recognised.
    case invalidImage
    /// Vision failed the request; the payload carries its own description of why.
    case recognitionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "Failed to load image"
        case .recognitionFailed(let message):
            "Text recognition failed: \(message)"
        }
    }
}
