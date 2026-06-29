import Foundation

/// 書類レイアウト検出に使用できる YOLOv12-DocLayNet モデルバリアント。
///
/// `.nano` バリアントはパッケージにバンドル済み。大きなバリアントは精度が高いが、別途ダウンロードが必要。
public enum ModelVariant: String, Sendable, CaseIterable, Codable {
    /// 最軽量モデル（約 6 MB）。パッケージにバンドル済みで追加ダウンロード不要。速度優先の用途向け。
    case nano
    /// ナノより高精度な小型モデル（約 19 MB）。別途ダウンロードが必要。
    case small
    /// 精度と速度のバランス型モデル（約 41 MB）。別途ダウンロードが必要。
    case medium
    /// 最高精度モデル（約 54 MB）。別途ダウンロードが必要。
    case large

    /// モデルの表示名。
    public var displayName: String {
        switch self {
        case .nano: "Nano"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    /// CoreML FP16 での推定モデルサイズ（メガバイト）。
    public var approximateSizeMB: Int {
        switch self {
        case .nano: 6
        case .small: 19
        case .medium: 41
        case .large: 54
        }
    }

    /// DocLayNet ベンチマークでの mAP50-95 精度スコア。
    public var accuracy: Double {
        switch self {
        case .nano: 0.756
        case .small: 0.782
        case .medium: 0.788
        case .large: 0.792
        }
    }

    /// パッケージにバンドルされているか（追加ダウンロード不要かどうか）。
    public var isBundled: Bool {
        self == .nano
    }

    /// CoreML モデルファイル名（拡張子なし）。
    public var modelFileName: String {
        switch self {
        case .nano: "YOLOv12nDocLayNet"
        case .small: "YOLOv12sDocLayNet"
        case .medium: "YOLOv12mDocLayNet"
        case .large: "YOLOv12lDocLayNet"
        }
    }
}
