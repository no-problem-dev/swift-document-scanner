import CoreGraphics
import CoreImage
import CoreML
import Foundation
import os
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

/// Default implementation using YOLOv12-DocLayNet CoreML model.
///
/// Performs raw tensor inference (no NMS in model) and applies
/// confidence filtering + NMS post-processing in Swift.
public actor DocumentLayoutServiceImpl: DocumentLayoutService {
    private let configuration: LayoutConfiguration
    private let mlModel: MLModel

    /// Number of classes in DocLayNet.
    private static let numClasses = 11

    /// IoU threshold for Non-Maximum Suppression.
    private static let nmsIoUThreshold: Float = 0.45

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

        self.mlModel = try MLModel(contentsOf: modelURL, configuration: mlConfig)
    }

    /// Initialize with an externally provided compiled model.
    ///
    /// Use ``compileModel(at:)`` to compile an `.mlpackage` before passing it here.
    public init(compiledModelURL: URL, configuration: LayoutConfiguration = .default) throws {
        self.configuration = configuration

        let mlConfig = MLModelConfiguration()
        mlConfig.computeUnits = .all

        self.mlModel = try MLModel(contentsOf: compiledModelURL, configuration: mlConfig)
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
        let elements = try performDetection(on: cgImage)
        return LayoutResult(elements: elements)
    }

    public func analyze(imageData: Data) async throws -> LayoutResult {
        guard let cgImage = createCGImage(from: imageData) else {
            throw LayoutError.invalidImage
        }
        return try await analyze(cgImage)
    }

    // MARK: - Private — Inference

    private func performDetection(on cgImage: CGImage) throws -> [LayoutElement] {
        // Resize image to model input size (640x640)
        let inputSize = CGFloat(configuration.inputSize)
        guard let resizedPixelBuffer = cgImage.resizedPixelBuffer(
            width: Int(inputSize), height: Int(inputSize)
        ) else {
            throw LayoutError.invalidImage
        }

        // Find the image input feature name
        let imageFeatureName = mlModel.modelDescription.inputDescriptionsByName.keys.first
            ?? "image"

        let input = try MLDictionaryFeatureProvider(dictionary: [
            imageFeatureName: MLFeatureValue(pixelBuffer: resizedPixelBuffer),
        ])

        let output = try mlModel.prediction(from: input)

        // Get raw output tensor — shape [1, 15, 8400]
        guard let outputFeatureName = mlModel.modelDescription.outputDescriptionsByName.keys.first,
              let multiArray = output.featureValue(for: outputFeatureName)?.multiArrayValue
        else {
            throw LayoutError.detectionFailed("Failed to get model output tensor")
        }

        let all = decodeYOLOOutput(
            multiArray: multiArray,
            confidenceThreshold: configuration.confidenceThreshold,
            imageWidth: CGFloat(cgImage.width),
            imageHeight: CGFloat(cgImage.height)
        )
        // Cap to maximumDetections, preferring highest-confidence detections.
        return Array(all.sorted { $0.confidence > $1.confidence }.prefix(configuration.maximumDetections))
    }

    // MARK: - Private — YOLO Output Decoding

    /// Decode raw YOLO output tensor [1, numClasses+4, numPredictions] into LayoutElements.
    private func decodeYOLOOutput(
        multiArray: MLMultiArray,
        confidenceThreshold: Float,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> [LayoutElement] {
        let shape = multiArray.shape.map(\.intValue)
        // Expected shape: [1, 15, 8400] or [1, 8400, 15]
        let channels: Int
        let numPredictions: Int

        if shape.count == 3 {
            // [batch, channels, predictions] — standard YOLO format
            if shape[1] == Self.numClasses + 4 {
                channels = shape[1]
                numPredictions = shape[2]
            } else if shape[2] == Self.numClasses + 4 {
                // Transposed: [batch, predictions, channels]
                channels = shape[2]
                numPredictions = shape[1]
            } else {
                Logger(subsystem: "DocumentLayout", category: "inference").error("Unexpected output shape: \(shape)")
                return []
            }
        } else {
            Logger(subsystem: "DocumentLayout", category: "inference").error("Unexpected output dimensions: \(shape.count)")
            return []
        }

        let isTransposed = shape.count == 3 && shape[2] == Self.numClasses + 4

        let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count)

        // Strides for [1, C, N] layout
        let stride0 = shape.count == 3 ? (isTransposed ? numPredictions * channels : channels * numPredictions) : 0
        let strideC = isTransposed ? 1 : numPredictions
        let strideN = isTransposed ? channels : 1

        _ = stride0 // suppress unused warning

        var candidates: [(element: LayoutElement, score: Float)] = []

        let inputSize = Float(configuration.inputSize)

        for i in 0..<numPredictions {
            // bbox: x_center, y_center, w, h (in pixel coords of input 640x640)
            let xCenter = pointer[0 * strideC + i * strideN]
            let yCenter = pointer[1 * strideC + i * strideN]
            let w = pointer[2 * strideC + i * strideN]
            let h = pointer[3 * strideC + i * strideN]

            // Find best class
            var bestClassIdx = 0
            var bestScore: Float = -1
            for c in 0..<Self.numClasses {
                let score = pointer[(4 + c) * strideC + i * strideN]
                if score > bestScore {
                    bestScore = score
                    bestClassIdx = c
                }
            }

            guard bestScore >= confidenceThreshold else { continue }
            guard let category = Self.classMap[bestClassIdx] else { continue }

            // Convert from model coordinates (640x640) to normalized (0-1), top-left origin
            let normX = CGFloat((xCenter - w / 2) / inputSize)
            let normY = CGFloat((yCenter - h / 2) / inputSize)
            let normW = CGFloat(w / inputSize)
            let normH = CGFloat(h / inputSize)

            let box = CGRect(
                x: max(0, normX),
                y: max(0, normY),
                width: min(1 - max(0, normX), normW),
                height: min(1 - max(0, normY), normH)
            )

            let element = LayoutElement(
                category: category,
                boundingBox: box,
                confidence: bestScore
            )
            candidates.append((element, bestScore))
        }

        // Apply Non-Maximum Suppression per class
        return applyNMS(candidates: candidates, iouThreshold: Self.nmsIoUThreshold)
    }

    // MARK: - Private — NMS

    private func applyNMS(
        candidates: [(element: LayoutElement, score: Float)],
        iouThreshold: Float
    ) -> [LayoutElement] {
        // Group by category
        var grouped: [LayoutElement.Category: [(element: LayoutElement, score: Float)]] = [:]
        for candidate in candidates {
            grouped[candidate.element.category, default: []].append(candidate)
        }

        var results: [LayoutElement] = []

        for (_, group) in grouped {
            // Sort by score descending
            let sorted = group.sorted { $0.score > $1.score }
            var kept: [LayoutElement] = []

            for candidate in sorted {
                let dominated = kept.contains { existing in
                    iou(existing.boundingBox, candidate.element.boundingBox) > iouThreshold
                }
                if !dominated {
                    kept.append(candidate.element)
                }
            }

            results.append(contentsOf: kept)
        }

        return results
    }

    private func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        guard unionArea > 0 else { return 0 }
        return Float(intersectionArea / unionArea)
    }

    // MARK: - Private — Image Utilities

    private func createCGImage(from imageData: Data) -> CGImage? {
        let ciContext = CIContext()
        guard let ciImage = CIImage(data: imageData) else { return nil }
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

// MARK: - CGImage Extension

extension CGImage {
    /// Resize to a pixel buffer of the given dimensions.
    func resizedPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}
