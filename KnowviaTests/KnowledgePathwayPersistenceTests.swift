import SwiftData
import XCTest
@testable import Knowvia

@MainActor
final class KnowledgePathwayPersistenceTests: XCTestCase {
    func testPersistsPathwayMetadataInMemory() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: KnowledgePathway.self,
            configurations: configuration
        )
        let context = container.mainContext
        let cardID = UUID()
        let candidateID = UUID()
        let pathway = KnowledgePathway(
            title: "认知负荷理论",
            overview: "梳理理论结构与应用边界。",
            tags: ["学习科学", "理论"],
            candidateDocumentIDs: [candidateID],
            knowledgeCardIDs: [cardID]
        )

        context.insert(pathway)
        try context.save()

        let pathways = try context.fetch(FetchDescriptor<KnowledgePathway>())
        XCTAssertEqual(pathways.count, 1)
        XCTAssertEqual(pathways.first?.title, "认知负荷理论")
        XCTAssertEqual(pathways.first?.overview, "梳理理论结构与应用边界。")
        XCTAssertEqual(pathways.first?.tags, ["学习科学", "理论"])
        XCTAssertEqual(pathways.first?.candidateDocumentIDs, [candidateID])
        XCTAssertEqual(pathways.first?.knowledgeCardIDs, [cardID])
    }
}
