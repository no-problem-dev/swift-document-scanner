import Foundation
import Testing

@testable import DocumentLayout

@Suite("ModelVariant")
struct ModelVariantTests {
    @Test("All cases have display names")
    func displayNames() {
        for variant in ModelVariant.allCases {
            #expect(!variant.displayName.isEmpty)
        }
    }

    @Test("Accuracy increases with model size")
    func accuracyOrdering() {
        let ordered: [ModelVariant] = [.nano, .small, .medium, .large]
        for i in 0..<ordered.count - 1 {
            #expect(ordered[i].accuracy < ordered[i + 1].accuracy)
        }
    }

    @Test("Size increases with model size")
    func sizeOrdering() {
        let ordered: [ModelVariant] = [.nano, .small, .medium, .large]
        for i in 0..<ordered.count - 1 {
            #expect(ordered[i].approximateSizeMB < ordered[i + 1].approximateSizeMB)
        }
    }

    @Test("Only nano is bundled")
    func bundledVariant() {
        #expect(ModelVariant.nano.isBundled)
        #expect(!ModelVariant.small.isBundled)
        #expect(!ModelVariant.medium.isBundled)
        #expect(!ModelVariant.large.isBundled)
    }

    @Test("Model file names follow naming convention")
    func modelFileNames() {
        #expect(ModelVariant.nano.modelFileName == "YOLOv12nDocLayNet")
        #expect(ModelVariant.small.modelFileName == "YOLOv12sDocLayNet")
        #expect(ModelVariant.medium.modelFileName == "YOLOv12mDocLayNet")
        #expect(ModelVariant.large.modelFileName == "YOLOv12lDocLayNet")
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        for variant in ModelVariant.allCases {
            let data = try JSONEncoder().encode(variant)
            let decoded = try JSONDecoder().decode(ModelVariant.self, from: data)
            #expect(decoded == variant)
        }
    }

    @Test("All cases count")
    func allCasesCount() {
        #expect(ModelVariant.allCases.count == 4)
    }
}
