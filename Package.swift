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
        // 画像データを開く共通部分。**product にしない**（利用者に見せる API ではなく、
        // OCR と Layout が同じ開き方をすることを保証するための内部の土台）。
        // 分けているのは、向きの扱いのような「間違えると静かに壊れる」処理が
        // 2 箇所に複製されると、片方だけ直る事故が起きるため。
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
            dependencies: ["DocumentLayout"]
        ),
    ]
)
