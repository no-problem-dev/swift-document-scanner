import CoreGraphics
import Foundation

/// The four corners of a detected quadrilateral, in Vision's normalised coordinate space.
///
/// Both axes run 0 to 1 with the origin at the **bottom left**, which is upside down relative to
/// SwiftUI and UIKit — anything drawing these has to flip y. Nothing guarantees the shape is a
/// true rectangle: a page photographed at an angle gives four corners that do not form right
/// angles.
public struct RectangleCorners: Sendable, Equatable {
    /// The upper-left corner, whose y is one of the two larger values.
    public let topLeft: CGPoint
    /// The upper-right corner, whose y is one of the two larger values.
    public let topRight: CGPoint
    /// The lower-left corner, whose y is one of the two smaller values.
    public let bottomLeft: CGPoint
    /// The lower-right corner, whose y is one of the two smaller values.
    public let bottomRight: CGPoint

    public init(
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}
