import Foundation

/// The failures layout analysis reports.
///
/// They do not cover everything that can go wrong: CoreML's own load and prediction errors are
/// passed through untouched rather than wrapped in one of these cases.
public enum LayoutError: Error, LocalizedError, Sendable {
    /// The bundled model file was not found among the package resources.
    ///
    /// It means the resource is missing from the build, not that CoreML rejected the model —
    /// a model that is present but unloadable surfaces as a CoreML error instead.
    case modelLoadFailed
    /// The image could not be redrawn into the square buffer the model takes as input.
    case invalidImage
    /// The model ran, but its output could not be read as a tensor.
    ///
    /// The payload names what was missing. A failure inside the prediction itself does not come
    /// back as this case.
    case detectionFailed(String)
    /// Turning a model package into a loadable compiled model failed; the payload says why.
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
