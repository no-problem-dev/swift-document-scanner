import Foundation

/// OCR テキスト認識の設定。
public struct OCRConfiguration: Sendable {
    /// 認識言語の優先度順リスト（例: ["ja-JP", "en-US"]）。
    public var recognitionLanguages: [String]

    /// 認識精度レベル。
    public var recognitionLevel: RecognitionLevel

    /// 認識後に言語補正処理を適用するかどうか。
    public var usesLanguageCorrection: Bool

    /// 認識精度と速度のトレードオフ設定。
    public enum RecognitionLevel: Sendable {
        /// 高精度・低速。
        case accurate
        /// 低精度・高速。
        case fast
    }

    public init(
        recognitionLanguages: [String],
        recognitionLevel: RecognitionLevel = .accurate,
        usesLanguageCorrection: Bool = true
    ) {
        self.recognitionLanguages = recognitionLanguages
        self.recognitionLevel = recognitionLevel
        self.usesLanguageCorrection = usesLanguageCorrection
    }
}

// MARK: - Presets

extension OCRConfiguration {
    /// 日本語 + 英語、高精度モード、言語補正あり。
    public static let japanese = OCRConfiguration(
        recognitionLanguages: ["ja-JP", "en-US"]
    )

    /// 英語のみ、高精度モード、言語補正あり。
    public static let english = OCRConfiguration(
        recognitionLanguages: ["en-US"]
    )
}
