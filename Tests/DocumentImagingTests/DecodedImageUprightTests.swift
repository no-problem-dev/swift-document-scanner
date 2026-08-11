import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import DocumentImaging

// MARK: - Helpers

/// Every pixel a different colour, so a wrong turn cannot come out looking right.
///
/// A flat or symmetric picture hides mirroring completely and hides rotation whenever the sides
/// happen to match, which is exactly the mistake being guarded against here. 4×8 also keeps the
/// two sides different lengths, so a quarter turn changes the dimensions and a half turn does not.
private func makeGradient(width: Int = 4, height: Int = 8) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    for row in 0..<height {
        for column in 0..<width {
            context.setFillColor(
                red: CGFloat(30 + column * 50) / 255,
                green: CGFloat(10 + row * 30) / 255,
                blue: 0.5,
                alpha: 1
            )
            // CoreGraphics counts y upwards; row 0 is the top of the picture.
            context.fill(CGRect(x: column, y: height - 1 - row, width: 1, height: 1))
        }
    }
    return context.makeImage()!
}

/// The pixels of an image, addressed the way a picture is read: column from the left, row from
/// the top.
private struct Bitmap {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(of image: CGImage) {
        let width = image.width
        let height = image.height
        self.width = width
        self.height = height
        var storage = [UInt8](repeating: 0, count: width * height * 4)
        storage.withUnsafeMutableBytes { raw in
            let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        bytes = storage
    }

    subscript(column: Int, row: Int) -> [UInt8] {
        let offset = (row * width + column) * 4
        return Array(bytes[offset..<(offset + 3)])
    }
}

/// Which stored pixel belongs at an upright position, read straight off the EXIF definitions
/// rather than off the implementation — otherwise the test would only restate the code.
///
/// EXIF states, for each value, which side of the picture the stored data's first row and first
/// column belong to; e.g. 6 (`.right`) is "first row is the right side, first column is the top".
private func storedLocation(
    ofUpright column: Int,
    _ row: Int,
    orientation: CGImagePropertyOrientation,
    storedWidth: Int,
    storedHeight: Int
) -> (column: Int, row: Int) {
    switch orientation {
    case .up: (column, row)
    case .upMirrored: (storedWidth - 1 - column, row)
    case .down: (storedWidth - 1 - column, storedHeight - 1 - row)
    case .downMirrored: (column, storedHeight - 1 - row)
    case .leftMirrored: (row, column)
    case .right: (row, storedHeight - 1 - column)
    case .rightMirrored: (storedWidth - 1 - row, storedHeight - 1 - column)
    case .left: (storedWidth - 1 - row, column)
    @unknown default: (column, row)
    }
}

private let quarterTurns: Set<CGImagePropertyOrientation> = [.left, .leftMirrored, .right, .rightMirrored]

// MARK: - Tests

@Suite("DecodedImage.upright Tests")
struct DecodedImageUprightTests {
    @Test(
        "8 通り全ての向きで、画素が正しい位置に来る",
        arguments: [
            CGImagePropertyOrientation.up,
            .upMirrored,
            .down,
            .downMirrored,
            .left,
            .leftMirrored,
            .right,
            .rightMirrored,
        ]
    )
    func placesEveryPixel(_ orientation: CGImagePropertyOrientation) throws {
        let stored = makeGradient()
        let decoded = DecodedImage(cgImage: stored, orientation: orientation)

        let upright = try #require(decoded.upright)
        let expectedWidth = quarterTurns.contains(orientation) ? stored.height : stored.width
        let expectedHeight = quarterTurns.contains(orientation) ? stored.width : stored.height
        #expect(upright.width == expectedWidth)
        #expect(upright.height == expectedHeight)

        let source = Bitmap(of: stored)
        let result = Bitmap(of: upright)
        for row in 0..<result.height {
            for column in 0..<result.width {
                let origin = storedLocation(
                    ofUpright: column, row,
                    orientation: orientation,
                    storedWidth: stored.width,
                    storedHeight: stored.height
                )
                #expect(
                    result[column, row] == source[origin.column, origin.row],
                    "(\(column), \(row)) should hold the stored pixel at (\(origin.column), \(origin.row))"
                )
            }
        }
    }

    @Test(".up は元の画像をそのまま返す（無駄な複製をしない）")
    func passesUpThrough() throws {
        let stored = makeGradient()
        let upright = try #require(DecodedImage(cgImage: stored, orientation: .up).upright)
        #expect(upright === stored)
    }

    /// The camera case end to end: a file that stores its pixels lying down and records that fact
    /// separately. Reading the file and asking for it upright has to give back a portrait picture.
    @Test("EXIF が回転を宣言したファイルは、開いてから起こせる")
    func uprightsFromFileMetadata() throws {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        )!
        CGImageDestinationAddImage(
            destination,
            makeGradient(width: 8, height: 4),
            [kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue] as CFDictionary
        )
        #expect(CGImageDestinationFinalize(destination))

        let decoded = try #require(DecodedImage(data: data as Data))
        #expect(decoded.cgImage.width == 8)
        #expect(decoded.cgImage.height == 4)

        let upright = try #require(decoded.upright)
        #expect(upright.width == 4)
        #expect(upright.height == 8)
    }
}
