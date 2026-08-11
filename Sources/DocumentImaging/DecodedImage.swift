import CoreGraphics
import Foundation
import ImageIO

/// The pixels of a decoded image, paired with the orientation they are meant to be viewed at.
///
/// ## Orientation is not baked into the pixels
///
/// A JPEG or HEIC from a camera normally stores **the pixels unrotated, with the orientation
/// recorded as metadata**. Take the pixels without reading that metadata and a photo shot with
/// the device upright comes out lying on its side. Vision and CoreML only look at the pixel
/// grid, so they treat such an image as genuinely sideways — on something like a receipt, where
/// the direction of the characters decides the outcome, that is the whole read failing.
///
/// There are two ways to fix it, and this type takes **the one that passes the orientation
/// along instead of rotating**. Vision accepts an orientation through
/// `VNImageRequestHandler(cgImage:orientation:options:)`, so nothing has to be turned — rotating
/// costs memory and time, and re-encoding costs quality on top.
///
/// ## How the data is opened
///
/// ImageIO is used directly rather than `CIImage(data:)` plus `CIContext.createCGImage`.
/// A `CIContext` builds a GPU/CPU rendering context, which is heavy for merely opening data,
/// and ImageIO **reads the orientation metadata in the same single pass** — the file is never
/// opened a second time.
public struct DecodedImage {
    /// The decoded pixels, with the stored orientation deliberately **not** applied.
    ///
    /// Use it together with `orientation`; on its own it can be sideways.
    public let cgImage: CGImage

    /// How the pixels are meant to be viewed, defaulting to `.up` when the file said nothing.
    public let orientation: CGImagePropertyOrientation

    public init(cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) {
        self.cgImage = cgImage
        self.orientation = orientation
    }

    /// Opens JPEG, PNG, HEIC or any other data ImageIO can read, failing only if it is not an image.
    ///
    /// Missing or unrecognised orientation metadata is taken as `.up` rather than treated as a
    /// failure — not knowing the orientation is not the same as not being able to read the
    /// image, and most images really are `.up`.
    public init?(data: Data) {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = properties?[kCGImagePropertyOrientation] as? UInt32

        self.cgImage = image
        self.orientation = raw.flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
    }
}
