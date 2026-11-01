import CoreGraphics
import Testing
@testable import DocumentOCR

private func chunk(
    _ text: String,
    reading: CGVector,
    vertical: Bool,
    box: CGRect = CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.05),
    confidence: Float = 1
) -> TextChunk {
    TextChunk(text: text, confidence: confidence, box: box, reading: reading, verticalScript: vertical)
}

private let right = CGVector(dx: 1, dy: 0)
private let down = CGVector(dx: 0, dy: 1)
private let left = CGVector(dx: -1, dy: 0)
private let up = CGVector(dx: 0, dy: -1)

@Suite("ページの向きと読む順")
struct PageTextGeometryTests {
    @Test("立っている横書きと縦書きは回さない")
    func uprightPagesStay() {
        #expect(PageTextGeometry.turn(for: [chunk("横書きの本文です", reading: right, vertical: false)]) == .none)
        #expect(PageTextGeometry.turn(for: [chunk("縦書きの本文です", reading: down, vertical: true)]) == .none)
    }

    @Test("左を上にして撮った縦書きは時計回りに 1 回、右を上にしたものは反時計回りに回す")
    func verticalOnItsSide() {
        #expect(PageTextGeometry.turn(for: [chunk("縦書きの本文です", reading: right, vertical: true)]) == .clockwise)
        #expect(PageTextGeometry.turn(for: [chunk("縦書きの本文です", reading: left, vertical: true)]) == .counterclockwise)
        #expect(PageTextGeometry.turn(for: [chunk("縦書きの本文です", reading: up, vertical: true)]) == .halfTurn)
    }

    @Test("横に寝かせて撮った横書きも起こす")
    func horizontalOnItsSide() {
        #expect(PageTextGeometry.turn(for: [chunk("sideways text", reading: down, vertical: false)]) == .counterclockwise)
        #expect(PageTextGeometry.turn(for: [chunk("sideways text", reading: up, vertical: false)]) == .clockwise)
        #expect(PageTextGeometry.turn(for: [chunk("upside down", reading: left, vertical: false)]) == .halfTurn)
    }

    @Test("長い本文の行がページ番号のような短い行に勝つ")
    func longLinesOutvoteShortOnes() {
        let chunks = [
            chunk("126", reading: up, vertical: false),
            chunk("「あなたの人生の失敗は何ですか」と問われたら", reading: right, vertical: true),
        ]
        #expect(PageTextGeometry.turn(for: chunks) == .clockwise)
    }

    @Test("何も読めなければ回さない")
    func nothingRead() {
        #expect(PageTextGeometry.turn(for: []) == .none)
    }

    @Test("縦書きは右の列から、列の中は上から読む")
    func verticalReadingOrder() {
        let chunks = [
            chunk("左の列", reading: down, vertical: true, box: CGRect(x: 0.2, y: 0.1, width: 0.05, height: 0.8)),
            chunk("右の列の下", reading: down, vertical: true, box: CGRect(x: 0.7, y: 0.6, width: 0.05, height: 0.3)),
            chunk("右の列の上", reading: down, vertical: true, box: CGRect(x: 0.7, y: 0.1, width: 0.05, height: 0.4)),
        ]
        #expect(PageTextGeometry.readingOrder(chunks, writing: .vertical).map(\.text) == ["右の列の上", "右の列の下", "左の列"])
    }

    @Test("横書きは上の行から、行の中は左から読む")
    func horizontalReadingOrder() {
        let chunks = [
            chunk("second", reading: right, vertical: false, box: CGRect(x: 0.1, y: 0.5, width: 0.5, height: 0.04)),
            chunk("first right", reading: right, vertical: false, box: CGRect(x: 0.6, y: 0.1, width: 0.3, height: 0.04)),
            chunk("first left", reading: right, vertical: false, box: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.04)),
        ]
        #expect(PageTextGeometry.readingOrder(chunks, writing: .horizontal).map(\.text) == ["first left", "first right", "second"])
    }

    @Test("縦に長い枠の行と縦書きと判断された行が過半なら縦書き")
    func writingDirection() {
        let tall = chunk("縦の行", reading: down, vertical: false, box: CGRect(x: 0.5, y: 0.1, width: 0.05, height: 0.6))
        let flat = chunk("横の行", reading: right, vertical: false)
        #expect(PageTextGeometry.writing(of: [tall, tall, flat]) == .vertical)
        #expect(PageTextGeometry.writing(of: [tall, flat, flat]) == .horizontal)
    }

    @Test("どちらの読み手を使うか: 確からしさと長さで多く読んだ方。向きは文字の向きを知っている文書の読み手から")
    func choosesReader() {
        let document = [chunk("縦書きの本文です", reading: right, vertical: true, confidence: 0.5)]
        let text = [chunk("縦書きの本文ですよ", reading: right, vertical: false)]
        let reading = PageReading(documentLines: document, textLines: text)
        #expect(reading.turn == .clockwise)
        #expect(reading.lines.map(\.text) == ["縦書きの本文ですよ"])
    }

    @Test("QuarterTurn は EXIF の向きに対応する")
    func orientations() {
        #expect(QuarterTurn.none.orientation == .up)
        #expect(QuarterTurn.clockwise.orientation == .right)
        #expect(QuarterTurn.halfTurn.orientation == .down)
        #expect(QuarterTurn.counterclockwise.orientation == .left)
    }
}
