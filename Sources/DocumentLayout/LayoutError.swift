import Foundation

/// 書類レイアウト解析で発生するエラー。
public enum LayoutError: Error, LocalizedError, Sendable {
    /// CoreML モデルのロードに失敗した。
    case modelLoadFailed
    /// 入力画像を処理できなかった。
    case invalidImage
    /// Vision リクエストが失敗した。
    case detectionFailed(String)
    /// CoreML モデルのコンパイルに失敗した。
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
