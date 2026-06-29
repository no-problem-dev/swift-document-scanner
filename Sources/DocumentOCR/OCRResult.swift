import Foundation

/// OCR テキスト認識の結果。
public struct OCRResult: Sendable {
    /// 認識されたテキスト全文（行を改行で結合）。
    public let text: String

    /// 全認識結果の平均信頼度（0.0〜1.0）。テキストが検出されなかった場合は nil。
    public let confidence: Float?

    public init(text: String, confidence: Float?) {
        self.text = text
        self.confidence = confidence
    }
}
