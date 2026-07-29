import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import DocumentImaging

/// 1×1 の不透明な画素を 1 枚作る。中身は問われないので色は何でもよい。
private func makeCGImage(width: Int = 4, height: Int = 8) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// 指定した向きのメタデータを持つ JPEG を書き出す。orientation が nil ならメタデータを付けない。
private func makeJPEG(orientation: CGImagePropertyOrientation?) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
    var properties: [CFString: Any] = [:]
    if let orientation {
        properties[kCGImagePropertyOrientation] = orientation.rawValue
    }
    CGImageDestinationAddImage(destination, makeCGImage(), properties as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

@Suite("DecodedImage Tests")
struct DecodedImageTests {
    /// ★これが今回いちばん静かに壊れていたところ。カメラで撮った写真は画素を回さずに
    /// 向きだけを立てて保存されるので、読み落とすと横倒しのまま Vision にかかる。
    @Test(
        "EXIF の向きを読む",
        arguments: [
            CGImagePropertyOrientation.up,
            .down,
            .left,
            .right,
            .upMirrored,
            .rightMirrored,
        ]
    )
    func readsOrientation(_ orientation: CGImagePropertyOrientation) throws {
        let decoded = try #require(DecodedImage(data: makeJPEG(orientation: orientation)))
        #expect(decoded.orientation == orientation)
    }

    @Test("向きのメタデータが無ければ .up として扱う（失敗にしない）")
    func defaultsToUp() throws {
        let decoded = try #require(DecodedImage(data: makeJPEG(orientation: nil)))
        #expect(decoded.orientation == .up)
    }

    @Test("画素は向きを適用せずそのまま返す（回転はしない）")
    func doesNotRotatePixels() throws {
        // .right は「90 度回して見る」指示。画素そのものは 4×8 のまま来るべきで、
        // ここが 8×4 になっていたら、どこかで回してしまっている。
        let decoded = try #require(DecodedImage(data: makeJPEG(orientation: .right)))
        #expect(decoded.cgImage.width == 4)
        #expect(decoded.cgImage.height == 8)
    }

    @Test("画像として読めないデータは nil")
    func rejectsNonImage() {
        #expect(DecodedImage(data: Data("not an image".utf8)) == nil)
        #expect(DecodedImage(data: Data()) == nil)
    }

    @Test("PNG も開ける（JPEG 専用になっていない）")
    func decodesPNG() throws {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, makeCGImage(), nil)
        #expect(CGImageDestinationFinalize(destination))

        let decoded = try #require(DecodedImage(data: data as Data))
        #expect(decoded.cgImage.width == 4)
    }
}
