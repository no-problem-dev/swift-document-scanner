import CoreGraphics
import CoreImage
import CoreML
import CryptoKit
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
    /// The model is bundled as an `.mlpackage`, which CoreML cannot load directly, so the first
    /// construction on a machine compiles it and keeps the result — see ``compiledBundledModel()``
    /// for what that costs and why it is kept rather than recompiled.
    ///
    /// - Throws: `LayoutError.modelLoadFailed` when the resource is missing from the bundle,
    ///   ``LayoutError/modelCompilationFailed(_:)`` when it is there but will not compile, or a
    ///   CoreML error from the load itself.
    public init(configuration: LayoutConfiguration = .default) throws {
        self.configuration = configuration

        let mlConfig = MLModelConfiguration()
        mlConfig.computeUnits = .all

        self.mlModel = try MLModel(contentsOf: Self.compiledBundledModel(), configuration: mlConfig)
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

    // MARK: - Private — The bundled model

    /// The name the bundled model resource carries, without extension.
    private static let bundledModelName = ModelVariant.nano.modelFileName

    /// The compiled form of the bundled model, compiling it the first time it is asked for.
    ///
    /// The resource ships as an `.mlpackage` and arrives that way from every build — the package
    /// declares it with SPM's `copy` rule, because `process` flattens directories and an
    /// `.mlpackage` is a directory whose layout is the file format. CoreML will not load that form,
    /// so it has to be compiled here.
    ///
    /// The result is kept in the caches directory rather than left where `compileModel(at:)` puts
    /// it, which is a fresh temporary directory each time. That path is what CoreML keys its own
    /// specialisation on: from a new location every launch, loading the model spends about four
    /// seconds preparing it for the Neural Engine, against about sixty milliseconds from one it has
    /// seen before. Compilation itself is the small part, around a tenth of a second.
    ///
    /// The cache is addressed by a digest of the model package, so a model that changes with a new
    /// release compiles itself again instead of loading a stale build, and earlier digests are
    /// dropped rather than accumulating.
    static func compiledBundledModel(in cacheRoot: URL? = nil) throws -> URL {
        guard let package = Bundle.module.url(forResource: bundledModelName, withExtension: "mlpackage") else {
            throw LayoutError.modelLoadFailed
        }

        do {
            let cacheRoot = try cacheRoot ?? defaultCacheRoot()

            let home = cacheRoot.appending(path: try digest(of: package), directoryHint: .isDirectory)
            let compiled = home.appending(path: "\(bundledModelName).mlmodelc", directoryHint: .isDirectory)
            let manifest = home.appending(path: "\(bundledModelName).manifest")
            if isIntact(compiled, manifest: manifest) { return compiled }

            // Whatever is there is not a whole model. Left in place it would be found again on
            // every later launch, so the bundled model would never load on this device again.
            try? FileManager.default.removeItem(at: compiled)
            try? FileManager.default.removeItem(at: manifest)

            let fresh = try MLModel.compileModel(at: package)
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

            // Arrive under a private name first. `fresh` is in a temporary directory, which may be
            // on another volume, and a move across volumes is a recursive copy rather than a
            // rename — so the destination exists, and is incomplete, for as long as the copy runs.
            // Under a private name nobody else can mistake that for a finished model.
            let staging = home.appending(path: "\(UUID().uuidString).partial", directoryHint: .isDirectory)
            try FileManager.default.moveItem(at: fresh, to: staging)
            do {
                // Same directory, so this one is a rename: it either happens or it does not.
                try FileManager.default.moveItem(at: staging, to: compiled)
                try writeManifest(for: compiled, to: manifest)
            } catch {
                try? FileManager.default.removeItem(at: staging)
                // Someone else may have finished the same compilation while this one was running.
                // Only a copy that is whole counts as theirs; anything else is wreckage, and is
                // cleared so the next attempt builds it again.
                guard isIntact(compiled, manifest: manifest) else {
                    try? FileManager.default.removeItem(at: compiled)
                    try? FileManager.default.removeItem(at: manifest)
                    throw error
                }
            }
            discardCompilations(in: cacheRoot, keeping: home)
            return compiled
        } catch {
            throw LayoutError.modelCompilationFailed(error.localizedDescription)
        }
    }

    /// Where compiled models are kept when the caller does not say.
    private static func defaultCacheRoot() throws -> URL {
        try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        .appending(path: "swift-document-scanner", directoryHint: .isDirectory)
        .appending(path: "CompiledModels", directoryHint: .isDirectory)
    }

    /// Whether everything written into the cache is still there.
    ///
    /// **`fileExists` on the directory is not this question.** It is true of an empty directory,
    /// and of one missing the file CoreML needs most — and a cache guarded by it alone serves the
    /// wreckage of one failed write for the life of the install, because the path never changes.
    ///
    /// Nor is checking one well-known file enough. A `.mlmodelc` missing `model.mil` or its
    /// `weights` still has `coremldata.bin`, and CoreML does not refuse that: **it segmentation
    /// faults.** The store this sits in is the caches directory, which the system empties file by
    /// file rather than tree by tree, so a model with a hole in it is a state to expect.
    ///
    /// So the manifest written beside the model records what was there when it was written, and
    /// every entry has to still exist. Nothing here knows what CoreML's layout is, which is what
    /// keeps it right when that layout changes.
    private static func isIntact(_ compiled: URL, manifest: URL) -> Bool {
        guard let listing = try? String(contentsOf: manifest, encoding: .utf8) else { return false }
        let paths = listing.split(separator: "\n").map(String.init)
        guard !paths.isEmpty else { return false }
        return paths.allSatisfy { FileManager.default.fileExists(atPath: compiled.appending(path: $0).path) }
    }

    /// Records every path inside the freshly compiled model, so a later launch can tell a complete
    /// copy from one the system has taken pieces out of.
    private static func writeManifest(for compiled: URL, to manifest: URL) throws {
        let paths = try FileManager.default.subpathsOfDirectory(atPath: compiled.path).sorted()
        try paths.joined(separator: "\n").write(to: manifest, atomically: true, encoding: .utf8)
    }

    /// Identifies a model package by its contents: every file's path and bytes, in a fixed order.
    private static func digest(of package: URL) throws -> String {
        var hasher = SHA256()
        let files = try FileManager.default
            .subpathsOfDirectory(atPath: package.path)
            .sorted()
        for path in files {
            let file = package.appending(path: path)
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            hasher.update(data: Data(path.utf8))
            hasher.update(data: try Data(contentsOf: file, options: .mappedIfSafe))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Removes compilations of models this build no longer uses, so an update does not leave the
    /// previous release's copy behind for good.
    private static func discardCompilations(in root: URL, keeping current: URL) {
        let others = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        for other in others where other.lastPathComponent != current.lastPathComponent {
            try? FileManager.default.removeItem(at: other)
        }
    }

    // MARK: - Analysis

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

        let all = Self.decodeYOLOOutput(
            multiArray: multiArray,
            confidenceThreshold: configuration.confidenceThreshold,
            inputSize: configuration.inputSize
        )
        // Cap to maximumDetections, preferring highest-confidence detections.
        return Array(all.sorted { $0.confidence > $1.confidence }.prefix(configuration.maximumDetections))
    }

    // MARK: - Private — YOLO Output Decoding

    /// Decode raw YOLO output tensor [1, numClasses+4, numPredictions] into LayoutElements.
    ///
    /// Static and free of instance state, so the arithmetic between the tensor and a
    /// ``LayoutElement`` can be pinned from a tensor built in a test, with no model to run.
    static func decodeYOLOOutput(
        multiArray: MLMultiArray,
        confidenceThreshold: Float,
        inputSize: Int
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

        let inputSize = Float(inputSize)

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

            // Clip each edge to the page independently. **Moving an edge in has to take the width
            // with it**: pulling `x` up to 0 while keeping the model's width slides the far edge
            // outward, so a header or a full-width block that the model puts a little past the
            // margin — which is most of them — comes back wider than it is.
            let left = max(0, normX)
            let top = max(0, normY)
            let right = min(1, normX + normW)
            let bottom = min(1, normY + normH)

            let box = CGRect(
                x: left,
                y: top,
                width: max(0, right - left),
                height: max(0, bottom - top)
            )

            let element = LayoutElement(
                category: category,
                boundingBox: box,
                confidence: bestScore
            )
            candidates.append((element, bestScore))
        }

        // Apply Non-Maximum Suppression per class
        return applyNMS(candidates: candidates, iouThreshold: nmsIoUThreshold)
    }

    // MARK: - Private — NMS

    private static func applyNMS(
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

    private static func iou(_ a: CGRect, _ b: CGRect) -> Float {
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
