import Foundation

/// The settings applied to every text recognition request.
///
/// The presets below cover the kinds of paper this package was built for; construct a value
/// directly only when none of them fits.
public struct OCRConfiguration: Sendable {
    /// The languages to try, most preferred first, as identifiers such as `"ja-JP"`.
    ///
    /// Automatic language detection is left switched off, so this list is exhaustive: a language
    /// that is not named here is not recognised at all, however clearly it is printed.
    public var recognitionLanguages: [String]

    /// Which of Vision's two recognisers to run; every preset here uses the accurate one.
    public var recognitionLevel: RecognitionLevel

    /// Whether Vision may pull recognised strings towards real words after reading them.
    ///
    /// It helps on prose and **does harm on paper that is not written in dictionary words**.
    /// Correction moves the recognised string towards a vocabulary, so a shop's own half-width
    /// katakana abbreviation on a receipt, or a model number — strings that are not proper words
    /// but are what is actually printed — get swapped for a plausible different word.
    public var usesLanguageCorrection: Bool

    /// The smallest character height to look for, as a fraction of the image height.
    ///
    /// Leave it nil to let Vision decide (its own default is around 1/32 of the image height).
    /// That default assumes document-sized type, so **whole lines vanish on small print such as a
    /// receipt**. Lowering it picks those lines up at the cost of more noise and more time.
    public var minimumTextHeight: Float?

    /// The accuracy-for-speed trade-off Vision makes while reading.
    public enum RecognitionLevel: Sendable {
        /// The slower, more accurate path, and the one every preset in this package uses.
        case accurate
        /// The quicker path, at lower accuracy.
        case fast
    }

    public init(
        recognitionLanguages: [String],
        recognitionLevel: RecognitionLevel = .accurate,
        usesLanguageCorrection: Bool = true,
        minimumTextHeight: Float? = nil
    ) {
        self.recognitionLanguages = recognitionLanguages
        self.recognitionLevel = recognitionLevel
        self.usesLanguageCorrection = usesLanguageCorrection
        self.minimumTextHeight = minimumTextHeight
    }
}

// MARK: - Presets

extension OCRConfiguration {
    /// Japanese with English behind it, read accurately, with language correction on.
    public static let japanese = OCRConfiguration(
        recognitionLanguages: ["ja-JP", "en-US"]
    )

    /// English alone, read accurately, with language correction on.
    public static let english = OCRConfiguration(
        recognitionLanguages: ["en-US"]
    )

    /// Receipts: Japanese and English, read accurately, **correction off**, small print picked up.
    ///
    /// Correction is off because item names on a receipt are written in the shop's own half-width
    /// katakana abbreviations. With correction on they drift towards dictionary words and become
    /// something else, and **the product can no longer be identified afterwards**. This preset
    /// returns what was read and leaves the interpretation to the caller.
    ///
    /// The minimum text height is set below Vision's default because thermal-paper print is
    /// smaller than document type. Use it with the receipt presets in DocumentDetection and
    /// DocumentCamera.
    public static let receipt = OCRConfiguration(
        recognitionLanguages: ["ja-JP", "en-US"],
        recognitionLevel: .accurate,
        usesLanguageCorrection: false,
        minimumTextHeight: 0.008
    )
}
