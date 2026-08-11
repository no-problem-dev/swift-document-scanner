import Foundation

/// Everything one recognition pass produced: the chunks, their joined text, and a mean confidence.
public struct OCRResult: Sendable {
    /// Every recognised chunk joined with newlines, as a convenience where positions do not matter.
    ///
    /// **Work from `lines` when the layout matters** — joining is the step that destroys the
    /// pairing between chunks and any confidence in their order (see `OCRLine`). No whitespace or
    /// line-break normalisation is applied: the chunks appear exactly as Vision returned them.
    public let text: String

    /// The unweighted mean of every chunk's confidence, or nil when nothing was recognised.
    ///
    /// A long paragraph and a two-character fragment count the same, so one confidently read
    /// scrap can lift the average of a page that otherwise went badly.
    public let confidence: Float?

    /// Each recognised chunk in the order Vision returned it, with its own position and confidence.
    public let lines: [OCRLine]

    /// Builds a result from observations, deriving the joined text and the mean confidence from
    /// them so the three cannot contradict each other.
    public init(lines: [OCRLine]) {
        self.lines = lines
        self.text = lines.map(\.text).joined(separator: "\n")
        self.confidence = lines.isEmpty
            ? nil
            : lines.reduce(Float(0)) { $0 + $1.confidence } / Float(lines.count)
    }

    /// Builds a result from values that are already known, for tests and for results that carry
    /// no per-chunk detail.
    ///
    /// Nothing is derived here, so the text and the confidence are never checked against the
    /// chunks and may disagree with them.
    public init(text: String, confidence: Float?, lines: [OCRLine] = []) {
        self.text = text
        self.confidence = confidence
        self.lines = lines
    }
}
