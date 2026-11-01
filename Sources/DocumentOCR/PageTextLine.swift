import CoreGraphics

/// One line of a page, read off the upright picture.
public struct PageTextLine: Sendable, Equatable {
    /// Vision's leading candidate for the line.
    public let text: String

    /// Vision's confidence in this line, from 0 to 1.
    public let confidence: Float

    /// Where the line sits on the upright picture, normalised 0 to 1 with **the origin at the top
    /// left** — the same space as `LayoutElement.boundingBox`, and the opposite of `OCRLine`.
    public let boundingBox: CGRect

    /// Whether the line runs top to bottom, as Japanese and Chinese body text often does.
    public let isVertical: Bool

    public init(text: String, confidence: Float, boundingBox: CGRect, isVertical: Bool) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.isVertical = isVertical
    }
}
