import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Cuts detected regions out of the image they were found in.
public enum LayoutCropper {
    /// Cuts a normalised, top-left-origin region out of an image, with a margin around it.
    ///
    /// **The padding is a fraction of the whole image, not of the region**, and is added to every
    /// side, so the same value grows a small region proportionally far more than a large one.
    /// A padded region that runs past the right or bottom edge is clipped to the image rather
    /// than shifted back inside, so the result can be smaller than the padding implies.
    ///
    /// Anything that works out smaller than 20×20 pixels is refused rather than returned, which
    /// keeps unusable slivers out of the caller's hands.
    ///
    /// - Parameters:
    ///   - cgImage: The image the region was measured against. A different image, or the same one
    ///     rotated since, silently crops the wrong place.
    ///   - boundingBox: The region to cut, normalised 0 to 1 with the origin at the top left.
    ///   - padding: Extra margin on each side, as a fraction of the image.
    /// - Returns: The cropped image, or nil when it would be too small or lies outside the image.
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
    /// Crops the same way and encodes the result as PNG.
    ///
    /// PNG keeps the crop lossless, which matters when it is going straight back into text
    /// recognition. **Available only where UIKit is, so not on macOS** — the encoder is UIKit's.
    ///
    /// - Parameters:
    ///   - cgImage: The image the region was measured against.
    ///   - boundingBox: The region to cut, normalised 0 to 1 with the origin at the top left.
    ///   - padding: Extra margin on each side, as a fraction of the image.
    /// - Returns: PNG data, or nil when the crop was refused or the encoding failed.
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
