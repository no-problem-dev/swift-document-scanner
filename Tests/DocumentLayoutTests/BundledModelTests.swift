import Foundation
import Testing
@testable import DocumentLayout

/// The bundled model has to survive the build, under the build everyone gets.
///
/// `DocumentLayout` has one headline feature and it needs the model: a package whose
/// ``DocumentLayoutServiceImpl`` cannot be constructed after `swift build` does not work at all for
/// anyone who simply adds the dependency. Nothing else in this suite notices — every other test
/// either avoids the model or steps aside when it is missing, which is how a package can be green
/// and unusable at the same time.
@Suite("Bundled model")
struct BundledModelTests {
    @Test("同梱モデルは素の swift build でも読み込め、サービスが構築できる")
    func serviceConstructsFromTheBundledModel() throws {
        _ = try DocumentLayoutServiceImpl()
    }

    /// The resource has to arrive as the model package it is, not as its contents strewn about.
    ///
    /// An `.mlpackage` is a directory whose layout is the file format; a build rule that flattens
    /// it leaves the individual files present and the model gone, which is why the failure shows up
    /// as "resource missing" rather than as anything about the copy.
    @Test("同梱モデルは .mlpackage のディレクトリ構造のまま bundle に入る")
    func modelPackageKeepsItsDirectoryStructure() throws {
        let url = try #require(Bundle.module.url(forResource: "YOLOv12nDocLayNet", withExtension: "mlpackage"))

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        // The parts the format is made of, which flattening would have scattered into the bundle root.
        #expect(FileManager.default.fileExists(atPath: url.appending(path: "Manifest.json").path))
        #expect(FileManager.default.fileExists(
            atPath: url.appending(path: "Data/com.apple.CoreML/model.mlmodel").path
        ))
    }
}
