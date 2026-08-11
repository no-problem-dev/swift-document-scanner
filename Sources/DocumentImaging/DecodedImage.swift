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
/// There are two ways to fix it, and this type offers both. **Passing the orientation along is
/// the cheaper one and the default**: Vision accepts an orientation through
/// `VNImageRequestHandler(cgImage:orientation:options:)`, so nothing has to be turned — rotating
/// costs memory and time, and re-encoding costs quality on top.
///
/// A consumer that has nowhere to put the orientation takes the other one, ``upright``, which
/// turns the pixels. CoreML is such a consumer: an `MLFeatureValue` built from a pixel buffer
/// carries pixels and nothing else, so an orientation held alongside them has no way in and is
/// lost. Whichever of the two a caller needs, **neither is "ignore the orientation"** — that is
/// the failure this type exists to prevent.
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

// MARK: - Turning the pixels

extension DecodedImage {
    /// The same picture with ``orientation`` applied to the pixels, so it can be looked at — or
    /// measured — without carrying the orientation any further.
    ///
    /// This is for the consumers that have nowhere to put an orientation, CoreML above all: pixel
    /// buffers carry pixels only. It is also what makes the geometry that comes back mean what it
    /// looks like. A box reported against unrotated pixels is expressed in a frame lying on its
    /// side, so "the top of the page" in the result is not the top of the page.
    ///
    /// Prefer handing ``orientation`` to whatever will read the image when it accepts one, as
    /// Vision does: turning the pixels allocates a second image and costs a redraw.
    ///
    /// `.up` returns the original image untouched — there is nothing to turn, and copying it
    /// would only cost memory.
    ///
    /// - Returns: The upright pixels, or `nil` when a bitmap context to redraw into cannot be
    ///   made. **Nil is never the original image**: silently handing back sideways pixels is the
    ///   bug this whole type exists to prevent, so the caller has to decide what to do.
    public var upright: CGImage? {
        Self.applying(orientation, to: cgImage)
    }

    /// Redraws `image` as though `orientation` had been applied to it.
    ///
    /// The eight cases are EXIF's, and each is one affine map from the stored pixel rectangle onto
    /// the upright one — the four turns, and each of them mirrored. The quarter turns swap width
    /// and height; the rest keep them.
    ///
    /// Interpolation is off: every case is a multiple of 90° with no scaling, so each source pixel
    /// lands exactly on a destination pixel and resampling would only blur it.
    static func applying(
        _ orientation: CGImagePropertyOrientation,
        to image: CGImage
    ) -> CGImage? {
        guard orientation != .up else { return image }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        let quarterTurned: Bool
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored: quarterTurned = true
        default: quarterTurned = false
        }

        // The transform maps the stored rectangle into the upright one, in CoreGraphics user
        // space — y upwards, so the stored image's top edge sits at y = height.
        let transform: CGAffineTransform
        switch orientation {
        case .up:
            transform = .identity
        case .upMirrored:
            transform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0)
        case .down:
            transform = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height)
        case .downMirrored:
            transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        case .left:
            transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: height, ty: 0)
        case .leftMirrored:
            transform = CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: height, ty: width)
        case .right:
            transform = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: width)
        case .rightMirrored:
            transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        @unknown default:
            return nil
        }

        guard let context = CGContext(
            data: nil,
            width: quarterTurned ? image.height : image.width,
            height: quarterTurned ? image.width : image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.concatenate(transform)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }
}
