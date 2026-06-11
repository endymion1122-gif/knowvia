import SwiftData
import XCTest
@testable import Knowvia

final class KnowledgeRelationServiceTests: XCTestCase {
    private let service = KnowledgeRelationService()

    func testRejectsSameNodeAndDuplicateRelation() throws {
        let pathwayID = UUID()
        let sourceID = UUID()
        let targetID = UUID()

        XCTAssertThrowsError(
            try service.makeRelation(
                pathwayID: pathwayID,
                sourceCardID: sourceID,
                targetCardID: sourceID,
                kind: .defines,
                existingRelations: []
            )
        )

        let existing = try service.makeRelation(
            pathwayID: pathwayID,
            sourceCardID: sourceID,
            targetCardID: targetID,
            kind: .supports,
            existingRelations: []
        )

        XCTAssertThrowsError(
            try service.makeRelation(
                pathwayID: pathwayID,
                sourceCardID: sourceID,
                targetCardID: targetID,
                kind: .supports,
                existingRelations: [existing]
            )
        )
    }

    func testBuildsClaimEvidencePairsFromSupportRelation() throws {
        let pathway = KnowledgePathway(title: "认知负荷理论")
        let claim = makeCard(title: "分段呈现可降低外在负荷", kind: .argument)
        let evidence = makeCard(title: "实验组保持率更高", kind: .evidence)
        let relation = try service.makeRelation(
            pathwayID: pathway.id,
            sourceCardID: evidence.id,
            targetCardID: claim.id,
            kind: .supports,
            existingRelations: []
        )

        let pairs = service.claimEvidencePairs(
            for: pathway,
            relations: [relation],
            cards: [claim, evidence]
        )

        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.claim.id, claim.id)
        XCTAssertEqual(pairs.first?.evidence.id, evidence.id)
    }

    func testFiltersRelationsByPathwayAndCard() throws {
        let firstPathway = KnowledgePathway(title: "第一条路径")
        let secondPathway = KnowledgePathway(title: "第二条路径")
        let source = makeCard(title: "概念", kind: .concept)
        let target = makeCard(title: "观点", kind: .argument)
        let first = try service.makeRelation(
            pathwayID: firstPathway.id,
            sourceCardID: source.id,
            targetCardID: target.id,
            kind: .defines,
            existingRelations: []
        )
        let second = try service.makeRelation(
            pathwayID: secondPathway.id,
            sourceCardID: target.id,
            targetCardID: source.id,
            kind: .relatedTo,
            existingRelations: []
        )

        XCTAssertEqual(service.relations(for: firstPathway, in: [first, second]).map(\.id), [first.id])
        XCTAssertEqual(Set(service.relations(involving: source, in: [first, second]).map(\.id)), [first.id, second.id])
    }

    private func makeCard(title: String, kind: KnowledgeCardKind) -> KnowledgeCard {
        KnowledgeCard(
            title: title,
            content: "测试内容",
            cardType: kind.rawValue
        )
    }
}

@MainActor
final class KnowledgeRelationPersistenceTests: XCTestCase {
    func testPersistsRelationMetadataInMemory() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: KnowledgeRelation.self,
            configurations: configuration
        )
        let context = container.mainContext
        let pathwayID = UUID()
        let sourceID = UUID()
        let targetID = UUID()
        let relation = KnowledgeRelation(
            pathwayID: pathwayID,
            sourceCardID: sourceID,
            targetCardID: targetID,
            relationType: KnowledgeRelationKind.extends.rawValue,
            note: "补充应用边界"
        )

        context.insert(relation)
        try context.save()

        let relations = try context.fetch(FetchDescriptor<KnowledgeRelation>())
        XCTAssertEqual(relations.count, 1)
        XCTAssertEqual(relations.first?.pathwayID, pathwayID)
        XCTAssertEqual(relations.first?.sourceCardID, sourceID)
        XCTAssertEqual(relations.first?.targetCardID, targetID)
        XCTAssertEqual(relations.first?.kind, .extends)
        XCTAssertEqual(relations.first?.note, "补充应用边界")
    }
}
