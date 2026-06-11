import XCTest
@testable import Knowvia

final class KnowledgeCardCalibrationServiceTests: XCTestCase {
    private let service = KnowledgeCardCalibrationService()

    func testTogglesMarkersAndConfirmsCard() {
        let card = makeCard()

        service.toggleHighlighted(card)
        service.toggleUnderstood(card)
        service.confirm(card)

        XCTAssertTrue(card.isHighlighted)
        XCTAssertTrue(card.isUnderstood)
        XCTAssertEqual(card.calibrationState, .confirmed)
    }

    func testUpdatesCalibrationAndTrimsNote() {
        let card = makeCard()

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

    private func makeCard() -> KnowledgeCard {
        KnowledgeCard(
            title: "反馈循环",
            content: "测试内容",
            cardType: KnowledgeCardKind.concept.rawValue
        )
    }
}

final class KnowledgePathwayGapServiceTests: XCTestCase {
    private let service = KnowledgePathwayGapService()

    func testDetectsLocalPathwayGaps() {
        let claim = KnowledgeCard(
            title: "反馈可以支持校准",
            content: "测试观点",
            cardType: KnowledgeCardKind.argument.rawValue
        )
        let question = KnowledgeCard(
            title: "反馈频率如何设置？",
            content: "测试问题",
            cardType: KnowledgeCardKind.question.rawValue
        )
        let pathway = KnowledgePathway(
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
        let claim = makeConfirmedCard(
            title: "反馈可以支持校准",
            kind: .argument,
            documentID: documentID
        )
        let evidence = makeConfirmedCard(
            title: "实验结果支持反馈机制",
            kind: .evidence,
            documentID: documentID
        )
        let concept = makeConfirmedCard(
            title: "反馈循环",
            kind: .concept,
            documentID: documentID
        )
        let pathway = KnowledgePathway(
            title: "学习反馈",
            overview: "整理反馈机制。",
            sourceDocumentIDs: [documentID],
            knowledgeCardIDs: [claim.id, evidence.id, concept.id]
        )
        let relation = KnowledgeRelation(
            pathwayID: pathway.id,
            sourceCardID: evidence.id,
            targetCardID: claim.id,
            relationType: KnowledgeRelationKind.supports.rawValue
        )

        let gaps = service.gaps(
            for: pathway,
            cards: [claim, evidence, concept],
            relations: [relation]
        )

        XCTAssertTrue(gaps.isEmpty)
    }

    func testDetectsSourceQualityAndPendingCandidateGaps() {
        let source = DocumentItem(
            title: "Web Article",
            filePath: "/tmp/web.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.webPage.rawValue,
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )
        let candidate = DocumentItem(
            title: "Candidate",
            filePath: "/tmp/candidate.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.externalEnrichment.rawValue,
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )
        let pathway = KnowledgePathway(
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

    private func makeConfirmedCard(
        title: String,
        kind: KnowledgeCardKind,
        documentID: UUID
    ) -> KnowledgeCard {
        KnowledgeCard(
            title: title,
            content: "测试内容",
            cardType: kind.rawValue,
            sourceDocumentId: documentID,
            sourceDocumentTitle: "Learning Notes",
            calibrationStatus: KnowledgeCardCalibrationStatus.confirmed.rawValue
        )
    }
}
