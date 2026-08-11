// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-document-scanner",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "DocumentDetection", targets: ["DocumentDetection"]),
        .library(name: "DocumentOCR", targets: ["DocumentOCR"]),
        .library(name: "DocumentCamera", targets: ["DocumentCamera"]),
        .library(name: "DocumentLayout", targets: ["DocumentLayout"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", .upToNextMajor(from: "1.4.0")),
    ],
    targets: [
        // The shared image-decoding foundation. **Deliberately not a product** — it is not API for
        // consumers, only the guarantee that OCR and Layout open an image the same way.
        // It is a separate target because handling that fails silently when you get it wrong, such
        // as EXIF orientation, must not be duplicated: one copy would end up fixed and the other not.
        .target(name: "DocumentImaging"),
        .target(name: "DocumentDetection"),
        .target(
            name: "DocumentOCR",
            dependencies: ["DocumentImaging"]
        ),
        .target(
            name: "DocumentCamera",
            dependencies: ["DocumentDetection"]
        ),
        .target(
            name: "DocumentLayout",
            dependencies: ["DocumentImaging"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DocumentImagingTests",
            dependencies: ["DocumentImaging"]
        ),
        .testTarget(
            name: "DocumentDetectionTests",
            dependencies: ["DocumentDetection"]
        ),
        .testTarget(
            name: "DocumentOCRTests",
            dependencies: ["DocumentOCR"]
        ),
        .testTarget(
            name: "DocumentCameraTests",
            dependencies: ["DocumentCamera"]
        ),
        .testTarget(
            name: "DocumentLayoutTests",
            // DocumentImaging is here so the orientation tests can build a photo the way a camera
            // stores one — pixels lying down, orientation recorded beside them.
            dependencies: ["DocumentLayout", "DocumentImaging"]
        ),
    ]
)
