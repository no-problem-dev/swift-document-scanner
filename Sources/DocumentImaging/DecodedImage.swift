import CoreGraphics
import Foundation
import ImageIO

/// 画像データを開いた結果。画素と、それをどう見るべきかの向きの組。
///
/// ## 向きを画素に焼かない
///
/// カメラで撮った JPEG / HEIC は、**画素を回さずに EXIF の向きだけを立てて**保存するのが普通。
/// この向きを読まずに画素だけを取り出すと、端末を縦に構えて撮った写真が横倒しのまま出てくる。
/// Vision も CoreML も画素の並びしか見ないので、そのまま渡すと横倒しの絵として扱われる
/// （レシートのように文字の向きが結果を左右するものでは、これがそのまま読み取り失敗になる）。
///
/// 直し方は 2 つあるが、**回さずに向きを伝えるほう**を採る。
/// Vision は `VNImageRequestHandler(cgImage:orientation:options:)` で向きを受け取れるので、
/// 画素を回転させる必要がない —— 回転はメモリと時間を使ううえ、再エンコードすれば劣化もする。
///
/// ## 開き方
///
/// `CIImage(data:)` + `CIContext.createCGImage` ではなく ImageIO を直に使う。
/// CIContext は GPU/CPU のレンダリング文脈を用意するので、ただデータを開くには重い。
/// ImageIO なら**同じ 1 回の読み取りで向きのメタデータも取れる**（別々に開き直さない）。
public struct DecodedImage {
    /// 画素。**向きは適用されていない**（`orientation` と組で使う）。
    public let cgImage: CGImage

    /// この画素をどう見るべきか。メタデータが無ければ `.up`。
    public let orientation: CGImagePropertyOrientation

    public init(cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) {
        self.cgImage = cgImage
        self.orientation = orientation
    }

    /// JPEG / PNG / HEIC などのデータを開く。画像として読めなければ `nil`。
    ///
    /// 向きのメタデータが無い・未知の値のときは `.up` として扱う。ここで失敗にはしない ——
    /// 向きが分からないことは画像が読めないことではないし、大半の画像は実際に `.up` だから。
    public init?(data: Data) {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = properties?[kCGImagePropertyOrientation] as? UInt32

        self.cgImage = image
        self.orientation = raw.flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
    }
}
