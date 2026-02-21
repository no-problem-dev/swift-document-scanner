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

    /// Exponential moving average smoothing with a new observation.
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

/// Detects rectangular documents in camera frames and static images.
public protocol RectangleDetectionService: AnyObject, Sendable {
    /// Process a camera frame with smoothing and stability tracking.
    func process(_ pixelBuffer: CVPixelBuffer) -> FrameDetectionResult

    /// Single-shot detection on a static image (stateless).
    func detect(in cgImage: CGImage) -> VNRectangleObservation?

    /// Reset internal stability tracking state.
    func reset()
}

// MARK: - Implementation

/// Default implementation using VNDetectDocumentSegmentationRequest.
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
