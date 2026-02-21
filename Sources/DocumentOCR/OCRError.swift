import Foundation

/// Errors from OCR processing.
public enum OCRError: Error, LocalizedError, Sendable {
    case invalidImage
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
