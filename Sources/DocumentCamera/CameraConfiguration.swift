import Foundation

/// ドキュメントカメラキャプチャサービスの設定。
public struct CameraConfiguration: Sendable {
    /// 自動ズーム計算に使用する書類の最小幅（ミリメートル）。
    public var minimumDocumentWidth: Float

    /// 書類がプレビューを占める目標割合（0.0〜1.0）。
    public var previewFillPercentage: Float

    /// キャプチャフレームの JPEG 圧縮品質（0.0〜1.0）。
    public var jpegCompressionQuality: CGFloat

    public init(
        minimumDocumentWidth: Float = 100,
        previewFillPercentage: Float = 0.8,
        jpegCompressionQuality: CGFloat = 0.9
    ) {
        self.minimumDocumentWidth = minimumDocumentWidth
        self.previewFillPercentage = previewFillPercentage
        self.jpegCompressionQuality = jpegCompressionQuality
    }
}

// MARK: - Presets

extension CameraConfiguration {
    /// レシートスキャン向け最適化設定（100mm 幅、80% フィル）。
    public static let receipt = CameraConfiguration(
        minimumDocumentWidth: 100,
        previewFillPercentage: 0.8,
        jpegCompressionQuality: 0.9
    )

    /// 書籍ページスキャン向け最適化設定（200mm 幅、90% フィル、高画質）。
    public static let bookPage = CameraConfiguration(
        minimumDocumentWidth: 200,
        previewFillPercentage: 0.9,
        jpegCompressionQuality: 0.95
    )

    /// A4 書類スキャン向け最適化設定（210mm 幅、90% フィル）。
    public static let a4Document = CameraConfiguration(
        minimumDocumentWidth: 210,
        previewFillPercentage: 0.9,
        jpegCompressionQuality: 0.9
    )
}
