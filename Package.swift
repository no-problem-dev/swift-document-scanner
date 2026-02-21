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
        .target(name: "DocumentDetection"),
        .target(name: "DocumentOCR"),
        .target(
            name: "DocumentCamera",
            dependencies: ["DocumentDetection"]
        ),
        .target(
            name: "DocumentLayout",
            resources: [.process("Resources")]
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
            dependencies: ["DocumentLayout"]
        ),
    ]
)
