import CoreGraphics
import Foundation

/// 認識できたテキストの 1 かたまり（Vision の観測 1 件）。
///
/// ## なぜ全文の文字列だけでは足りないのか
///
/// Vision が返すのは「レイアウト上のひとまとまり」であって、人が見て 1 行だと思うものとは限らない。
/// レシートのように **品名と価格が横に離れて並ぶ**紙では、その 2 つは別々の観測として返る。
/// 全部を改行で繋いだ 1 本の文字列にしてしまうと、
///
/// - どの品名にどの価格が対応するのかが分からなくなる
/// - **並び順も当てにならない**（観測の順序は、見た目の上から順とは限らない）
///
/// 位置を持っておけば、呼び出し側が用途に合わせて並べ替えたり列を対応付けたりできる。
/// **その対応付け自体はここではやらない** —— 何が正しい組み方かは紙の種類ごとに違い、
/// レシートの都合を汎用の読み取りに持ち込むと使い道が狭くなる。
public struct OCRLine: Sendable, Equatable {
    /// 認識されたテキスト（最有力候補）。
    public let text: String

    /// この 1 件の信頼度（0.0〜1.0）。
    public let confidence: Float

    /// 画像内での位置。**Vision の正規化座標**で、原点は左下・幅も高さも 0〜1。
    /// 画像の大きさに依らないので、縮小した画像で読んでも同じ値になる。
    public let boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
