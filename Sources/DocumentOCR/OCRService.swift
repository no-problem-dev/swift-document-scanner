import CoreImage
import Foundation
import Vision

// MARK: - Protocol

/// Vision フレームワークを使用して画像内のテキストを認識するサービス。
public protocol OCRService: Sendable {
    /// JPEG/PNG 画像データからテキストを認識する。
    ///
    /// - Parameter imageData: JPEG または PNG 形式の画像データ。
    /// - Returns: 認識テキストと観測値全体の平均信頼度を含む `OCRResult`。
    /// - Throws: `OCRError.invalidImage`（Data → CGImage 変換失敗）、`OCRError.recognitionFailed(_:)`（Vision 認識失敗）。
    func recognizeText(from imageData: Data) async throws -> OCRResult

    /// CGImage からテキストを認識する。
    ///
    /// - Parameter cgImage: 認識対象の CGImage。
    /// - Returns: 認識テキストと観測値全体の平均信頼度を含む `OCRResult`。
    /// - Throws: `OCRError.recognitionFailed(_:)`（Vision リクエスト失敗）。
    func recognizeText(from cgImage: CGImage) async throws -> OCRResult
}

// MARK: - Implementation

/// `VNRecognizeTextRequest` を使用するデフォルト OCR 実装。
public actor OCRServiceImpl: OCRService {
    private let configuration: OCRConfiguration
    private let ciContext = CIContext()

    public init(configuration: OCRConfiguration) {
        self.configuration = configuration
    }

    public func recognizeText(from imageData: Data) async throws -> OCRResult {
        guard let cgImage = createCGImage(from: imageData) else {
            throw OCRError.invalidImage
        }
        return try await recognizeText(from: cgImage)
    }

    public func recognizeText(from cgImage: CGImage) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(text: "", confidence: nil))
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: "\n")
                let avgConfidence: Float? = observations.isEmpty ? nil : {
                    let confidences = observations.compactMap { $0.topCandidates(1).first?.confidence }
                    return confidences.reduce(0, +) / Float(confidences.count)
                }()

                continuation.resume(returning: OCRResult(
                    text: fullText,
                    confidence: avgConfidence
                ))
            }

            switch configuration.recognitionLevel {
            case .accurate:
                request.recognitionLevel = .accurate
            case .fast:
                request.recognitionLevel = .fast
            }
            request.recognitionLanguages = configuration.recognitionLanguages
            request.usesLanguageCorrection = configuration.usesLanguageCorrection

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Private Methods

    private func createCGImage(from imageData: Data) -> CGImage? {
        guard let ciImage = CIImage(data: imageData) else {
            return nil
        }
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}
