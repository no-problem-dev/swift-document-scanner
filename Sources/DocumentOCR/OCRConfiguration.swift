import Foundation

/// Configuration for OCR text recognition.
public struct OCRConfiguration: Sendable {
    /// Recognition languages in priority order (e.g., ["ja-JP", "en-US"]).
    public var recognitionLanguages: [String]

    /// Recognition accuracy level.
    public var recognitionLevel: RecognitionLevel

    /// Whether to apply language correction post-processing.
    public var usesLanguageCorrection: Bool

    /// Recognition accuracy vs speed tradeoff.
    public enum RecognitionLevel: Sendable {
        /// Higher accuracy, slower processing.
        case accurate
        /// Lower accuracy, faster processing.
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
    /// Japanese + English, accurate mode with language correction.
    public static let japanese = OCRConfiguration(
        recognitionLanguages: ["ja-JP", "en-US"]
    )

    /// English only, accurate mode with language correction.
    public static let english = OCRConfiguration(
        recognitionLanguages: ["en-US"]
    )
}
