import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import DocumentOCR

/// Pins what reaches the caller when Vision refuses the image.
///
/// A refusal is reported by Vision through **two channels at once**: the request's completion
/// handler is called with the error, and `perform` throws the same error. Answering on both is
/// not a thrown error the caller can catch — it is
/// `SWIFT TASK CONTINUATION MISUSE`, which takes the process down.
@Suite("読み取りが断られたとき")
struct OCRFailureTests {

    /// An image too narrow for Vision to work on. Any dimension of 2 px or less is refused.
    private func tinyImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try #require(context.makeImage())
    }

    @Test("小さすぎる画像は、落ちずに OCRError になる")
    func refusedImageThrowsInsteadOfTrapping() async throws {
        let service = OCRServiceImpl(configuration: .japanese)
        let image = try tinyImage(width: 2, height: 300)

        await #expect(throws: OCRError.self) {
            _ = try await service.recognizeText(from: image, orientation: .up)
        }
    }

    @Test("小さすぎる画像は、データ入口からも落ちずに OCRError になる")
    func refusedImageDataThrowsInsteadOfTrapping() async throws {
        let service = OCRServiceImpl(configuration: .japanese)
        let image = try tinyImage(width: 1, height: 1)

        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))

        await #expect(throws: OCRError.self) {
            _ = try await service.recognizeText(from: data as Data)
        }
    }

    @Test("読めるが文字の無い画像は、空の結果を返す")
    func blankImageYieldsNoLines() async throws {
        let service = OCRServiceImpl(configuration: .japanese)
        let context = try #require(CGContext(
            data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        let blank = try #require(context.makeImage())

        let result = try await service.recognizeText(from: blank, orientation: .up)

        #expect(result.lines.isEmpty)
    }
}
