import ImageIO

/// How far a picture has to be turned clockwise, in quarter turns, before its text stands upright.
public enum QuarterTurn: Int, Sendable, CaseIterable {
    case none = 0
    case clockwise = 1
    case halfTurn = 2
    case counterclockwise = 3

    /// The EXIF orientation that, recorded beside the pixels, means "turn them this far to view".
    public var orientation: CGImagePropertyOrientation {
        switch self {
        case .none: .up
        case .clockwise: .right
        case .halfTurn: .down
        case .counterclockwise: .left
        }
    }
}
