import CoreGraphics

/// A recognised line before it is put in order, with the geometry the ordering needs.
///
/// Kept free of Vision types so the ordering and the turn estimate can be tested on plain values.
struct TextChunk: Sendable, Equatable {
    let text: String
    let confidence: Float
    /// Top-left-origin normalised box.
    let box: CGRect
    /// The direction the recogniser read the line in, in top-left-origin space (y grows downwards).
    let reading: CGVector
    /// Whether the recogniser judged the script itself to run top to bottom.
    let verticalScript: Bool

    var weight: Float {
        confidence * Float(text.count)
    }

    var line: PageTextLine {
        let tall = box.height > box.width * 1.6 && text.count > 1
        return PageTextLine(text: text, confidence: confidence, boundingBox: box, isVertical: verticalScript || tall)
    }
}

enum PageTextGeometry {
    /// Which quarter turn makes the page upright, judged from the direction its lines were read in.
    ///
    /// Upright, a horizontal line reads rightwards and a vertical one downwards. A page photographed
    /// on its side keeps the recogniser's sense of which script it is reading, so comparing the
    /// direction it read in with the upright direction for that script gives the turn. Each line
    /// votes with its confidence times its length, so a long body line outweighs a page number.
    static func turn(for chunks: [TextChunk]) -> QuarterTurn {
        var votes = [Float](repeating: 0, count: 4)
        for chunk in chunks where chunk.weight > 0 {
            let observed = direction(of: chunk.reading)
            let upright = chunk.verticalScript ? 1 : 0
            votes[(upright - observed + 4) % 4] += chunk.weight
        }
        guard let best = votes.indices.max(by: { votes[$0] < votes[$1] }), votes[best] > 0 else { return .none }
        return QuarterTurn(rawValue: best) ?? .none
    }

    /// 0 right, 1 down, 2 left, 3 up — clockwise, in top-left-origin space.
    static func direction(of vector: CGVector) -> Int {
        if abs(vector.dx) >= abs(vector.dy) {
            return vector.dx >= 0 ? 0 : 2
        }
        return vector.dy >= 0 ? 1 : 3
    }

    static func writing(of chunks: [TextChunk]) -> PageText.Writing {
        let lines = chunks.map(\.line)
        return lines.filter(\.isVertical).count * 2 > lines.count ? .vertical : .horizontal
    }

    /// Sorts lines the way a person reads the page: columns right to left for vertical text, rows
    /// top to bottom for horizontal text.
    static func readingOrder(_ chunks: [TextChunk], writing: PageText.Writing) -> [TextChunk] {
        switch writing {
        case .vertical:
            return chunks.sorted { lhs, rhs in
                let tolerance = min(lhs.box.width, rhs.box.width) / 2
                if abs(lhs.box.midX - rhs.box.midX) > tolerance {
                    return lhs.box.midX > rhs.box.midX
                }
                return lhs.box.minY < rhs.box.minY
            }
        case .horizontal:
            return chunks.sorted { lhs, rhs in
                let tolerance = min(lhs.box.height, rhs.box.height) / 2
                if abs(lhs.box.midY - rhs.box.midY) > tolerance {
                    return lhs.box.midY < rhs.box.midY
                }
                return lhs.box.minX < rhs.box.minX
            }
        }
    }
}

/// What the two recognisers made of one picture.
struct PageReading: Sendable {
    /// From the document reader, in its own reading order, carrying its judgement of the script's
    /// direction.
    let documentLines: [TextChunk]
    /// From the plain text reader, in Vision's order, with no judgement of the script's direction.
    let textLines: [TextChunk]

    /// The turn, judged from the document reader's lines — only they say whether the script runs
    /// top to bottom, which is what tells a vertical page from a horizontal one lying on its side.
    var turn: QuarterTurn {
        PageTextGeometry.turn(for: documentLines.isEmpty ? textLines : documentLines)
    }

    /// Whichever reader read more, weighted by confidence, in reading order.
    var lines: [TextChunk] {
        guard Self.score(textLines) > Self.score(documentLines) else { return documentLines }
        let writing = PageTextGeometry.writing(of: documentLines.isEmpty ? textLines : documentLines)
        return PageTextGeometry.readingOrder(textLines, writing: writing)
    }

    private static func score(_ chunks: [TextChunk]) -> Float {
        chunks.reduce(0) { $0 + $1.weight }
    }
}
