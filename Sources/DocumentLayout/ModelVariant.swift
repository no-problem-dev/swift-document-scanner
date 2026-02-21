import Foundation

/// Available YOLOv12-DocLayNet model variants for document layout detection.
///
/// The `.nano` variant is bundled with the package. Larger variants offer
/// improved accuracy but must be downloaded separately.
public enum ModelVariant: String, Sendable, CaseIterable, Codable {
    case nano
    case small
    case medium
    case large

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .nano: "Nano"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    /// Approximate model size in megabytes (CoreML FP16).
    public var approximateSizeMB: Int {
        switch self {
        case .nano: 6
        case .small: 19
        case .medium: 41
        case .large: 54
        }
    }

    /// mAP50-95 accuracy on DocLayNet benchmark.
    public var accuracy: Double {
        switch self {
        case .nano: 0.756
        case .small: 0.782
        case .medium: 0.788
        case .large: 0.792
        }
    }

    /// Whether this variant is bundled with the package (no download needed).
    public var isBundled: Bool {
        self == .nano
    }

    /// CoreML model file name (without extension).
    public var modelFileName: String {
        switch self {
        case .nano: "YOLOv12nDocLayNet"
        case .small: "YOLOv12sDocLayNet"
        case .medium: "YOLOv12mDocLayNet"
        case .large: "YOLOv12lDocLayNet"
        }
    }
}
