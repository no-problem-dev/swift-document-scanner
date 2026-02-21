import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision

/// Applies perspective correction to extract a front-facing document image.
public enum PerspectiveCorrection {
    /// Corrects the perspective of a detected rectangle within an image.
    /// - Parameters:
    ///   - cgImage: The source image containing the document.
    ///   - observation: The detected rectangle observation from Vision.
    /// - Returns: A perspective-corrected image, or nil if correction fails.
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
