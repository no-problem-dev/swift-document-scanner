import Foundation

/// Errors that can occur during document layout analysis.
public enum LayoutError: Error, LocalizedError, Sendable {
    /// The CoreML model could not be loaded.
    case modelLoadFailed
    /// The input image could not be processed.
    case invalidImage
    /// The Vision request failed.
    case detectionFailed(String)
    /// The CoreML model compilation failed.
    case modelCompilationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            "Failed to load the document layout model"
        case .invalidImage:
            "The provided image could not be processed"
        case .detectionFailed(let message):
            "Layout detection failed: \(message)"
        case .modelCompilationFailed(let message):
            "Model compilation failed: \(message)"
        }
    }
}
