import Testing
@testable import DocumentCamera

@Suite("CameraConfiguration Tests")
struct CameraConfigurationTests {
    @Test("Receipt preset values")
    func receiptPreset() {
        let config = CameraConfiguration.receipt
        #expect(config.minimumDocumentWidth == 100)
        #expect(config.previewFillPercentage == 0.8)
        #expect(config.jpegCompressionQuality == 0.9)
    }

    @Test("Book page preset has wider document width")
    func bookPagePreset() {
        let config = CameraConfiguration.bookPage
        #expect(config.minimumDocumentWidth == 200)
        #expect(config.previewFillPercentage == 0.9)
        #expect(config.jpegCompressionQuality == 0.95)
    }

    @Test("A4 document preset")
    func a4Preset() {
        let config = CameraConfiguration.a4Document
        #expect(config.minimumDocumentWidth == 210)
    }

    @Test("Default initialization values")
    func defaultInit() {
        let config = CameraConfiguration()
        #expect(config.minimumDocumentWidth == 100)
        #expect(config.previewFillPercentage == 0.8)
        #expect(config.jpegCompressionQuality == 0.9)
    }

    @Test("Custom initialization")
    func customInit() {
        let config = CameraConfiguration(
            minimumDocumentWidth: 150,
            previewFillPercentage: 0.7,
            jpegCompressionQuality: 0.85
        )
        #expect(config.minimumDocumentWidth == 150)
        #expect(config.previewFillPercentage == 0.7)
        #expect(config.jpegCompressionQuality == 0.85)
    }
}
