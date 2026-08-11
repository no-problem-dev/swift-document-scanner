import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import DocumentImaging
@testable import DocumentLayout

// MARK: - Helpers

/// A portrait page with a heading, a block of body text and a figure, drawn the right way up.
///
/// Real glyphs rather than black bars, because the model was trained on documents and finds
/// nothing on a page of rectangles — a page it finds nothing on cannot tell two readings of it
/// apart. The shape is what makes a wrong turn visible: a page analysed sideways is a landscape
/// one.
private func makeUprightPage(width: Int = 768, height: Int = 1024) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    func draw(_ text: String, size: CGFloat, bold: Bool, in rect: CGRect) {
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: CTFontCreateWithName(
                (bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil
            ),
            kCTForegroundColorAttributeName: CGColor(gray: 0, alpha: 1),
        ]
        let string = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        let frame = CTFramesetterCreateFrame(
            framesetter, CFRangeMake(0, 0), CGPath(rect: rect, transform: nil), nil
        )
        CTFrameDraw(frame, context)
    }

    // y counts upwards here, so the heading goes at the high end of the page.
    let margin = CGFloat(width) * 0.09
    draw(
        "A Study of Document Layout",
        size: 30, bold: true,
        in: CGRect(x: margin, y: CGFloat(height) - 130, width: CGFloat(width) - margin * 2, height: 60)
    )
    draw(
        String(
            repeating: "The quick brown fox jumps over the lazy dog. Lorem ipsum dolor sit amet, "
                + "consectetur adipiscing elit sed do eiusmod tempor. ",
            count: 14
        ),
        size: 15, bold: false,
        in: CGRect(
            x: margin, y: 380,
            width: CGFloat(width) - margin * 2, height: CGFloat(height) - 530
        )
    )
    // A figure in the lower half, so the two halves of the page are not interchangeable.
    context.setFillColor(gray: 0.75, alpha: 1)
    context.fill(CGRect(x: margin, y: 90, width: CGFloat(width) - margin * 2, height: 250))

    return context.makeImage()!
}

/// Encodes pixels as PNG, recording an orientation beside them the way a camera does — the pixels
/// themselves are left lying down.
private func makePNG(_ image: CGImage, orientation: CGImagePropertyOrientation) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
        data, UTType.png.identifier as CFString, 1, nil
    )!
    CGImageDestinationAddImage(
        destination,
        image,
        [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
    )
    _ = CGImageDestinationFinalize(destination)
    return data as Data
}

/// The bundled model is an `.mlpackage`, which only an Xcode-driven build compiles into the
/// `.mlmodelc` the loader looks for; a plain `swift build` copies it in pieces and the loader
/// finds nothing. The end-to-end test below therefore runs under `xcodebuild` and is skipped
/// under `swift test`, rather than being quietly reported as passing there.
private let modelIsAvailable = (try? DocumentLayoutServiceImpl()) != nil

// MARK: - Tests

@Suite("Layout Orientation Tests")
struct LayoutOrientationTests {
    /// The frame the model is shown, which is the frame every box in the result is expressed in.
    ///
    /// A camera stores a portrait photo as landscape pixels plus a note saying which way is up.
    /// Analysing those pixels as they are gives boxes in a frame lying on its side: "the top of
    /// the page" in the result is really one of its edges, and nothing about the result says so.
    @Test("EXIF が回転を宣言した写真は、起こしてから解析される")
    func analysesTheUprightFrame() throws {
        let page = makeUprightPage(width: 96, height: 144)
        let asStored = try #require(DecodedImage(cgImage: page, orientation: .left).upright)
        #expect(asStored.width == 144)
        #expect(asStored.height == 96)

        let analysed = try DocumentLayoutServiceImpl.uprightImage(
            from: makePNG(asStored, orientation: .right)
        )

        #expect(analysed.width == 96)
        #expect(analysed.height == 144)
    }

    /// The whole point of the orientation, measured on the result rather than on the input: the
    /// regions found in a sideways-stored photo have to be the regions of the upright page.
    @Test("回転した写真の解析結果は、起きた画像の解析結果と一致する", .enabled(if: modelIsAvailable))
    func geometryMatchesTheUprightInterpretation() async throws {
        let service = try DocumentLayoutServiceImpl()

        let page = makeUprightPage()
        let asStored = try #require(DecodedImage(cgImage: page, orientation: .left).upright)

        let upright = try await service.analyze(page)
        let fromCamera = try await service.analyze(imageData: makePNG(asStored, orientation: .right))
        let sideways = try await service.analyze(asStored)

        // A page nothing is found on would make every comparison below vacuously true.
        try #require(!upright.elements.isEmpty)

        #expect(fromCamera.elements.count == upright.elements.count)
        for (found, expected) in zip(fromCamera.elements, upright.elements) {
            #expect(found.category == expected.category)
            #expect(abs(found.boundingBox.minX - expected.boundingBox.minX) < 0.02)
            #expect(abs(found.boundingBox.minY - expected.boundingBox.minY) < 0.02)
            #expect(abs(found.boundingBox.width - expected.boundingBox.width) < 0.02)
            #expect(abs(found.boundingBox.height - expected.boundingBox.height) < 0.02)
        }

        // And the two readings really are distinguishable, so the check above has teeth.
        let uprightBoxes = upright.elements.map(\.boundingBox)
        let sidewaysBoxes = sideways.elements.map(\.boundingBox)
        #expect(uprightBoxes != sidewaysBoxes)
    }
}
