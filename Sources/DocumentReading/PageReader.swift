import CoreGraphics
import DocumentDetection
import DocumentImaging
import DocumentLayout
import DocumentOCR
import Foundation

/// Why a picture could not be read.
public enum PageReadingError: Error, Sendable, Equatable {
    /// The data could not be opened as an image.
    case invalidImage
}

/// Reads a photographed page end to end: optional outline crop, rotation, text in reading order,
/// and the layout region of every line.
@available(iOS 26.0, macOS 26.0, *)
public protocol PageReader: Sendable {
    /// Reads encoded image data, honouring the orientation stored in the file.
    func read(imageData: Data) async throws -> ReadPage

    /// Reads pixels that are stored the way they are viewed.
    func read(_ cgImage: CGImage) async throws -> ReadPage
}

@available(iOS 26.0, macOS 26.0, *)
public actor PageReaderImpl: PageReader {
    private let configuration: PageReadingConfiguration
    private let recognizer: any PageTextRecognizer
    private let layout: (any DocumentLayoutService)?

    public init(configuration: PageReadingConfiguration) throws {
        self.configuration = configuration
        recognizer = PageTextRecognizerImpl(configuration: configuration.ocr)
        layout = try configuration.layout.map { try DocumentLayoutServiceImpl(configuration: $0) }
    }

    public init(
        configuration: PageReadingConfiguration,
        recognizer: any PageTextRecognizer,
        layout: (any DocumentLayoutService)?
    ) {
        self.configuration = configuration
        self.recognizer = recognizer
        self.layout = layout
    }

    public func read(imageData: Data) async throws -> ReadPage {
        guard let upright = DecodedImage(data: imageData)?.upright else {
            throw PageReadingError.invalidImage
        }
        return try await read(upright)
    }

    public func read(_ cgImage: CGImage) async throws -> ReadPage {
        let (picture, isCropped) = cropped(cgImage)
        let text = try await recognizer.recognize(picture, correctsRotation: configuration.correctsRotation)
        let regions = try await layout?.analyze(text.image).elements ?? []
        let lines = text.lines.map { line in
            ReadLine(
                text: line.text,
                confidence: line.confidence,
                boundingBox: line.boundingBox,
                isVertical: line.isVertical,
                region: RegionAssignment.region(of: line.boundingBox, among: regions)
            )
        }
        return ReadPage(
            image: text.image,
            isCropped: isCropped,
            turn: text.turn,
            writing: text.writing,
            lines: lines,
            regions: regions
        )
    }

    private func cropped(_ cgImage: CGImage) -> (CGImage, Bool) {
        guard configuration.cropping == .detectedDocument,
              let outline = RectangleDetectionServiceImpl(configuration: .default).detect(in: cgImage),
              let flattened = PerspectiveCorrection.correct(cgImage: cgImage, observation: outline)
        else { return (cgImage, false) }
        return (flattened, true)
    }
}
