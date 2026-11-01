/// Whether the reader looks for the page's outline and flattens it before reading.
public enum PageCropping: Sendable, Equatable {
    /// Read the picture as it is.
    ///
    /// Right for photos of an open book: a spread, the fingers holding it and the desk under it
    /// make the outline Vision finds wrong more often than right, and a wrong crop cuts text off.
    case none

    /// Find the document's outline, correct its perspective, and read only what is inside.
    ///
    /// Right for a single sheet lying flat with its four corners visible. When no outline is
    /// found the whole picture is read, and `ReadPage.isCropped` says so.
    case detectedDocument
}
