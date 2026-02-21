import Foundation

/// Result of OCR text recognition.
public struct OCRResult: Sendable {
    /// Full recognized text (lines joined by newlines).
    public let text: String

    /// Average confidence across all recognized text observations (0.0-1.0), nil if no text found.
    public let confidence: Float?

    public init(text: String, confidence: Float?) {
        self.text = text
        self.confidence = confidence
    }
}
