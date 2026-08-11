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

    /// Item names on a receipt are the shop's own half-width katakana abbreviations.
    ///
    /// Language correction pulls them towards dictionary words until they are something else, and
    /// shipping with it left on breaks quietly: the text reads fine, but the product can no longer
    /// be identified. Pin it here.
    @Test("Receipt preset disables language correction")
    func receiptDisablesLanguageCorrection() {
        #expect(OCRConfiguration.receipt.usesLanguageCorrection == false)
    }

    @Test("Receipt preset lowers the minimum text height for small print")
    func receiptLowersMinimumTextHeight() throws {
        let height = try #require(OCRConfiguration.receipt.minimumTextHeight)
        // Vision's own default is around 1/32 (0.031); thermal-paper print is smaller than that
        #expect(height < 0.031)
        #expect(height > 0)
    }

    @Test("Receipt preset reads Japanese and English, accurately")
    func receiptLanguages() {
        #expect(OCRConfiguration.receipt.recognitionLanguages == ["ja-JP", "en-US"])
        switch OCRConfiguration.receipt.recognitionLevel {
        case .accurate: break // expected
        case .fast: Issue.record("Expected accurate level")
        }
    }

    /// The default is to leave it to Vision. Putting 0 in states "no lower bound", which behaves
    /// differently from leaving it alone.
    @Test("Other presets leave minimumTextHeight to Vision")
    func othersLeaveMinimumTextHeightNil() {
        #expect(OCRConfiguration.japanese.minimumTextHeight == nil)
        #expect(OCRConfiguration.english.minimumTextHeight == nil)
    }
}
