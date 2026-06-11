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
        let pathway = TestFactories.makeKnowledgePathway(title: "认知负荷理论")
        let claim = TestFactories.makeKnowledgeCard(title: "分段呈现可降低外在负荷", cardType: .argument)
        let evidence = TestFactories.makeKnowledgeCard(title: "实验组保持率更高", cardType: .evidence)
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
        let firstPathway = TestFactories.makeKnowledgePathway(title: "第一条路径")
        let secondPathway = TestFactories.makeKnowledgePathway(title: "第二条路径")
        let source = TestFactories.makeKnowledgeCard(title: "概念", cardType: .concept)
        let target = TestFactories.makeKnowledgeCard(title: "观点", cardType: .argument)
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
}

@MainActor
final class KnowledgeRelationPersistenceTests: XCTestCase {
    func testPersistsRelationMetadataInMemory() throws {
        let container = try TestModelContext.makeInMemoryContainer(for: KnowledgeRelation.self)
        let context = container.mainContext
        let pathwayID = UUID()
        let sourceID = UUID()
        let targetID = UUID()
        let relation = TestFactories.makeKnowledgeRelation(
            pathwayID: pathwayID,
            sourceCardID: sourceID,
            targetCardID: targetID,
            relationType: .extends,
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
