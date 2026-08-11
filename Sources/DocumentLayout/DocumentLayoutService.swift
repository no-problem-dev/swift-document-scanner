import CoreGraphics
import CoreImage
import CoreML
import DocumentImaging
import Foundation
import os
import Vision

// MARK: - Protocol

/// Finds where the parts of a page are — text blocks, figures, tables — and labels each one.
///
/// A bundled CoreML model does the work, so nothing leaves the device. It locates and labels
/// regions and nothing more: **no text is read, no table is broken into rows and cells, and no
/// reading order is worked out** beyond sorting the regions down the page.
public protocol DocumentLayoutService: Sendable {
    /// Analyses already-decoded pixels, exactly as they are.
    ///
    /// The image is stretched into the model's square input, so its aspect ratio need not be
    /// anything in particular — but its rotation does matter: pixels that are not upright are
    /// analysed sideways, and the labels come back accordingly wrong.
    ///
    /// - Parameter cgImage: The page to analyse.
    /// - Returns: The regions found, sorted top to bottom.
    /// - Throws: `LayoutError.invalidImage` when the image cannot be redrawn into the model's
    ///   input, `LayoutError.detectionFailed(_:)` when the output cannot be read as a tensor, or
    ///   a CoreML error from the prediction itself, which is not wrapped.
    func analyze(_ cgImage: CGImage) async throws -> LayoutResult

    /// Analyses encoded image data, honouring the orientation stored in the file.
    ///
    /// **Orientation metadata in the data is respected** — photos from a camera store their
    /// pixels unrotated and record the orientation separately, so a portrait photo would
    /// otherwise be analysed lying on its side. The pixels are turned upright before the model
    /// sees them, which is also what makes the boxes that come back mean what they look like:
    /// they are in the frame of the upright page, so "the top" in the result is the top of the
    /// page (see `DecodedImage.upright`).
    ///
    /// Unlike OCR, which hands Vision the orientation and lets it deal with it, this has to turn
    /// the pixels: a CoreML pixel buffer carries pixels and nothing else.
    ///
    /// - Parameter imageData: JPEG, PNG, HEIC, or anything else ImageIO can open.
    /// - Returns: The regions found, sorted top to bottom.
    /// - Throws: `LayoutError.invalidImage` when the data cannot be opened, cannot be turned
    ///   upright, or cannot be redrawn into the model's input, `LayoutError.detectionFailed(_:)`
    ///   when the output cannot be read as a tensor, or a CoreML error from the prediction
    ///   itself, which is not wrapped.
    func analyze(imageData: Data) async throws -> LayoutResult
}

// MARK: - Implementation

/// The default implementation, running a bundled YOLOv12-DocLayNet model through CoreML.
///
/// **The model itself suppresses nothing**, so decoding the raw tensor, applying the score floor,
/// and merging overlapping boxes per class all happen here in Swift. Both of the tensor layouts
/// the exporter produces are handled; a shape that is neither is logged and yields no regions
/// rather than failing.
///
/// CoreML is left free to use every compute unit, so it will pick up the Neural Engine where
/// there is one. Being an actor, analyses queue up rather than running side by side.
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

    /// Loads the nano model that ships with this package.
    ///
    /// - Throws: `LayoutError.modelLoadFailed` when the resource is missing from the bundle, or a
    ///   CoreML error when the file is there but will not load.
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

    /// Loads a compiled model you supply, for the larger sizes that do not ship here.
    ///
    /// The URL must point at a compiled model, not at a model package — compile one first with
    /// ``compileModel(at:)``. **The output is assumed to carry DocLayNet's eleven classes in the
    /// standard order**: a model trained on anything else decodes into the wrong categories
    /// without reporting anything wrong.
    ///
    /// - Throws: A CoreML error when the model will not load.
    public init(compiledModelURL: URL, configuration: LayoutConfiguration = .default) throws {
        self.configuration = configuration

        let mlConfig = MLModelConfiguration()
        mlConfig.computeUnits = .all

        self.mlModel = try MLModel(contentsOf: compiledModelURL, configuration: mlConfig)
    }

    /// Compiles a model package into the form ``init(compiledModelURL:configuration:)`` accepts.
    ///
    /// CoreML writes the result to a temporary location, so move it somewhere you control if it
    /// has to outlive the process — compiling on every launch is slow.
    ///
    /// - Parameter packageURL: The URL of the model package directory.
    /// - Returns: The URL of the compiled model directory.
    /// - Throws: ``LayoutError/modelCompilationFailed(_:)`` when compilation fails.
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
        try await analyze(Self.uprightImage(from: imageData))
    }

    /// Opens the data and turns the pixels the way the file says they should be looked at.
    ///
    /// Taking `decoded.cgImage` here instead would be the silent failure `DocumentImaging` exists
    /// to prevent: a camera photo would come back analysed sideways, with plausible-looking boxes
    /// in a frame lying on its side, and nothing anywhere would say so.
    static func uprightImage(from imageData: Data) throws -> CGImage {
        guard
            let decoded = DecodedImage(data: imageData),
            let upright = decoded.upright
        else {
            throw LayoutError.invalidImage
        }
        return upright
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
