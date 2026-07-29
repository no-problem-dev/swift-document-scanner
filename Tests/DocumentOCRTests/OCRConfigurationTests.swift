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

    /// レシートの品名は半角カナの独自略記（`ｱﾀｯｸZERO ﾂﾒｶｴ`）で、言語補正をかけると
    /// 辞書の語に寄って別物になる。**補正が入ったまま出荷されると、読めているのに
    /// 商品を特定できない**という気づきにくい壊れ方をするので、ここで固定する。
    @Test("Receipt preset disables language correction")
    func receiptDisablesLanguageCorrection() {
        #expect(OCRConfiguration.receipt.usesLanguageCorrection == false)
    }

    @Test("Receipt preset lowers the minimum text height for small print")
    func receiptLowersMinimumTextHeight() throws {
        let height = try #require(OCRConfiguration.receipt.minimumTextHeight)
        // Vision の既定はおよそ 1/32（0.031）。感熱紙の印字はそれより小さい
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

    /// 既定は Vision に任せる。0 を入れると「下限なし」の指定になり、任せるのとは別の挙動になる。
    @Test("Other presets leave minimumTextHeight to Vision")
    func othersLeaveMinimumTextHeightNil() {
        #expect(OCRConfiguration.japanese.minimumTextHeight == nil)
        #expect(OCRConfiguration.english.minimumTextHeight == nil)
    }
}
