import Foundation

/// OCR 処理で発生するエラー。
public enum OCRError: Error, LocalizedError, Sendable {
    /// 画像データの読み込みに失敗した。
    case invalidImage
    /// テキスト認識処理が失敗した。
    case recognitionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            "Failed to load image"
        case .recognitionFailed(let message):
            "Text recognition failed: \(message)"
        }
    }
}
