import Testing

@testable import DocumentLayout

@Suite("LayoutConfiguration Tests")
struct LayoutConfigurationTests {
    @Test func defaultPreset() {
        let config = LayoutConfiguration.default
        #expect(config.confidenceThreshold == 0.25)
        #expect(config.maximumDetections == 100)
        #expect(config.inputSize == 640)
    }

    @Test func bookPagePreset() {
        let config = LayoutConfiguration.bookPage
        #expect(config.confidenceThreshold == 0.35)
        #expect(config.maximumDetections == 50)
        #expect(config.inputSize == 640)
    }

    @Test func customConfiguration() {
        let config = LayoutConfiguration(
            confidenceThreshold: 0.5,
            maximumDetections: 20,
            inputSize: 1024
        )
        #expect(config.confidenceThreshold == 0.5)
        #expect(config.maximumDetections == 20)
        #expect(config.inputSize == 1024)
    }
}
