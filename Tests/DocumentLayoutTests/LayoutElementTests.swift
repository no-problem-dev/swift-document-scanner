import CoreGraphics
import Testing

@testable import DocumentLayout

@Suite("LayoutElement Tests")
struct LayoutElementTests {
    @Test func categoryRawValues() {
        #expect(LayoutElement.Category.picture.rawValue == "Picture")
        #expect(LayoutElement.Category.table.rawValue == "Table")
        #expect(LayoutElement.Category.text.rawValue == "Text")
        #expect(LayoutElement.Category.title.rawValue == "Title")
        #expect(LayoutElement.Category.sectionHeader.rawValue == "Section-header")
    }

    @Test func isVisual() {
        #expect(LayoutElement.Category.picture.isVisual == true)
        #expect(LayoutElement.Category.table.isVisual == true)
        #expect(LayoutElement.Category.formula.isVisual == true)
        #expect(LayoutElement.Category.text.isVisual == false)
        #expect(LayoutElement.Category.title.isVisual == false)
    }

    @Test func resultSortsByVerticalPosition() {
        let bottom = LayoutElement(
            category: .text,
            boundingBox: CGRect(x: 0, y: 0.8, width: 1.0, height: 0.1),
            confidence: 0.9
        )
        let top = LayoutElement(
            category: .title,
            boundingBox: CGRect(x: 0, y: 0.1, width: 1.0, height: 0.05),
            confidence: 0.95
        )

        let result = LayoutResult(elements: [bottom, top])
        #expect(result.elements.first?.category == .title)
        #expect(result.elements.last?.category == .text)
    }

    @Test func resultFiltersByCategory() {
        let elements = [
            LayoutElement(category: .picture, boundingBox: .zero, confidence: 0.9),
            LayoutElement(category: .text, boundingBox: .zero, confidence: 0.8),
            LayoutElement(category: .picture, boundingBox: .zero, confidence: 0.7),
            LayoutElement(category: .table, boundingBox: .zero, confidence: 0.85),
        ]

        let result = LayoutResult(elements: elements)
        #expect(result.pictures.count == 2)
        #expect(result.tables.count == 1)
    }

    @Test func sendable() async {
        let element = LayoutElement(
            category: .picture,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.5),
            confidence: 0.95
        )
        let result = await Task { element }.value
        #expect(result.category == .picture)
        #expect(result.confidence == 0.95)
    }
}
