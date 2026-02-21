import Testing
@testable import DocumentOCR

@Suite("OCRResult Tests")
struct OCRResultTests {
    @Test("Result with text and confidence")
    func resultWithConfidence() {
        let result = OCRResult(text: "Hello World", confidence: 0.95)
        #expect(result.text == "Hello World")
        #expect(result.confidence == 0.95)
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
}
