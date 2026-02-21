import Testing
@testable import DocumentOCR

@Suite("OCRConfiguration Tests")
struct OCRConfigurationTests {
    @Test("Japanese preset includes ja-JP and en-US")
    func japanesePreset() {
        let config = OCRConfiguration.japanese
        #expect(config.recognitionLanguages == ["ja-JP", "en-US"])
        #expect(config.usesLanguageCorrection == true)
    }

    @Test("English preset includes en-US only")
    func englishPreset() {
        let config = OCRConfiguration.english
        #expect(config.recognitionLanguages == ["en-US"])
        #expect(config.usesLanguageCorrection == true)
    }

    @Test("Custom configuration")
    func customConfiguration() {
        let config = OCRConfiguration(
            recognitionLanguages: ["zh-Hans", "en-US"],
            recognitionLevel: .fast,
            usesLanguageCorrection: false
        )
        #expect(config.recognitionLanguages == ["zh-Hans", "en-US"])
        #expect(config.usesLanguageCorrection == false)
    }

    @Test("Default recognition level is accurate")
    func defaultLevel() {
        let config = OCRConfiguration(recognitionLanguages: ["en-US"])
        switch config.recognitionLevel {
        case .accurate: break // expected
        case .fast: Issue.record("Expected accurate level")
        }
    }
}
