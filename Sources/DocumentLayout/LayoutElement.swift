import CoreGraphics
import Foundation

/// One region of a page that the layout model found, and what it took that region to be.
public struct LayoutElement: Sendable, Equatable {
    /// The highest-scoring of the eleven classes the model chose for this region.
    ///
    /// Only the winner is kept; the scores for the other ten are gone by the time you see this.
    public let category: Category

    /// Where the region sits, normalised 0 to 1 with the origin at the **top left** — the
    /// opposite of the convention Vision and DocumentDetection use.
    ///
    /// It is clamped to the image, so a box the model pushed past an edge arrives truncated
    /// rather than negative or oversized.
    public let boundingBox: CGRect

    /// The model's raw score for the winning class, from 0 to 1, uncalibrated.
    ///
    /// It says how sure the model is of the label, not how well the box fits the region.
    public let confidence: Float

    public init(category: Category, boundingBox: CGRect, confidence: Float) {
        self.category = category
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

// MARK: - Category

extension LayoutElement {
    /// The eleven kinds of region the DocLayNet model was trained to tell apart.
    ///
    /// The raw values are DocLayNet's own labels, so they line up with datasets and tools that
    /// use the same vocabulary. Every region gets one of these and nothing else — there is no
    /// "unknown" case, so an unusual region is labelled with whichever of the eleven scored best.
    public enum Category: String, Sendable, CaseIterable {
        /// Text attached to a figure or table that describes it.
        case caption = "Caption"
        /// A note anchored at the foot of the page, outside the running text.
        case footnote = "Footnote"
        /// A mathematical expression set apart from the text as its own block.
        case formula = "Formula"
        /// A single entry in a bulleted or numbered list; a list produces one region per entry.
        case listItem = "List-item"
        /// Running matter at the bottom of the page, such as a page number.
        case pageFooter = "Page-footer"
        /// Running matter at the top of the page, such as a chapter title.
        case pageHeader = "Page-header"
        /// A photograph, illustration, chart, or diagram.
        case picture = "Picture"
        /// A heading that opens a section, as distinct from the document's own title.
        case sectionHeader = "Section-header"
        /// A table, located as one block. Its rows, columns, and cells are not recovered.
        case table = "Table"
        /// A paragraph-level block of body text.
        case text = "Text"
        /// The title of the document as a whole.
        case title = "Title"

        /// Whether the region is something to look at rather than read.
        ///
        /// Tables and formulas count as visual alongside pictures, because their structure is not
        /// recovered here — cropping the image out is the only thing you can do with them.
        public var isVisual: Bool {
            switch self {
            case .picture, .table, .formula:
                true
            default:
                false
            }
        }
    }
}

// MARK: - LayoutResult

/// Everything the layout model found in one image, ordered down the page.
public struct LayoutResult: Sendable {
    /// The regions found, sorted by the top edge of each box.
    ///
    /// It is a single vertical ordering, not a reading order: on a two-column page the two
    /// columns interleave rather than running down one and then the other.
    public let elements: [LayoutElement]

    public init(elements: [LayoutElement]) {
        self.elements = elements.sorted { $0.boundingBox.minY < $1.boundingBox.minY }
    }

    /// The regions of one category, still in top-to-bottom order.
    public func elements(ofCategory category: LayoutElement.Category) -> [LayoutElement] {
        elements.filter { $0.category == category }
    }

    /// Every picture region, top to bottom — the usual input to cropping figures out of a page.
    public var pictures: [LayoutElement] {
        elements(ofCategory: .picture)
    }

    /// Every table region, top to bottom, located but not parsed into rows and cells.
    public var tables: [LayoutElement] {
        elements(ofCategory: .table)
    }
}
