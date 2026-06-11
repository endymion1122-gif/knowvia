import XCTest
@testable import Knowvia

final class KnowledgeCardCalibrationServiceTests: XCTestCase {
    private let service = KnowledgeCardCalibrationService()

    func testTogglesMarkersAndConfirmsCard() {
        let card = TestFactories.makeKnowledgeCard(title: "反馈循环")

        service.toggleHighlighted(card)
        service.toggleUnderstood(card)
        service.confirm(card)

        XCTAssertTrue(card.isHighlighted)
        XCTAssertTrue(card.isUnderstood)
        XCTAssertEqual(card.calibrationState, .confirmed)
    }

    func testUpdatesCalibrationAndTrimsNote() {
        let card = TestFactories.makeKnowledgeCard(title: "反馈循环")

        service.update(
            card,
            status: .needsFollowUp,
            isHighlighted: true,
            isUnderstood: false,
            note: "  继续核验适用范围。  "
        )

        XCTAssertEqual(card.calibrationState, .needsFollowUp)
        XCTAssertTrue(card.isHighlighted)
        XCTAssertFalse(card.isUnderstood)
        XCTAssertEqual(card.calibrationNote, "继续核验适用范围。")
    }
}

final class KnowledgePathwayGapServiceTests: XCTestCase {
    private let service = KnowledgePathwayGapService()

    func testDetectsLocalPathwayGaps() {
        let claim = TestFactories.makeKnowledgeCard(
            title: "反馈可以支持校准",
            cardType: .argument,
            content: "测试观点"
        )
        let question = TestFactories.makeKnowledgeCard(
            title: "反馈频率如何设置？",
            cardType: .question,
            content: "测试问题"
        )
        let pathway = TestFactories.makeKnowledgePathway(
            title: "学习反馈",
            knowledgeCardIDs: [claim.id, question.id]
        )

        let gaps = service.gaps(
            for: pathway,
            cards: [claim, question],
            relations: []
        )

        XCTAssertEqual(
            Set(gaps.map(\.kind)),
            [
                .missingOverview,
                .missingSources,
                .missingConcepts,
                .missingEvidence,
                .sourceTraceability,
                .pendingCalibration,
                .unsupportedClaims,
                .openQuestions,
            ]
        )
    }

    func testSupportRelationAndConfirmedCardsReduceGaps() {
        let documentID = UUID()
        let claim = TestFactories.makeKnowledgeCard(
            title: "反馈可以支持校准",
            cardType: .argument,
            sourceDocumentId: documentID,
            sourceDocumentTitle: "Learning Notes",
            calibrationStatus: .confirmed
        )
        let evidence = TestFactories.makeKnowledgeCard(
            title: "实验结果支持反馈机制",
            cardType: .evidence,
            sourceDocumentId: documentID,
            sourceDocumentTitle: "Learning Notes",
            calibrationStatus: .confirmed
        )
        let concept = TestFactories.makeKnowledgeCard(
            title: "反馈循环",
            cardType: .concept,
            sourceDocumentId: documentID,
            sourceDocumentTitle: "Learning Notes",
            calibrationStatus: .confirmed
        )
        let pathway = TestFactories.makeKnowledgePathway(
            title: "学习反馈",
            overview: "整理反馈机制。",
            sourceDocumentIDs: [documentID],
            knowledgeCardIDs: [claim.id, evidence.id, concept.id]
        )
        let relation = TestFactories.makeKnowledgeRelation(
            pathwayID: pathway.id,
            sourceCardID: evidence.id,
            targetCardID: claim.id,
            relationType: .supports
        )

        let gaps = service.gaps(
            for: pathway,
            cards: [claim, evidence, concept],
            relations: [relation]
        )

        XCTAssertTrue(gaps.isEmpty)
    }

    func testDetectsSourceQualityAndPendingCandidateGaps() {
        let source = TestFactories.makeDocumentItem(
            title: "Web Article",
            filePath: "/tmp/web.md",
            sourceKind: .webPage,
            credibilityLevel: .needsVerification
        )
        let candidate = TestFactories.makeDocumentItem(
            title: "Candidate",
            filePath: "/tmp/candidate.md",
            sourceKind: .externalEnrichment,
            credibilityLevel: .needsVerification
        )
        let pathway = TestFactories.makeKnowledgePathway(
            title: "学习反馈",
            sourceDocumentIDs: [source.id],
            candidateDocumentIDs: [candidate.id]
        )

        let kinds = Set(
            service.gaps(
                for: pathway,
                cards: [],
                relations: [],
                documents: [source, candidate]
            )
            .map(\.kind)
        )

        XCTAssertTrue(kinds.contains(.missingSourceMetadata))
        XCTAssertTrue(kinds.contains(.unverifiedSources))
        XCTAssertTrue(kinds.contains(.missingAuthoritativeSources))
        XCTAssertTrue(kinds.contains(.pendingExternalCandidates))
    }
}
