import CoreGraphics
import Foundation

/// One chunk of recognised text — a single Vision observation — with where it sat on the page.
///
/// ## Why the joined string alone is not enough
///
/// What Vision returns is a cluster of the layout, which is not necessarily what a person would
/// call a line. On paper where **the item name and the price sit far apart on the same row**,
/// such as a receipt, the two come back as separate observations. Join everything into one
/// newline-separated string and two things are gone:
///
/// - which price belongs to which item name
/// - **the order itself** — observations do not necessarily arrive in the order they appear on
///   the page
///
/// Keeping the position lets the caller re-sort them or pair up columns however the job needs.
/// **That pairing is deliberately not done here**: what counts as a correct pairing differs from
/// one kind of paper to the next, and building a receipt's rules into a general-purpose reader
/// would narrow what it is good for.
public struct OCRLine: Sendable, Equatable {
    /// The recognised string — Vision's leading candidate, with the alternatives discarded here.
    public let text: String

    /// Vision's confidence in this one observation, from 0 to 1, not a per-word or per-character
    /// score.
    public let confidence: Float

    /// Where the chunk sits, in **Vision's normalised coordinates**: origin at the bottom left,
    /// width and height both running 0 to 1.
    ///
    /// Being independent of pixel size, the values come out the same whether the image was read
    /// at full size or scaled down. Note that the origin is the opposite of SwiftUI's and UIKit's,
    /// so drawing these means flipping y.
    public let boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
