import CoreGraphics
import Foundation
import Testing
import DocumentLayout
import DocumentOCR
@testable import DocumentReading

@available(macOS 26.0, iOS 26.0, *)
private struct ScriptedRecognizer: PageTextRecognizer {
    let lines: [PageTextLine]
    let turn: QuarterTurn
    let received = Received()

    final class Received: @unchecked Sendable {
        var correctsRotation: Bool?
    }

    func recognize(_ cgImage: CGImage, correctsRotation: Bool) async throws -> PageText {
        received.correctsRotation = correctsRotation
        return PageText(image: cgImage, turn: turn, writing: .vertical, lines: lines)
    }
}

private struct ScriptedLayout: DocumentLayoutService {
    let elements: [LayoutElement]
    func analyze(_ cgImage: CGImage) async throws -> LayoutResult { LayoutResult(elements: elements) }
    func analyze(imageData: Data) async throws -> LayoutResult { LayoutResult(elements: elements) }
}

private func blankImage() -> CGImage {
    let context = CGContext(
        data: nil, width: 40, height: 60, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
    return context.makeImage()!
}

@Suite("ページを読む流れ")
struct PageReaderTests {
    private let body = PageTextLine(text: "本文", confidence: 1, boundingBox: CGRect(x: 0.5, y: 0.1, width: 0.05, height: 0.8), isVertical: true)
    private let folio = PageTextLine(text: "48", confidence: 1, boundingBox: CGRect(x: 0.48, y: 0.95, width: 0.04, height: 0.02), isVertical: false)

    @Test("切り出さない設定では写真をそのまま読み、各行に覆うレイアウトの領域を付ける")
    func readsWithoutCropping() async throws {
        guard #available(macOS 26.0, iOS 26.0, *) else { return }
        let recognizer = ScriptedRecognizer(lines: [body, folio], turn: .clockwise)
        let layout = ScriptedLayout(elements: [
            LayoutElement(category: .text, boundingBox: CGRect(x: 0.4, y: 0.05, width: 0.3, height: 0.9), confidence: 0.9),
            LayoutElement(category: .pageFooter, boundingBox: CGRect(x: 0.45, y: 0.94, width: 0.1, height: 0.04), confidence: 0.9),
        ])
        let reader = PageReaderImpl(configuration: .bookPhoto, recognizer: recognizer, layout: layout)

        let page = try await reader.read(blankImage())

        #expect(page.isCropped == false)
        #expect(page.turn == .clockwise)
        #expect(page.lines.map(\.region) == [.text, .pageFooter])
        #expect(recognizer.received.correctsRotation == true)
    }

    @Test("レイアウトを切った設定では領域を付けない")
    func readsWithoutLayout() async throws {
        guard #available(macOS 26.0, iOS 26.0, *) else { return }
        var configuration = PageReadingConfiguration.bookPhoto
        configuration.layout = nil
        configuration.correctsRotation = false
        let recognizer = ScriptedRecognizer(lines: [body], turn: .none)
        let reader = PageReaderImpl(configuration: configuration, recognizer: recognizer, layout: nil)

        let page = try await reader.read(blankImage())

        #expect(page.lines.map(\.region) == [nil])
        #expect(page.regions.isEmpty)
        #expect(recognizer.received.correctsRotation == false)
    }

    @Test("輪郭が見つからなければ切り出しの設定でも写真全体を読み、切り出していないと返す")
    func croppingFallsBackToWholePicture() async throws {
        guard #available(macOS 26.0, iOS 26.0, *) else { return }
        let reader = PageReaderImpl(configuration: .flatDocument, recognizer: ScriptedRecognizer(lines: [body], turn: .none), layout: nil)
        let image = blankImage()

        let page = try await reader.read(image)

        #expect(page.isCropped == false)
        #expect(page.image.width == image.width)
    }

    @Test("画像として開けないデータは invalidImage")
    func invalidData() async {
        guard #available(macOS 26.0, iOS 26.0, *) else { return }
        let reader = PageReaderImpl(configuration: .bookPhoto, recognizer: ScriptedRecognizer(lines: [], turn: .none), layout: nil)
        await #expect(throws: PageReadingError.invalidImage) {
            try await reader.read(imageData: Data([0x00, 0x01]))
        }
    }

    @Test("切り出しは設定で明示する。本の写真は切り出さず、平らな書類は切り出す")
    func croppingIsExplicit() {
        #expect(PageReadingConfiguration.bookPhoto.cropping == .none)
        #expect(PageReadingConfiguration.flatDocument.cropping == .detectedDocument)
    }

    @Test("行の半分以上を覆う領域が無ければ領域は付かない")
    func regionNeedsHalfTheLine() {
        let region = LayoutElement(category: .text, boundingBox: CGRect(x: 0, y: 0, width: 0.52, height: 1), confidence: 1)
        #expect(RegionAssignment.region(of: CGRect(x: 0.5, y: 0.1, width: 0.1, height: 0.1), among: [region]) == nil)
        #expect(RegionAssignment.region(of: CGRect(x: 0.4, y: 0.1, width: 0.1, height: 0.1), among: [region]) == .text)
    }
}
