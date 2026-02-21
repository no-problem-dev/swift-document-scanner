import CoreGraphics
import CoreImage
import CoreML
import Foundation
import Vision

// MARK: - Protocol

/// Detects document layout elements (text, pictures, tables, etc.) in images.
public protocol DocumentLayoutService: Sendable {
    /// Analyze document layout from a CGImage.
    func analyze(_ cgImage: CGImage) async throws -> LayoutResult

    /// Analyze document layout from JPEG/PNG image data.
    func analyze(imageData: Data) async throws -> LayoutResult
}

// MARK: - Implementation

/// Default implementation using YOLOv12n-DocLayNet CoreML model.
public actor DocumentLayoutServiceImpl: DocumentLayoutService {
    private let configuration: LayoutConfiguration
    private let model: VNCoreMLModel

    /// Class index to category mapping (DocLayNet 11 classes).
    private static let classMap: [Int: LayoutElement.Category] = [
        0: .caption,
        1: .footnote,
        2: .formula,
        3: .listItem,
        4: .pageFooter,
        5: .pageHeader,
        6: .picture,
        7: .sectionHeader,
        8: .table,
        9: .text,
        10: .title,
    ]

    /// Initialize with the bundled YOLOv12n model.
    public init(configuration: LayoutConfiguration = .default) throws {
        self.configuration = configuration

        guard let modelURL = Bundle.module.url(forResource: "YOLOv12nDocLayNet", withExtension: "mlmodelc")
            ?? Bundle.module.url(forResource: "YOLOv12nDocLayNet", withExtension: "mlpackage")
        else {
            throw LayoutError.modelLoadFailed
        }

        let mlConfig = MLModelConfiguration()
        mlConfig.computeUnits = .all

        let mlModel = try MLModel(contentsOf: modelURL, configuration: mlConfig)
        self.model = try VNCoreMLModel(for: mlModel)
    }

    /// Initialize with an externally provided compiled model.
    ///
    /// Use ``compileModel(at:)`` to compile an `.mlpackage` before passing it here.
    public init(compiledModelURL: URL, configuration: LayoutConfiguration = .default) throws {
        self.configuration = configuration

        let mlConfig = MLModelConfiguration()
        mlConfig.computeUnits = .all

        let mlModel = try MLModel(contentsOf: compiledModelURL, configuration: mlConfig)
        self.model = try VNCoreMLModel(for: mlModel)
    }

    /// Compile an `.mlpackage` into a compiled model that can be used with ``init(compiledModelURL:configuration:)``.
    ///
    /// - Parameter packageURL: URL to the `.mlpackage` directory.
    /// - Returns: URL to the compiled `.mlmodelc` directory.
    public static func compileModel(at packageURL: URL) throws -> URL {
        do {
            return try MLModel.compileModel(at: packageURL)
        } catch {
            throw LayoutError.modelCompilationFailed(error.localizedDescription)
        }
    }

    public func analyze(_ cgImage: CGImage) async throws -> LayoutResult {
        let confThreshold = configuration.confidenceThreshold
        let elements = try await performDetection(on: cgImage, confidenceThreshold: confThreshold)
        return LayoutResult(elements: elements)
    }

    public func analyze(imageData: Data) async throws -> LayoutResult {
        guard let cgImage = createCGImage(from: imageData) else {
            throw LayoutError.invalidImage
        }
        return try await analyze(cgImage)
    }

    // MARK: - Private

    private func performDetection(
        on cgImage: CGImage,
        confidenceThreshold: Float
    ) async throws -> [LayoutElement] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: LayoutError.detectionFailed(error.localizedDescription))
                    return
                }

                let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []

                // Extract Sendable data inside the callback to avoid data race
                let elements: [LayoutElement] = observations.compactMap { observation in
                    guard observation.confidence >= confidenceThreshold else { return nil }

                    guard let topLabel = observation.labels.first,
                          let category = Self.categoryFromLabel(topLabel.identifier)
                    else { return nil }

                    // Vision uses bottom-left origin; convert to top-left origin
                    let visionBox = observation.boundingBox
                    let topLeftBox = CGRect(
                        x: visionBox.origin.x,
                        y: 1.0 - visionBox.origin.y - visionBox.height,
                        width: visionBox.width,
                        height: visionBox.height
                    )

                    return LayoutElement(
                        category: category,
                        boundingBox: topLeftBox,
                        confidence: observation.confidence
                    )
                }

                continuation.resume(returning: elements)
            }

            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: LayoutError.detectionFailed(error.localizedDescription))
            }
        }
    }

    private static func categoryFromLabel(_ label: String) -> LayoutElement.Category? {
        // Try direct match first
        if let category = LayoutElement.Category(rawValue: label) {
            return category
        }

        // Try index-based lookup (YOLO outputs "0", "1", etc. when class names missing)
        if let index = Int(label) {
            return classMap[index]
        }

        return nil
    }

    private func createCGImage(from imageData: Data) -> CGImage? {
        let ciContext = CIContext()
        guard let ciImage = CIImage(data: imageData) else { return nil }
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}
