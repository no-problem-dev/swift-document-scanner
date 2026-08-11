import CoreImage
import Foundation
import os
@preconcurrency import Vision

// MARK: - RectangleCorners + VNRectangleObservation

extension RectangleCorners {
    init(_ observation: VNRectangleObservation) {
        self.init(
            topLeft: observation.topLeft,
            topRight: observation.topRight,
            bottomLeft: observation.bottomLeft,
            bottomRight: observation.bottomRight
        )
    }

    /// Blends a new observation into these corners with an exponential moving average, where the
    /// factor is the weight given to the new observation.
    func smoothed(with observation: VNRectangleObservation, factor alpha: CGFloat) -> RectangleCorners {
        func smooth(_ current: CGPoint, _ previous: CGPoint) -> CGPoint {
            CGPoint(
                x: alpha * current.x + (1 - alpha) * previous.x,
                y: alpha * current.y + (1 - alpha) * previous.y
            )
        }
        return RectangleCorners(
            topLeft: smooth(observation.topLeft, topLeft),
            topRight: smooth(observation.topRight, topRight),
            bottomLeft: smooth(observation.bottomLeft, bottomLeft),
            bottomRight: smooth(observation.bottomRight, bottomRight)
        )
    }
}

// MARK: - Protocol

/// Finds the outline of a document, both in a live camera stream and in a single still.
///
/// The two entry points differ in more than the input type: the streaming one carries state
/// across frames — smoothing and stillness — while the still one remembers nothing.
public protocol RectangleDetectionService: AnyObject, Sendable {
    /// Runs detection on one camera frame, updating the smoothing and the stability clock.
    ///
    /// A frame with no usable document throws away everything accumulated so far, so stability
    /// restarts from zero rather than picking up where it left off.
    func process(_ pixelBuffer: CVPixelBuffer) -> FrameDetectionResult

    /// Detects the document outline in a still image, touching no state at all.
    ///
    /// The observation comes back only if it clears the confidence, area and edge-margin checks;
    /// otherwise the answer is nil, with no way to tell which check turned it down.
    func detect(in cgImage: CGImage) -> VNRectangleObservation?

    /// Forgets the smoothed corners and the stability clock so the next frame starts fresh.
    ///
    /// Call it after capturing, or the next frames will still be counted as the same held-still
    /// document and fire another automatic capture immediately.
    func reset()
}

// MARK: - Implementation

/// The default detector, built on Vision's document segmentation request.
///
/// Segmentation looks for a document rather than for four straight lines, so it copes with a page
/// whose edge is partly hidden, and it can equally return a confident quadrilateral around
/// something that is not paper — the checks in the configuration are what keep those out.
///
/// State is guarded by a lock rather than by actor isolation because the camera calls this from
/// its video output queue, where suspending is not an option. Detection itself runs synchronously
/// on the calling thread.
public final class RectangleDetectionServiceImpl: RectangleDetectionService, @unchecked Sendable {
    private let configuration: DetectionConfiguration

    private struct State {
        var referenceRectangle: VNRectangleObservation?
        var stableStartTime: Date?
        var consecutiveStableFrameCount: Int = 0
        var smoothedCorners: RectangleCorners?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public init(configuration: DetectionConfiguration) {
        self.configuration = configuration
    }

    public func process(_ pixelBuffer: CVPixelBuffer) -> FrameDetectionResult {
        let observation = performDocumentDetection(
            handler: VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        )

        return state.withLock { state in
            guard let observation else {
                state = State()
                return FrameDetectionResult(
                    smoothedCorners: nil,
                    stability: 0,
                    shouldAutoCapture: false
                )
            }

            if let existing = state.smoothedCorners {
                state.smoothedCorners = existing.smoothed(with: observation, factor: configuration.smoothingFactor)
            } else {
                state.smoothedCorners = RectangleCorners(observation)
            }

            var stability: Double = 0
            var shouldAutoCapture = false

            if let reference = state.referenceRectangle {
                let isStable = isRectangleStable(observation, reference: reference)

                if isStable {
                    state.consecutiveStableFrameCount += 1

                    if state.consecutiveStableFrameCount >= configuration.minimumStableFrameCount {
                        if state.stableStartTime == nil {
                            state.stableStartTime = Date()
                        }

                        let stableDuration = Date().timeIntervalSince(state.stableStartTime!)
                        stability = min(stableDuration / configuration.stabilityThreshold, 1.0)

                        if stableDuration >= configuration.stabilityThreshold {
                            shouldAutoCapture = true
                        }
                    }
                } else {
                    state.stableStartTime = nil
                    state.consecutiveStableFrameCount = 0
                    stability = 0
                }
            }

            state.referenceRectangle = observation

            return FrameDetectionResult(
                smoothedCorners: state.smoothedCorners,
                stability: stability,
                shouldAutoCapture: shouldAutoCapture
            )
        }
    }

    public func reset() {
        state.withLock { $0 = State() }
    }

    public func detect(in cgImage: CGImage) -> VNRectangleObservation? {
        performDocumentDetection(
            handler: VNImageRequestHandler(cgImage: cgImage, options: [:])
        )
    }

    // MARK: - Private Methods

    private func performDocumentDetection(handler: VNImageRequestHandler) -> VNRectangleObservation? {
        var detectedObservation: VNRectangleObservation?

        let request = VNDetectDocumentSegmentationRequest { request, _ in
            detectedObservation = request.results?.first as? VNRectangleObservation
        }

        try? handler.perform([request])

        guard let observation = detectedObservation,
              isValidRectangle(observation) else {
            return nil
        }

        return observation
    }

    private func isRectangleStable(
        _ current: VNRectangleObservation,
        reference: VNRectangleObservation
    ) -> Bool {
        let corners = [
            (current.topLeft, reference.topLeft),
            (current.topRight, reference.topRight),
            (current.bottomLeft, reference.bottomLeft),
            (current.bottomRight, reference.bottomRight),
        ]

        for (currentCorner, referenceCorner) in corners {
            let dx = abs(currentCorner.x - referenceCorner.x)
            let dy = abs(currentCorner.y - referenceCorner.y)
            if dx > configuration.positionThreshold || dy > configuration.positionThreshold {
                return false
            }
        }

        return true
    }

    private func isValidRectangle(_ observation: VNRectangleObservation) -> Bool {
        if observation.confidence < configuration.minimumConfidence {
            return false
        }

        let area = calculateRectangleArea(observation)
        if area > configuration.maximumRectangleAreaRatio {
            return false
        }

        let margin = configuration.minimumEdgeMargin
        let corners = [
            observation.topLeft,
            observation.topRight,
            observation.bottomLeft,
            observation.bottomRight,
        ]

        for corner in corners {
            if corner.x < margin || corner.x > (1.0 - margin) ||
                corner.y < margin || corner.y > (1.0 - margin)
            {
                return false
            }
        }

        return true
    }

    /// Shoelace formula for area calculation in normalized coordinates (0.0-1.0).
    private func calculateRectangleArea(_ observation: VNRectangleObservation) -> CGFloat {
        let corners = [
            observation.bottomLeft,
            observation.bottomRight,
            observation.topRight,
            observation.topLeft,
        ]

        var area: CGFloat = 0
        for i in 0..<4 {
            let j = (i + 1) % 4
            area += corners[i].x * corners[j].y
            area -= corners[j].x * corners[i].y
        }

        return abs(area) / 2.0
    }
}
