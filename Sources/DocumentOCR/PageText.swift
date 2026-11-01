import CoreGraphics

/// The text of one page, turned upright and put in reading order.
public struct PageText: @unchecked Sendable {
    /// The way most of the page's text runs.
    public enum Writing: Sendable, Equatable {
        /// Lines run left to right and stack downwards.
        case horizontal
        /// Lines run top to bottom and stack from right to left.
        case vertical
    }

    /// The picture the lines were read from: the input, turned by `turn`.
    ///
    /// Line boxes are relative to this picture, not to the one you passed in.
    public let image: CGImage

    /// How far the input was turned before reading. `.none` when it was already upright, or when
    /// rotation correction was switched off.
    public let turn: QuarterTurn

    /// Which way most of the text runs.
    public let writing: Writing

    /// Every line, in the order a person reads them.
    public let lines: [PageTextLine]

    public init(image: CGImage, turn: QuarterTurn, writing: Writing, lines: [PageTextLine]) {
        self.image = image
        self.turn = turn
        self.writing = writing
        self.lines = lines
    }
}
