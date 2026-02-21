import Testing
@testable import DocumentDetection

@Suite("DetectionConfiguration Tests")
struct DetectionConfigurationTests {
    @Test("Default preset has valid values")
    func defaultPreset() {
        let config = DetectionConfiguration.default
        #expect(config.stabilityThreshold > 0)
        #expect(config.positionThreshold > 0)
        #expect(config.minimumStableFrameCount > 0)
        #expect(config.maximumRectangleAreaRatio > 0 && config.maximumRectangleAreaRatio <= 1.0)
        #expect(config.minimumEdgeMargin >= 0)
        #expect(config.minimumConfidence >= 0 && config.minimumConfidence <= 1.0)
        #expect(config.smoothingFactor >= 0 && config.smoothingFactor <= 1.0)
    }

    @Test("Receipt preset matches SpendInsight values")
    func receiptPreset() {
        let config = DetectionConfiguration.receipt
        #expect(config.stabilityThreshold == 2.0)
        #expect(config.positionThreshold == 0.03)
        #expect(config.minimumStableFrameCount == 8)
        #expect(config.maximumRectangleAreaRatio == 0.85)
        #expect(config.minimumEdgeMargin == 0.02)
        #expect(config.minimumConfidence == 0.5)
        #expect(config.smoothingFactor == 0.3)
    }

    @Test("Book page preset has relaxed parameters")
    func bookPagePreset() {
        let config = DetectionConfiguration.bookPage
        #expect(config.stabilityThreshold < DetectionConfiguration.receipt.stabilityThreshold)
        #expect(config.minimumStableFrameCount < DetectionConfiguration.receipt.minimumStableFrameCount)
        #expect(config.maximumRectangleAreaRatio > DetectionConfiguration.receipt.maximumRectangleAreaRatio)
    }

    @Test("Custom configuration works")
    func customConfiguration() {
        let config = DetectionConfiguration(
            stabilityThreshold: 3.0,
            positionThreshold: 0.05,
            minimumStableFrameCount: 10,
            maximumRectangleAreaRatio: 0.9,
            minimumEdgeMargin: 0.03,
            minimumConfidence: 0.7,
            smoothingFactor: 0.5
        )
        #expect(config.stabilityThreshold == 3.0)
        #expect(config.positionThreshold == 0.05)
    }
}
