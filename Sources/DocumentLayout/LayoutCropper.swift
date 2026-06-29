import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// 書類レイアウト要素をソース画像から切り抜くユーティリティ。
public enum LayoutCropper {
    /// 正規化座標（0.0〜1.0、原点: 左上）を使って CGImage から領域を切り抜く。
    ///
    /// - Parameters:
    ///   - cgImage: 切り抜き元のソース画像。
    ///   - boundingBox: 正規化バウンディングボックス（0.0〜1.0、原点: 左上）。
    ///   - padding: 切り抜き領域に加える追加パディング比率（0.0〜1.0）。デフォルトは 0.02。
    /// - Returns: 切り抜いた CGImage。切り抜きに失敗した場合は nil。
    public static func crop(
        from cgImage: CGImage,
        boundingBox: CGRect,
        padding: CGFloat = 0.02
    ) -> CGImage? {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Apply padding
        let paddedBox = CGRect(
            x: max(0, boundingBox.origin.x - padding),
            y: max(0, boundingBox.origin.y - padding),
            width: min(1.0, boundingBox.width + padding * 2),
            height: min(1.0, boundingBox.height + padding * 2)
        )

        // Convert to pixel coordinates
        let pixelRect = CGRect(
            x: paddedBox.origin.x * imageWidth,
            y: paddedBox.origin.y * imageHeight,
            width: paddedBox.width * imageWidth,
            height: paddedBox.height * imageHeight
        ).integral

        // Minimum size check
        guard pixelRect.width >= 20 && pixelRect.height >= 20 else { return nil }

        return cgImage.cropping(to: pixelRect)
    }

    #if canImport(UIKit)
    /// 切り抜いた領域を PNG データとして返す。
    ///
    /// - Parameters:
    ///   - cgImage: 切り抜き元のソース画像。
    ///   - boundingBox: 正規化バウンディングボックス（0.0〜1.0、原点: 左上）。
    ///   - padding: 追加パディング比率（0.0〜1.0）。デフォルトは 0.02。
    /// - Returns: PNG 画像データ。切り抜きに失敗した場合は nil。
    public static func cropToPNG(
        from cgImage: CGImage,
        boundingBox: CGRect,
        padding: CGFloat = 0.02
    ) -> Data? {
        guard let cropped = crop(from: cgImage, boundingBox: boundingBox, padding: padding) else {
            return nil
        }
        return UIImage(cgImage: cropped).pngData()
    }
    #endif
}
