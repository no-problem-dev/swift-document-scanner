import DocumentLayout
import DocumentOCR

/// What `PageReaderImpl` does to a picture before and after reading it.
///
/// Every step is named explicitly, so nothing is switched on behind the caller's back.
public struct PageReadingConfiguration: Sendable {
    /// Whether to find and flatten the document's outline first.
    public var cropping: PageCropping

    /// Whether to turn a page photographed on its side or upside down the right way up.
    public var correctsRotation: Bool

    /// The recogniser's languages and settings.
    public var ocr: OCRConfiguration

    /// The layout model's settings, or nil to skip layout analysis and leave every line's region
    /// unset.
    public var layout: LayoutConfiguration?

    public init(
        cropping: PageCropping,
        correctsRotation: Bool,
        ocr: OCRConfiguration,
        layout: LayoutConfiguration?
    ) {
        self.cropping = cropping
        self.correctsRotation = correctsRotation
        self.ocr = ocr
        self.layout = layout
    }
}

extension PageReadingConfiguration {
    /// A photo of an open book: no outline detection, rotation corrected, Japanese first, layout on.
    public static let bookPhoto = PageReadingConfiguration(
        cropping: .none,
        correctsRotation: true,
        ocr: .japanese,
        layout: .bookPage
    )

    /// A single sheet with its corners in view: outline detected and flattened, rotation corrected.
    public static let flatDocument = PageReadingConfiguration(
        cropping: .detectedDocument,
        correctsRotation: true,
        ocr: .japanese,
        layout: .default
    )
}
