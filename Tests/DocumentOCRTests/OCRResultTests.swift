import CoreGraphics
import Testing
@testable import DocumentOCR

private func line(_ text: String, _ confidence: Float, y: CGFloat = 0) -> OCRLine {
    OCRLine(
        text: text,
        confidence: confidence,
        boundingBox: CGRect(x: 0.1, y: y, width: 0.5, height: 0.02)
    )
}

@Suite("OCRResult Tests")
struct OCRResultTests {
    @Test("Result with text and confidence")
    func resultWithConfidence() {
        let result = OCRResult(text: "Hello World", confidence: 0.95)
        #expect(result.text == "Hello World")
        #expect(result.confidence == 0.95)
        #expect(result.lines.isEmpty)
    }

    @Test("Result with nil confidence")
    func resultWithNilConfidence() {
        let result = OCRResult(text: "", confidence: nil)
        #expect(result.text == "")
        #expect(result.confidence == nil)
    }

    @Test("Sendable conformance")
    func sendable() async {
        let result = OCRResult(text: "test", confidence: 0.5)
        let task = Task { result }
        let value = await task.value
        #expect(value.text == "test")
    }

    @Test("行から組むと text と confidence が導出される")
    func derivesFromLines() throws {
        let result = OCRResult(lines: [line("ｱﾀｯｸZERO ﾂﾒｶｴ", 0.8), line("498", 0.6, y: 0.9)])

        #expect(result.text == "ｱﾀｯｸZERO ﾂﾒｶｴ\n498")
        // The mean is binary floating point, so compare with a tolerance rather than for equality
        // (the mean of 0.8 and 0.6 comes out as 0.70000005)
        #expect(abs(try #require(result.confidence) - 0.7) < 0.0001)
        #expect(result.lines.count == 2)
    }

    /// An item name and its price sit apart on a receipt and come back as separate observations,
    /// which is why the position has to survive. The joined string alone cannot tell you which
    /// price belongs to which name.
    @Test("位置が保たれる（結合した文字列では失われる情報）")
    func keepsBoundingBoxes() {
        let name = OCRLine(
            text: "ｱﾀｯｸZERO",
            confidence: 0.8,
            boundingBox: CGRect(x: 0.05, y: 0.5, width: 0.4, height: 0.02)
        )
        let price = OCRLine(
            text: "498",
            confidence: 0.9,
            boundingBox: CGRect(x: 0.80, y: 0.5, width: 0.1, height: 0.02)
        )
        let result = OCRResult(lines: [name, price])

        // Same height, far apart horizontally — enough for a caller to read them as one row
        #expect(result.lines[0].boundingBox.minY == result.lines[1].boundingBox.minY)
        #expect(result.lines[1].boundingBox.minX > result.lines[0].boundingBox.maxX)
    }

    @Test("行がゼロなら confidence は nil・text は空")
    func emptyLines() {
        let result = OCRResult(lines: [])
        #expect(result.text.isEmpty)
        #expect(result.confidence == nil)
    }
}
