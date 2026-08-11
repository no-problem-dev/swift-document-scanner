import CoreML
import Foundation
import Testing
@testable import DocumentLayout

/// Pins what the compiled-model cache does when what it finds on disk is not a model.
///
/// The cache exists so the four seconds CoreML spends preparing a model from an unfamiliar path
/// are paid once. The risk that comes with it is that **a bad entry is permanent**: it is written
/// to a stable path, and every later launch finds it and hands it straight back.
@Suite("コンパイル済みモデルのキャッシュ")
struct CompiledModelCacheTests {

    private func makeRoot() throws -> URL {
        let root = URL.temporaryDirectory.appending(path: "cache-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("同じキャッシュからは二度目も読める")
    func servesTheSameCompiledModelAgain() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try DocumentLayoutServiceImpl.compiledBundledModel(in: root)
        _ = try MLModel(contentsOf: first)

        let second = try DocumentLayoutServiceImpl.compiledBundledModel(in: root)
        _ = try MLModel(contentsOf: second)

        #expect(first == second)
    }

    /// The state an interrupted move leaves behind: the `.mlmodelc` directory is there, the model
    /// inside it is not.
    ///
    /// `FileManager.fileExists` is true for an empty directory, so a cache guarded by nothing else
    /// hands that back on every launch afterwards — **the bundled model stops loading on that
    /// device for good**, and nothing an app can do at runtime recovers it.
    @Test("中身の無いキャッシュは作り直される")
    func rebuildsWhenTheCachedCopyIsEmpty() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let compiled = try DocumentLayoutServiceImpl.compiledBundledModel(in: root)
        for entry in try FileManager.default.contentsOfDirectory(at: compiled, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: entry)
        }

        let recovered = try DocumentLayoutServiceImpl.compiledBundledModel(in: root)
        _ = try MLModel(contentsOf: recovered)
    }

    /// Every shape of a copy with a hole in it, one file at a time.
    ///
    /// The caches directory is emptied by the system **file by file**, not tree by tree, so these
    /// are states to expect rather than curiosities. Losing `coremldata.bin` makes CoreML refuse
    /// the model; losing `model.mil` or `weights` makes it **segmentation fault** — so checking for
    /// one well-known file is not enough, and the check has to be that everything written is still
    /// there.
    @Test(
        "一部を失ったキャッシュは作り直される",
        arguments: ["coremldata.bin", "model.mil", "weights", "analytics"]
    )
    func rebuildsWhenTheCachedCopyLostAPiece(missing: String) throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let compiled = try DocumentLayoutServiceImpl.compiledBundledModel(in: root)
        try FileManager.default.removeItem(at: compiled.appending(path: missing))

        let recovered = try DocumentLayoutServiceImpl.compiledBundledModel(in: root)
        _ = try MLModel(contentsOf: recovered)
    }
}
