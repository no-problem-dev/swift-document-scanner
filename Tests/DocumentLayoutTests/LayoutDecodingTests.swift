import CoreGraphics
import CoreML
import Foundation
import Testing
@testable import DocumentLayout

/// Pins the step between the model's raw tensor and a ``LayoutElement``.
///
/// The model reports boxes in the 640×640 frame it was given, and is free to put one partly
/// outside it. Turning that into the normalised, clamped box ``LayoutElement/boundingBox``
/// promises is arithmetic, and **it can be checked without running the model at all** — the
/// tensor is built here.
@Suite("YOLO 出力の読み取り")
struct LayoutDecodingTests {

    private static let inputSize = 640
    private static let channels = 15          // 11 classes + 4 box values
    private static let textClassIndex = 9     // LayoutElement.Category.text

    /// Builds a `[1, 15, N]` tensor — the layout the bundled model actually emits.
    private func tensor(_ predictions: [(box: (x: Float, y: Float, w: Float, h: Float), classIndex: Int, score: Float)]) throws -> MLMultiArray {
        let count = predictions.count
        let array = try MLMultiArray(shape: [1, NSNumber(value: Self.channels), NSNumber(value: count)], dataType: .float32)
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        for index in 0..<array.count { pointer[index] = 0 }

        // [1, C, N]: channel c of prediction i sits at c * N + i.
        for (i, prediction) in predictions.enumerated() {
            pointer[0 * count + i] = prediction.box.x
            pointer[1 * count + i] = prediction.box.y
            pointer[2 * count + i] = prediction.box.w
            pointer[3 * count + i] = prediction.box.h
            pointer[(4 + prediction.classIndex) * count + i] = prediction.score
        }
        return array
    }

    @Test("枠の中に収まっている箱は、そのまま正規化される")
    func normalisesABoxInsideTheFrame() throws {
        // Centre (320, 320), 320×160 → x 0.25…0.75, y 0.375…0.625
        let array = try tensor([((x: 320, y: 320, w: 320, h: 160), Self.textClassIndex, 0.9)])

        let elements = DocumentLayoutServiceImpl.decodeYOLOOutput(
            multiArray: array,
            confidenceThreshold: 0.25,
            inputSize: Self.inputSize
        )

        #expect(elements.count == 1)
        let box = try #require(elements.first?.boundingBox)
        #expect(abs(box.minX - 0.25) < 0.0001)
        #expect(abs(box.minY - 0.375) < 0.0001)
        #expect(abs(box.width - 0.5) < 0.0001)
        #expect(abs(box.height - 0.25) < 0.0001)
    }

    /// A header or a full-width text block routinely reaches the margin, and the model puts the
    /// box a little past it. `LayoutElement.boundingBox` promises such a box "arrives truncated
    /// rather than negative or oversized" — so the edge that was outside moves to 0 and the
    /// **opposite edge stays where the model put it.**
    @Test("左にはみ出した箱は、はみ出した分だけ削られる（右端は動かない）")
    func truncatesABoxThatStartsLeftOfTheFrame() throws {
        // Centre (96, 240), 320×160 → x −0.1…0.4, y 0.25…0.5
        let array = try tensor([((x: 96, y: 240, w: 320, h: 160), Self.textClassIndex, 0.9)])

        let elements = DocumentLayoutServiceImpl.decodeYOLOOutput(
            multiArray: array,
            confidenceThreshold: 0.25,
            inputSize: Self.inputSize
        )

        let box = try #require(elements.first?.boundingBox)
        #expect(abs(box.minX - 0) < 0.0001)
        #expect(abs(box.maxX - 0.4) < 0.0001, "右端が動いてはいけない（箱が太る）")
        #expect(abs(box.width - 0.4) < 0.0001)
    }

    @Test("上にはみ出した箱は、はみ出した分だけ削られる（下端は動かない）")
    func truncatesABoxThatStartsAboveTheFrame() throws {
        // Centre (320, 96), 160×320 → x 0.375…0.625, y −0.1…0.4
        let array = try tensor([((x: 320, y: 96, w: 160, h: 320), Self.textClassIndex, 0.9)])

        let elements = DocumentLayoutServiceImpl.decodeYOLOOutput(
            multiArray: array,
            confidenceThreshold: 0.25,
            inputSize: Self.inputSize
        )

        let box = try #require(elements.first?.boundingBox)
        #expect(abs(box.minY - 0) < 0.0001)
        #expect(abs(box.maxY - 0.4) < 0.0001, "下端が動いてはいけない（箱が太る）")
        #expect(abs(box.height - 0.4) < 0.0001)
    }

    @Test("右下にはみ出した箱も、枠の中に収まる")
    func truncatesABoxThatRunsPastTheFarEdges() throws {
        // Centre (576, 576), 320×320 → x 0.65…1.15, y 0.65…1.15
        let array = try tensor([((x: 576, y: 576, w: 320, h: 320), Self.textClassIndex, 0.9)])

        let elements = DocumentLayoutServiceImpl.decodeYOLOOutput(
            multiArray: array,
            confidenceThreshold: 0.25,
            inputSize: Self.inputSize
        )

        let box = try #require(elements.first?.boundingBox)
        #expect(abs(box.maxX - 1) < 0.0001)
        #expect(abs(box.maxY - 1) < 0.0001)
        #expect(abs(box.minX - 0.65) < 0.0001)
    }

    @Test("しきい値に届かない予測は落ちる")
    func dropsPredictionsBelowTheThreshold() throws {
        let array = try tensor([((x: 320, y: 320, w: 160, h: 160), Self.textClassIndex, 0.2)])

        let elements = DocumentLayoutServiceImpl.decodeYOLOOutput(
            multiArray: array,
            confidenceThreshold: 0.25,
            inputSize: Self.inputSize
        )

        #expect(elements.isEmpty)
    }
}
