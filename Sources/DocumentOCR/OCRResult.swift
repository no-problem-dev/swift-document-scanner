import Foundation

/// OCR テキスト認識の結果。
public struct OCRResult: Sendable {
    /// 認識されたテキスト全文（`lines` を改行で結合）。
    ///
    /// 位置の要らない用途のための便宜。**行ごとに扱うなら `lines` を使う** ——
    /// この文字列は結合した時点で、対応関係と並びの信頼性を失っている（`OCRLine` の説明を参照）。
    public let text: String

    /// 全認識結果の平均信頼度（0.0〜1.0）。テキストが検出されなかった場合は nil。
    public let confidence: Float?

    /// 認識できたかたまりを、位置と信頼度つきで 1 件ずつ。
    public let lines: [OCRLine]

    /// 観測から組み立てる。`text` と `confidence` は `lines` から導出するので、3 つが食い違わない。
    public init(lines: [OCRLine]) {
        self.lines = lines
        self.text = lines.map(\.text).joined(separator: "\n")
        self.confidence = lines.isEmpty
            ? nil
            : lines.reduce(Float(0)) { $0 + $1.confidence } / Float(lines.count)
    }

    /// 値を直に組む（テストや、行を持たない結果を作るとき）。
    public init(text: String, confidence: Float?, lines: [OCRLine] = []) {
        self.text = text
        self.confidence = confidence
        self.lines = lines
    }
}
