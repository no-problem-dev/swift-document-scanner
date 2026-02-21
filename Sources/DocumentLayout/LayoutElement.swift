import CoreGraphics
import Foundation

/// A detected element in a document layout.
public struct LayoutElement: Sendable, Equatable {
    /// The type of document element detected.
    public let category: Category

    /// Bounding box in normalized coordinates (0.0-1.0, origin at top-left).
    public let boundingBox: CGRect

    /// Detection confidence (0.0-1.0).
    public let confidence: Float

    public init(category: Category, boundingBox: CGRect, confidence: Float) {
        self.category = category
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

// MARK: - Category

extension LayoutElement {
    /// Document element categories detected by the DocLayNet model.
    public enum Category: String, Sendable, CaseIterable {
        case caption = "Caption"
        case footnote = "Footnote"
        case formula = "Formula"
        case listItem = "List-item"
        case pageFooter = "Page-footer"
        case pageHeader = "Page-header"
        case picture = "Picture"
        case sectionHeader = "Section-header"
        case table = "Table"
        case text = "Text"
        case title = "Title"

        /// Whether this category represents a visual/non-text element.
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

/// Result of document layout analysis on a single image.
public struct LayoutResult: Sendable {
    /// All detected elements sorted by vertical position (top to bottom).
    public let elements: [LayoutElement]

    public init(elements: [LayoutElement]) {
        self.elements = elements.sorted { $0.boundingBox.minY < $1.boundingBox.minY }
    }

    /// Elements filtered by category.
    public func elements(ofCategory category: LayoutElement.Category) -> [LayoutElement] {
        elements.filter { $0.category == category }
    }

    /// All detected pictures/figures.
    public var pictures: [LayoutElement] {
        elements(ofCategory: .picture)
    }

    /// All detected tables.
    public var tables: [LayoutElement] {
        elements(ofCategory: .table)
    }
}
