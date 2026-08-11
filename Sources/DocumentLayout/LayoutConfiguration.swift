import Foundation

/// The thresholds and input size one layout analysis pass runs with.
public struct LayoutConfiguration: Sendable {
    /// The lowest class score a region needs to survive, from 0 to 1.
    ///
    /// It is applied before overlapping boxes are merged, so lowering it adds work as well as
    /// results, and the extra results are the ones the model was least sure of.
    public var confidenceThreshold: Float

    /// The most regions one image may return.
    ///
    /// The cap is applied last and keeps the highest-scoring regions, so raising it only ever
    /// adds to what you already had.
    public var maximumDetections: Int

    /// The side length, in pixels, of the square the image is redrawn into for the model.
    ///
    /// The bundled model expects 640, and the same number converts the model's output back into
    /// normalised coordinates — changing it does not make a differently-sized model work, it
    /// misaligns the boxes. The image is stretched to a square, so aspect ratio is not preserved.
    public var inputSize: Int

    public init(
        confidenceThreshold: Float = 0.25,
        maximumDetections: Int = 100,
        inputSize: Int = 640
    ) {
        self.confidenceThreshold = confidenceThreshold
        self.maximumDetections = maximumDetections
        self.inputSize = inputSize
    }
}

// MARK: - Presets

extension LayoutConfiguration {
    /// General analysis: a score floor of 0.25 and up to 100 regions.
    public static let `default` = LayoutConfiguration()

    /// Pulling figures out of book pages, trading recall for fewer false positives.
    ///
    /// The score floor rises to 0.35 and the cap drops to 50, on the assumption that missing one
    /// figure costs less than cropping something that was not a figure.
    public static let bookPage = LayoutConfiguration(
        confidenceThreshold: 0.35,
        maximumDetections: 50
    )
}
