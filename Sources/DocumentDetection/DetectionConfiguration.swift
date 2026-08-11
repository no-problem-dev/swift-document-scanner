import Foundation

/// The thresholds that decide which detections count and when one has held still long enough.
public struct DetectionConfiguration: Sendable {
    /// How long the document must hold still, in seconds, before an automatic capture fires.
    ///
    /// The initialiser traps on anything that is not greater than zero.
    public var stabilityThreshold: TimeInterval

    /// How far a corner may drift between frames and still count as still, in normalised units.
    ///
    /// It is checked per axis against all four corners, so one corner moving further than this on
    /// either x or y throws away the stability built up so far.
    public var positionThreshold: CGFloat

    /// How many consecutive still frames must pass before the stability clock even starts.
    ///
    /// It filters out momentary coincidences: the seconds counted against the stability threshold
    /// begin only after this many frames in a row have qualified.
    public var minimumStableFrameCount: Int

    /// The largest share of the frame a detection may cover before it is thrown away.
    ///
    /// A quadrilateral filling almost the whole frame is usually the frame itself, or the desk,
    /// rather than a document. The area is the shoelace area of the four corners.
    public var maximumRectangleAreaRatio: CGFloat

    /// How far every corner must stay clear of the frame edges, in normalised units.
    ///
    /// A document touching the edge is probably cropped, so a single corner inside this margin
    /// rejects the whole detection.
    public var minimumEdgeMargin: CGFloat

    /// The lowest confidence Vision may report for a detection to be used at all.
    ///
    /// It is the segmentation request's own score for the whole shape, not a per-corner value.
    /// Anything below is discarded and reported as no document at all, so raising it makes the
    /// outline disappear rather than wobble.
    public var minimumConfidence: Float

    /// How much weight the newest frame gets when smoothing the drawn corners, from 0 to 1.
    ///
    /// At 1 the new corners are used as they are; lower values keep more of the previous position
    /// and move the outline more slowly. **It affects only the corners handed back for display**
    /// — stability is always judged on the raw detection.
    public var smoothingFactor: CGFloat

    public init(
        stabilityThreshold: TimeInterval,
        positionThreshold: CGFloat,
        minimumStableFrameCount: Int,
        maximumRectangleAreaRatio: CGFloat,
        minimumEdgeMargin: CGFloat,
        minimumConfidence: Float,
        smoothingFactor: CGFloat
    ) {
        precondition(stabilityThreshold > 0, "stabilityThreshold must be > 0")
        self.stabilityThreshold = stabilityThreshold
        self.positionThreshold = positionThreshold
        self.minimumStableFrameCount = minimumStableFrameCount
        self.maximumRectangleAreaRatio = maximumRectangleAreaRatio
        self.minimumEdgeMargin = minimumEdgeMargin
        self.minimumConfidence = minimumConfidence
        self.smoothingFactor = smoothingFactor
    }
}

// MARK: - Presets

extension DetectionConfiguration {
    /// General document scanning: two seconds of stillness, nothing over 85% of the frame.
    public static let `default` = DetectionConfiguration(
        stabilityThreshold: 2.0,
        positionThreshold: 0.03,
        minimumStableFrameCount: 8,
        maximumRectangleAreaRatio: 0.85,
        minimumEdgeMargin: 0.02,
        minimumConfidence: 0.5,
        smoothingFactor: 0.3
    )

    /// Receipts — tall, narrow paper. The values are currently identical to the general ones.
    ///
    /// It exists as a separate name so the receipt path can be tuned without moving the default
    /// underneath everything else. Choosing it today changes nothing about detection.
    public static let receipt = DetectionConfiguration(
        stabilityThreshold: 2.0,
        positionThreshold: 0.03,
        minimumStableFrameCount: 8,
        maximumRectangleAreaRatio: 0.85,
        minimumEdgeMargin: 0.02,
        minimumConfidence: 0.5,
        smoothingFactor: 0.3
    )

    /// Book pages: fires sooner than the default and lets a page fill almost the whole frame.
    ///
    /// Stillness is required for 1.5 seconds over 6 frames, up to 95% of the frame is allowed,
    /// and the confidence floor drops to 0.4 because a bound page has a softer edge than a
    /// loose sheet.
    public static let bookPage = DetectionConfiguration(
        stabilityThreshold: 1.5,
        positionThreshold: 0.04,
        minimumStableFrameCount: 6,
        maximumRectangleAreaRatio: 0.95,
        minimumEdgeMargin: 0.01,
        minimumConfidence: 0.4,
        smoothingFactor: 0.3
    )

    /// Two-page spreads: the most permissive set, for paper that runs right to the frame edge.
    ///
    /// 1.2 seconds of stillness, up to 98% of the frame, corners allowed within 0.5% of the edge,
    /// and confidence down to 0.3. Expect more false detections in return.
    public static let bookSpread = DetectionConfiguration(
        stabilityThreshold: 1.2,
        positionThreshold: 0.05,
        minimumStableFrameCount: 6,
        maximumRectangleAreaRatio: 0.98,
        minimumEdgeMargin: 0.005,
        minimumConfidence: 0.3,
        smoothingFactor: 0.25
    )
}
