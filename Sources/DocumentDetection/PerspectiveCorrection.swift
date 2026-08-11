import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision

/// Flattens a document photographed at an angle into a straight-on image of just that document.
public enum PerspectiveCorrection {
    /// Warps the four detected corners onto a rectangle, straightening and cropping the page.
    ///
    /// **The result is a different size from the source.** Its dimensions come from the corrected
    /// quadrilateral, so it is generally smaller than the frame it was cut from — the surroundings
    /// are gone and the document has been resampled. The corner mapping also takes out the
    /// rotation of the quadrilateral itself, so a page shot sideways comes back upright.
    ///
    /// **Orientation metadata is never consulted.** The pixels are used exactly as given, and the
    /// normalised corners are read in the same bottom-left-origin space Core Image uses. Pass
    /// pixels and corners that came from the same, unrotated image.
    ///
    /// - Parameters:
    ///   - cgImage: The image the document was detected in.
    ///   - observation: The quadrilateral Vision found in that same image.
    /// - Returns: The straightened document, or nil if Core Image could not render it.
    public static func correct(cgImage: CGImage, observation: VNRectangleObservation) -> CGImage? {
        let ciImage = CIImage(cgImage: cgImage)
        let imageSize = ciImage.extent.size

        let topLeft = CGPoint(
            x: observation.topLeft.x * imageSize.width,
            y: observation.topLeft.y * imageSize.height
        )
        let topRight = CGPoint(
            x: observation.topRight.x * imageSize.width,
            y: observation.topRight.y * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: observation.bottomLeft.x * imageSize.width,
            y: observation.bottomLeft.y * imageSize.height
        )
        let bottomRight = CGPoint(
            x: observation.bottomRight.x * imageSize.width,
            y: observation.bottomRight.y * imageSize.height
        )

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = topLeft
        filter.topRight = topRight
        filter.bottomLeft = bottomLeft
        filter.bottomRight = bottomRight

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
}
