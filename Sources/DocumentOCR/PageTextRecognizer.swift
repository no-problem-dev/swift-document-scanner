import CoreGraphics
import DocumentImaging
import Foundation
import Vision

/// Reads a whole page of text — upright or not, horizontal or vertical — into reading order.
///
/// Unlike `OCRService`, this:
///
/// - **turns the page upright first** when it was photographed on its side or upside down, so
///   the boxes, the reading order and anything you hand on (a layout model, a crop) see a page the
///   right way up
/// - **reads vertical Japanese and Chinese**, which the older recogniser behind `OCRService`
///   largely does not
/// - **returns lines in reading order**, columns right to left for vertical text
///
/// It runs Vision's document reader and its plain text reader on the same picture and keeps
/// whichever read more, weighted by confidence. The document reader keeps paragraph order on
/// multi-column pages; the plain reader sometimes reads more of a photographed page.
@available(iOS 26.0, macOS 26.0, *)
public protocol PageTextRecognizer: Sendable {
    /// Reads the page in `cgImage`, which is taken to be stored the way it is viewed.
    ///
    /// - Parameter correctsRotation: Turn the picture upright before reading. Switch it off when
    ///   the caller already knows the page is upright.
    func recognize(_ cgImage: CGImage, correctsRotation: Bool) async throws -> PageText
}

@available(iOS 26.0, macOS 26.0, *)
public struct PageTextRecognizerImpl: PageTextRecognizer {
    private let configuration: OCRConfiguration

    public init(configuration: OCRConfiguration) {
        self.configuration = configuration
    }

    public func recognize(_ cgImage: CGImage, correctsRotation: Bool = true) async throws -> PageText {
        let first = try await reading(of: cgImage)
        let turn = correctsRotation ? first.turn : .none
        guard turn != .none else {
            return page(from: first.lines, image: cgImage, turn: .none)
        }
        guard let upright = DecodedImage(cgImage: cgImage, orientation: turn.orientation).upright else {
            throw OCRError.invalidImage
        }
        return page(from: try await reading(of: upright).lines, image: upright, turn: turn)
    }

    private func page(from read: [TextChunk], image: CGImage, turn: QuarterTurn) -> PageText {
        let writing = PageTextGeometry.writing(of: read)
        return PageText(image: image, turn: turn, writing: writing, lines: read.map(\.line))
    }

    private var languages: [Locale.Language] {
        configuration.recognitionLanguages.map { Locale.Language(identifier: $0) }
    }

    private func reading(of cgImage: CGImage) async throws -> PageReading {
        let handler = ImageRequestHandler(cgImage)
        var documentRequest = RecognizeDocumentsRequest()
        documentRequest.textRecognitionOptions.recognitionLanguages = languages
        documentRequest.textRecognitionOptions.automaticallyDetectLanguage = false
        documentRequest.textRecognitionOptions.useLanguageCorrection = configuration.usesLanguageCorrection
        documentRequest.barcodeDetectionOptions.enabled = false
        if let minimumTextHeight = configuration.minimumTextHeight {
            documentRequest.textRecognitionOptions.minimumTextHeightFraction = minimumTextHeight
        }

        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = configuration.recognitionLevel == .accurate ? .accurate : .fast
        textRequest.recognitionLanguages = languages
        textRequest.automaticallyDetectsLanguage = false
        textRequest.usesLanguageCorrection = configuration.usesLanguageCorrection
        if let minimumTextHeight = configuration.minimumTextHeight {
            textRequest.minimumTextHeightFraction = minimumTextHeight
        }

        let documentLines = ((try? await handler.perform(documentRequest)) ?? [])
            .flatMap { $0.document.text.lines }
        let textLines: [RecognizedTextObservation]
        do {
            textLines = try await handler.perform(textRequest)
        } catch {
            throw OCRError.recognitionFailed(error.localizedDescription)
        }

        return PageReading(
            documentLines: documentLines.compactMap(Self.chunk),
            textLines: textLines.compactMap(Self.chunk)
        )
    }

    private static func chunk(_ observation: RecognizedTextObservation) -> TextChunk? {
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let rect = observation.boundingBox.cgRect
        let box = CGRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
        let reading = CGVector(
            dx: observation.topRight.x - observation.topLeft.x,
            dy: -(observation.topRight.y - observation.topLeft.y)
        )
        return TextChunk(
            text: text,
            confidence: observation.confidence,
            box: box,
            reading: reading,
            verticalScript: observation.textDirection == .topToBottom
        )
    }
}
