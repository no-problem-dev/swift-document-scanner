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
        // 平均は二進浮動小数なので、等値ではなく許容差で見る（0.8 と 0.6 の平均は 0.70000005 になる）
        #expect(abs(try #require(result.confidence) - 0.7) < 0.0001)
        #expect(result.lines.count == 2)
    }

    /// レシートの品名と価格は横に離れて別々の観測として返るので、位置が要る。
    /// 結合した文字列だけでは、どの品名にどの価格が対応するかを復元できない。
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

        // 同じ高さで横に離れている ＝ 同じ行の品名と価格、と呼び出し側が判断できる
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
