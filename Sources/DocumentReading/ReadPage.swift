import CoreGraphics
import DocumentLayout
import DocumentOCR

/// One line of a read page, with the layout region it falls in.
public struct ReadLine: Sendable, Equatable {
    public let text: String
    public let confidence: Float
    /// Top-left-origin normalised box on `ReadPage.image`.
    public let boundingBox: CGRect
    public let isVertical: Bool
    /// The layout region that covers most of the line, or nil when layout analysis was off or no
    /// region covers at least half of it.
    public let region: LayoutElement.Category?

    public init(text: String, confidence: Float, boundingBox: CGRect, isVertical: Bool, region: LayoutElement.Category?) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.isVertical = isVertical
        self.region = region
    }
}

/// Everything `PageReader` found on one picture.
public struct ReadPage: @unchecked Sendable {
    /// The picture that was read — cropped and turned upright as configured. Every box refers to it.
    public let image: CGImage
    /// Whether an outline was found and the picture cropped to it.
    public let isCropped: Bool
    /// How far the picture was turned before reading.
    public let turn: QuarterTurn
    /// Which way most of the text runs.
    public let writing: PageText.Writing
    /// The lines in reading order.
    public let lines: [ReadLine]
    /// The layout regions found, empty when layout analysis was off.
    public let regions: [LayoutElement]

    public init(
        image: CGImage,
        isCropped: Bool,
        turn: QuarterTurn,
        writing: PageText.Writing,
        lines: [ReadLine],
        regions: [LayoutElement]
    ) {
        self.image = image
        self.isCropped = isCropped
        self.turn = turn
        self.writing = writing
        self.lines = lines
        self.regions = regions
    }
}

enum RegionAssignment {
    static func region(of box: CGRect, among regions: [LayoutElement]) -> LayoutElement.Category? {
        let area = box.width * box.height
        guard area > 0 else { return nil }
        let best = regions
            .map { ($0.category, overlap($0.boundingBox, box)) }
            .max { $0.1 < $1.1 }
        guard let best, best.1 >= area / 2 else { return nil }
        return best.0
    }

    private static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let shared = a.intersection(b)
        return shared.isNull ? 0 : shared.width * shared.height
    }
}
