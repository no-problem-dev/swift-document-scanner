import DocumentImaging
import Foundation
import ImageIO
import Vision

// MARK: - Protocol

/// Vision フレームワークを使用して画像内のテキストを認識するサービス。
public protocol OCRService: Sendable {
    /// JPEG/PNG/HEIC 画像データからテキストを認識する。
    ///
    /// **データに向きのメタデータがあれば、それを尊重する**（カメラで撮った写真は
    /// 画素を回さずに向きだけを立てて保存されるため。詳細は `DecodedImage`）。
    ///
    /// - Parameter imageData: 画像データ。
    /// - Returns: 認識できたかたまりと、全体の平均信頼度を含む `OCRResult`。
    /// - Throws: `OCRError.invalidImage`（画像として開けない）、`OCRError.recognitionFailed(_:)`（Vision 認識失敗）。
    func recognizeText(from imageData: Data) async throws -> OCRResult

    /// CGImage からテキストを認識する。
    ///
    /// - Parameters:
    ///   - cgImage: 認識対象の画素。
    ///   - orientation: その画素をどう見るべきか。**呼び出し側が回転させる必要はない**。
    /// - Returns: 認識できたかたまりと、全体の平均信頼度を含む `OCRResult`。
    /// - Throws: `OCRError.recognitionFailed(_:)`（Vision リクエスト失敗）。
    func recognizeText(
        from cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> OCRResult
}

extension OCRService {
    /// 向きが分かっていない（または `.up` である）画素を読む。
    public func recognizeText(from cgImage: CGImage) async throws -> OCRResult {
        try await recognizeText(from: cgImage, orientation: .up)
    }
}

// MARK: - Implementation

/// `VNRecognizeTextRequest` を使用するデフォルト OCR 実装。
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

                // 位置が取れるのはここだけ。捨てると、横に並んだ 2 つのかたまりを
                // 対応付ける手がかりを呼び出し側が永久に失う（`OCRLine` の説明を参照）。
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
            // nil のときは触らない。0 を代入すると「下限なし」を指定したことになり、
            // Vision の既定値に任せるのとは別の挙動になる。
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
