import Foundation

/// The four sizes the YOLOv12-DocLayNet model comes in, as a table of facts about them.
///
/// **Only the smallest ships inside this package, and nothing here downloads or loads the
/// others.** No API takes a variant: the layout service either uses the bundled model or takes a
/// compiled model URL you supply. Use these cases to describe and choose between the sizes, and
/// obtain the files yourself.
public enum ModelVariant: String, Sendable, CaseIterable, Codable {
    /// The smallest model and the only one shipped inside this package, for speed over accuracy.
    case nano
    /// Roughly three times the size of nano for a couple of points of accuracy; supply it yourself.
    case small
    /// Twice the size of small again, for a fraction of a point more; supply it yourself.
    case medium
    /// The most accurate of the four, though barely ahead of medium; supply it yourself.
    case large

    /// The capitalised English label, which is not localised.
    public var displayName: String {
        switch self {
        case .nano: "Nano"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    /// Roughly how many megabytes the FP16 CoreML build takes, for budgeting a download.
    ///
    /// The figures are recorded here rather than measured from any file on disk.
    public var approximateSizeMB: Int {
        switch self {
        case .nano: 6
        case .small: 19
        case .medium: 41
        case .large: 54
        }
    }

    /// The mAP50-95 score published for this size on the DocLayNet benchmark.
    ///
    /// It is a quoted figure, not something this package measures, and the three larger sizes sit
    /// within about a point of each other — most of the gain is in the step up from nano.
    public var accuracy: Double {
        switch self {
        case .nano: 0.756
        case .small: 0.782
        case .medium: 0.788
        case .large: 0.792
        }
    }

    /// Whether the file ships inside this package, which is true of nano alone.
    public var isBundled: Bool {
        self == .nano
    }

    /// The file name, without extension, the model file is expected to carry.
    ///
    /// Only the nano name resolves against this package's resources; the others describe files
    /// you would obtain and compile yourself.
    public var modelFileName: String {
        switch self {
        case .nano: "YOLOv12nDocLayNet"
        case .small: "YOLOv12sDocLayNet"
        case .medium: "YOLOv12mDocLayNet"
        case .large: "YOLOv12lDocLayNet"
        }
    }
}
