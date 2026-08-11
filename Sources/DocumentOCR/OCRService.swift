import DocumentImaging
import Foundation
import ImageIO
import Vision

// MARK: - Protocol

/// Reads printed text out of an image with Vision, keeping each chunk's position and confidence.
///
/// ## What the result does and does not promise
///
/// - **The languages are exactly the ones configured.** Automatic language detection is not
///   enabled, so anything printed in a language outside the configured list is not read.
/// - **The order is Vision's, not the page's.** Chunks are returned as Vision produced them and
///   are never re-sorted here, so they may not run down the page. Sort by bounding box if the
///   order matters.
/// - **The text is returned as recognised.** Whitespace inside a chunk is untouched, and the
///   only line breaks in the joined string are the ones inserted between chunks.
/// - **Confidence is per chunk.** There is no per-word or per-character score, and the overall
///   figure is an unweighted mean of the chunks.
/// - **No layout is reconstructed.** Columns are not detected, tables are not turned into rows
///   and cells, and headers are not separated from body text — for that, use DocumentLayout.
/// - **Handwriting is not part of the contract.** Nothing here asks for it or checks for it;
///   you get whatever Vision's text recogniser makes of the configured languages.
/// - **An empty result is not an error.** A page Vision found nothing on comes back with no
///   chunks, empty text and a nil confidence, exactly like a blank sheet would.
public protocol OCRService: Sendable {
    /// Reads text from encoded image data, honouring the orientation stored in the file.
    ///
    /// **Orientation metadata in the data is respected** — photos from a camera store their
    /// pixels unrotated and record the orientation separately, and reading it here is what stops
    /// a portrait photo being read sideways (see `DecodedImage`).
    ///
    /// - Parameter imageData: JPEG, PNG, HEIC, or anything else ImageIO can open.
    /// - Returns: The recognised chunks, plus the mean confidence across them.
    /// - Throws: `OCRError.invalidImage` when the data cannot be opened as an image, or
    ///   `OCRError.recognitionFailed(_:)` when Vision fails the request.
    func recognizeText(from imageData: Data) async throws -> OCRResult

    /// Reads text from already-decoded pixels, viewed at the orientation you name.
    ///
    /// - Parameters:
    ///   - cgImage: The pixels to read. They are handed to Vision as they are, never rotated.
    ///   - orientation: How those pixels are meant to be viewed. Naming it is enough — **the
    ///     caller does not have to rotate anything first**.
    /// - Returns: The recognised chunks, plus the mean confidence across them.
    /// - Throws: `OCRError.recognitionFailed(_:)` when the Vision request fails.
    func recognizeText(
        from cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> OCRResult
}

extension OCRService {
    /// Reads pixels that are already upright, or whose orientation is simply unknown.
    ///
    /// They are treated as `.up`, which is wrong for a photo straight out of a camera roll.
    public func recognizeText(from cgImage: CGImage) async throws -> OCRResult {
        try await recognizeText(from: cgImage, orientation: .up)
    }
}

// MARK: - Implementation

/// The default reader, backed by Vision's text recognition request.
///
/// Recognition runs synchronously inside the actor, so calls queue up behind one another rather
/// than overlapping. Each call builds its own request from the configuration given at init, and
/// the configuration cannot change afterwards.
public actor OCRServiceImpl: OCRService {
    private let configuration: OCRConfiguration

    public init(configuration: OCRConfiguration) {
        self.configuration = configuration
    }

    public func recognizeText(from imageData: Data) async throws -> OCRResult {
        guard let decoded = DecodedImage(data: imageData) else {
            throw OCRError.invalidImage
        }
        return try await recognizeText(from: decoded.cgImage, orientation: decoded.orientation)
    }

    public func recognizeText(
        from cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(lines: []))
                    return
                }

                // This is the only place the position is available. Drop it and the caller loses,
                // permanently, any way to pair up two chunks that sit side by side (see OCRLine).
                let lines = observations.compactMap { observation -> OCRLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRLine(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: OCRResult(lines: lines))
            }

            switch configuration.recognitionLevel {
            case .accurate:
                request.recognitionLevel = .accurate
            case .fast:
                request.recognitionLevel = .fast
            }
            request.recognitionLanguages = configuration.recognitionLanguages
            request.usesLanguageCorrection = configuration.usesLanguageCorrection
            // Leave the request alone when nil. Assigning 0 states "no lower bound", which is a
            // different behaviour from letting Vision apply its own default.
            if let minimumTextHeight = configuration.minimumTextHeight {
                request.minimumTextHeight = minimumTextHeight
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }
}
