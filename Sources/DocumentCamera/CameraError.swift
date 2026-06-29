import Foundation

/// カメラキャプチャ操作で発生するエラー。
public enum CameraError: Error, LocalizedError, Sendable {
    /// 画像データを取得できなかった。
    case imageDataNotAvailable

    public var errorDescription: String? {
        switch self {
        case .imageDataNotAvailable:
            "Image data not available"
        }
    }
}
