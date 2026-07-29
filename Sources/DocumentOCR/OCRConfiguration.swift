import Foundation

/// OCR テキスト認識の設定。
public struct OCRConfiguration: Sendable {
    /// 認識言語の優先度順リスト（例: ["ja-JP", "en-US"]）。
    public var recognitionLanguages: [String]

    /// 認識精度レベル。
    public var recognitionLevel: RecognitionLevel

    /// 認識後に言語補正処理を適用するかどうか。
    ///
    /// 文章には効くが、**辞書に無い書き方をする紙では害になる**。補正は認識した文字列を
    /// 語彙に寄せるので、レシートの半角カナの略記（`ｱﾀｯｸZERO ﾂﾒｶｴ`）や型番のような
    /// 「正しい語ではないが、そう書いてある」文字列が、それらしい別の語に置き換わる。
    public var usesLanguageCorrection: Bool

    /// 認識対象とする文字の最小の高さ。画像の高さに対する割合（0.0〜1.0）で、
    /// `nil` なら Vision の既定値（画像の高さの 1/32 前後）に任せる。
    ///
    /// 既定値は文書を想定した大きさなので、**レシートのような小さい印字では行が丸ごと落ちる**。
    /// 小さくすると拾える代わりに、ノイズも拾い、遅くなる。
    public var minimumTextHeight: Float?

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
    /// 日本語 + 英語、高精度モード、言語補正あり。
    public static let japanese = OCRConfiguration(
        recognitionLanguages: ["ja-JP", "en-US"]
    )

    /// 英語のみ、高精度モード、言語補正あり。
    public static let english = OCRConfiguration(
        recognitionLanguages: ["en-US"]
    )

    /// レシート。日本語 + 英語、高精度モード、**言語補正なし**、小さい印字を拾う。
    ///
    /// 補正を切るのは、レシートの品名が半角カナの独自略記で書かれるため（`ｷﾚｲｷﾚｲ ﾎｰﾑ 詰替`）。
    /// 補正をかけると辞書の語に寄って別物になり、**あとから商品を特定できなくなる**。
    /// 読めたままを返し、意味づけは呼び出し側に任せる。
    ///
    /// `minimumTextHeight` を既定より小さく取るのは、感熱紙の印字が文書より小さいから。
    /// 検出とカメラの `.receipt` プリセットと組で使う。
    public static let receipt = OCRConfiguration(
        recognitionLanguages: ["ja-JP", "en-US"],
        recognitionLevel: .accurate,
        usesLanguageCorrection: false,
        minimumTextHeight: 0.008
    )
}
