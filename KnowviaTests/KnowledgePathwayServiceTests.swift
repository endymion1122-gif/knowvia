import XCTest
@testable import Knowvia

final class KnowledgePathwayServiceTests: XCTestCase {
    private let service = KnowledgePathwayService()

    func testUpdatesDocumentAssignmentsOnBothSides() {
        let document = makeDocument()
        let first = KnowledgePathway(title: "认知负荷理论")
        let second = KnowledgePathway(title: "自我调节学习")

        service.updateAssignments(
            for: document,
            selectedPathwayIDs: [first.id, second.id],
            pathways: [first, second]
        )

        XCTAssertEqual(Set(document.pathwayIDs), [first.id, second.id])
        XCTAssertEqual(first.sourceDocumentIDs, [document.id])
        XCTAssertEqual(second.sourceDocumentIDs, [document.id])

        service.updateAssignments(
            for: document,
            selectedPathwayIDs: [second.id],
            pathways: [first, second]
        )

        XCTAssertEqual(document.pathwayIDs, [second.id])
        XCTAssertTrue(first.sourceDocumentIDs.isEmpty)
        XCTAssertEqual(second.sourceDocumentIDs, [document.id])
    }

    func testDetachesDeletedPathwayFromDocuments() {
        let firstDocument = makeDocument()
        let secondDocument = makeDocument()
        let pathway = KnowledgePathway(
            title: "生成式 AI 支架",
            sourceDocumentIDs: [firstDocument.id, secondDocument.id]
        )
        firstDocument.pathwayIDs = [pathway.id]
        secondDocument.pathwayIDs = [pathway.id]

        service.detach(pathway, from: [firstDocument, secondDocument])

        XCTAssertTrue(pathway.sourceDocumentIDs.isEmpty)
        XCTAssertTrue(firstDocument.pathwayIDs.isEmpty)
        XCTAssertTrue(secondDocument.pathwayIDs.isEmpty)
    }

    func testUpdatesKnowledgeCardAssignmentsAndBuildsOverview() {
        let concept = makeCard(title: "认知负荷", kind: .concept)
        let evidence = makeCard(title: "工作记忆容量有限", kind: .evidence)
        let question = makeCard(title: "如何控制外在负荷？", kind: .question)
        let pathway = KnowledgePathway(title: "认知负荷理论")

        service.updateKnowledgeNodes(
            for: pathway,
            selectedCardIDs: [concept.id, evidence.id, question.id],
            cards: [concept, evidence, question]
        )

        XCTAssertEqual(Set(pathway.knowledgeCardIDs), [concept.id, evidence.id, question.id])
        XCTAssertEqual(concept.pathwayIDs, [pathway.id])

        let overview = service.overview(
            for: pathway,
            in: [concept, evidence, question]
        )
        XCTAssertEqual(overview.concepts.map(\.id), [concept.id])
        XCTAssertEqual(overview.evidence.map(\.id), [evidence.id])
        XCTAssertEqual(overview.questions.map(\.id), [question.id])
        XCTAssertTrue(overview.arguments.isEmpty)
    }

    func testDetachesDeletedCardFromPathways() {
        let card = makeCard(title: "生成效应", kind: .concept)
        let pathway = KnowledgePathway(
            title: "深度学习策略",
            knowledgeCardIDs: [card.id]
        )
        card.pathwayIDs = [pathway.id]

        service.detach(card, from: [pathway])

        XCTAssertTrue(card.pathwayIDs.isEmpty)
        XCTAssertTrue(pathway.knowledgeCardIDs.isEmpty)
    }

    func testCandidateIsSeparatedUntilConfirmed() {
        let document = makeDocument()
        let pathway = KnowledgePathway(title: "生成式 AI 支架")

        service.addCandidate(document, to: pathway)

        XCTAssertEqual(pathway.candidateDocumentIDs, [document.id])
        XCTAssertTrue(pathway.sourceDocumentIDs.isEmpty)
        XCTAssertTrue(document.pathwayIDs.isEmpty)
        XCTAssertEqual(document.sourceType, .externalEnrichment)
        XCTAssertEqual(document.credibility, .needsVerification)

        service.confirmCandidate(document, for: pathway)

        XCTAssertTrue(pathway.candidateDocumentIDs.isEmpty)
        XCTAssertEqual(pathway.sourceDocumentIDs, [document.id])
        XCTAssertEqual(document.pathwayIDs, [pathway.id])
    }

    func testRemovesCandidateWithoutAddingFormalSource() {
        let document = makeDocument()
        let pathway = KnowledgePathway(
            title: "生成式 AI 支架",
            candidateDocumentIDs: [document.id]
        )

        service.removeCandidate(document, from: pathway)

        XCTAssertTrue(pathway.candidateDocumentIDs.isEmpty)
        XCTAssertTrue(pathway.sourceDocumentIDs.isEmpty)
    }

    private func makeDocument() -> DocumentItem {
        DocumentItem(
            title: "Learning Notes",
            filePath: "/tmp/notes.md",
            fileType: "md"
        )
    }

    private func makeCard(title: String, kind: KnowledgeCardKind) -> KnowledgeCard {
        KnowledgeCard(
            title: title,
            content: "测试内容",
            cardType: kind.rawValue
        )
    }
}
