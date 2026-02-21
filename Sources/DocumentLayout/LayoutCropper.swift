import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Crops detected layout elements from source images.
public enum LayoutCropper {
    /// Crop a region from a CGImage using normalized coordinates (top-left origin).
    /// - Parameters:
    ///   - cgImage: Source image to crop from.
    ///   - boundingBox: Normalized bounding box (0.0-1.0, top-left origin).
    ///   - padding: Extra padding ratio to add around the crop (0.0-1.0).
    /// - Returns: Cropped CGImage, or nil if cropping fails.
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
    /// Crop and return as PNG data.
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
