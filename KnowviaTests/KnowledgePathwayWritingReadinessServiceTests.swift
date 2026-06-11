import XCTest
@testable import Knowvia

final class KnowledgePathwayWritingReadinessServiceTests: XCTestCase {
    private let service = KnowledgePathwayWritingReadinessService()
    private let outlineService = KnowledgePathwayWritingOutlineService()
    private let actionService = KnowledgePathwayWritingActionService()
    private let nodeFilterService = KnowledgePathwayNodeFilterService()

    func testFlagsBlockersForEmptyPathway() {
        let pathway = KnowledgePathway(title: "写作准备")

        let checks = service.checks(
            for: pathway,
            cards: [],
            relations: [],
            documents: []
        )

        XCTAssertTrue(checks.contains {
            $0.id == "claims-supported" && $0.status == .blocker
        })
        XCTAssertTrue(checks.contains {
            $0.id == "evidence-traceable" && $0.status == .blocker
        })
        XCTAssertTrue(checks.contains {
            $0.id == "sources-citable" && $0.status == .blocker
        })
    }

    func testMarksSupportedTraceablePathwayAsReady() {
        let source = DocumentItem(
            title: "Core Source",
            filePath: "/tmp/source.md",
            fileType: "md",
            author: "Research Lab",
            publicationYear: 2026,
            credibilityLevel: SourceCredibilityLevel.authoritative.rawValue
        )
        let claim = KnowledgeCard(
            title: "反馈促进校准",
            content: "反馈可以帮助学习者修正理解。",
            cardType: KnowledgeCardKind.argument.rawValue,
            calibrationStatus: KnowledgeCardCalibrationStatus.confirmed.rawValue
        )
        let evidence = KnowledgeCard(
            title: "实验摘录",
            content: "学习者根据反馈调整策略。",
            cardType: KnowledgeCardKind.evidence.rawValue,
            sourceDocumentId: source.id,
            calibrationStatus: KnowledgeCardCalibrationStatus.confirmed.rawValue
        )
        let pathway = KnowledgePathway(
            title: "反馈闭环",
            sourceDocumentIDs: [source.id],
            knowledgeCardIDs: [claim.id, evidence.id]
        )
        let relation = KnowledgeRelation(
            pathwayID: pathway.id,
            sourceCardID: evidence.id,
            targetCardID: claim.id,
            relationType: KnowledgeRelationKind.supports.rawValue
        )

        let checks = service.checks(
            for: pathway,
            cards: [claim, evidence],
            relations: [relation],
            documents: [source]
        )

        XCTAssertTrue(checks.allSatisfy { $0.status == .ready })
    }

    func testBuildsLocalWritingOutlineFromNodesAndEvidenceRelations() {
        let claim = KnowledgeCard(
            title: "反馈促进校准",
            content: "反馈可以帮助学习者修正理解。",
            cardType: KnowledgeCardKind.argument.rawValue
        )
        let evidence = KnowledgeCard(
            title: "实验摘录",
            content: "学习者根据反馈调整策略。",
            cardType: KnowledgeCardKind.evidence.rawValue
        )
        let concept = KnowledgeCard(
            title: "形成性反馈",
            content: "学习过程中的即时反馈。",
            cardType: KnowledgeCardKind.concept.rawValue
        )
        let pathway = KnowledgePathway(
            title: "反馈闭环",
            overview: "说明反馈如何支持学习校准。",
            knowledgeCardIDs: [claim.id, evidence.id, concept.id]
        )
        let relation = KnowledgeRelation(
            pathwayID: pathway.id,
            sourceCardID: evidence.id,
            targetCardID: claim.id,
            relationType: KnowledgeRelationKind.supports.rawValue
        )

        let outline = outlineService.outline(
            for: pathway,
            cards: [claim, evidence, concept],
            relations: [relation]
        )

        XCTAssertTrue(outline.contains {
            $0.id == "scope" && $0.bullets.contains("核心概念：形成性反馈")
        })
        XCTAssertTrue(outline.contains {
            $0.id == "claims"
                && $0.bullets.contains("反馈促进校准：支持证据：实验摘录")
        })
    }

    func testFiltersNodesByKindAndSourceQuality() {
        let unverifiedSource = DocumentItem(
            title: "Web Source",
            filePath: "/tmp/web.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.webPage.rawValue,
            author: "Author",
            publicationYear: 2026,
            sourceURLString: "https://example.com",
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )
        let incompleteSource = DocumentItem(
            title: "Incomplete Source",
            filePath: "/tmp/incomplete.md",
            fileType: "md",
            credibilityLevel: SourceCredibilityLevel.userProvided.rawValue
        )
        let claim = KnowledgeCard(
            title: "待核验观点",
            content: "观点内容",
            cardType: KnowledgeCardKind.argument.rawValue,
            sourceDocumentId: unverifiedSource.id
        )
        let evidence = KnowledgeCard(
            title: "待补证据",
            content: "证据内容",
            cardType: KnowledgeCardKind.evidence.rawValue,
            sourceDocumentId: incompleteSource.id
        )

        XCTAssertEqual(
            nodeFilterService.filter(
                [claim, evidence],
                documents: [unverifiedSource, incompleteSource],
                kind: .argument,
                sourceQuality: .needsVerification
            ).map(\.id),
            [claim.id]
        )
        XCTAssertEqual(
            nodeFilterService.filter(
                [claim, evidence],
                documents: [unverifiedSource, incompleteSource],
                kind: .evidence,
                sourceQuality: .missingMetadata
            ).map(\.id),
            [evidence.id]
        )
    }

    func testBuildsWritingActionsFromReadinessAndSourceQuality() {
        let unverifiedSource = DocumentItem(
            title: "Web Source",
            filePath: "/tmp/web.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.webPage.rawValue,
            author: "Author",
            publicationYear: 2026,
            sourceURLString: "https://example.com",
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )
        let incompleteSource = DocumentItem(
            title: "Incomplete Source",
            filePath: "/tmp/incomplete.md",
            fileType: "md",
            credibilityLevel: SourceCredibilityLevel.userProvided.rawValue
        )
        let claim = KnowledgeCard(
            title: "待核验观点",
            content: "观点内容",
            cardType: KnowledgeCardKind.argument.rawValue,
            sourceDocumentId: unverifiedSource.id
        )
        let evidence = KnowledgeCard(
            title: "待补证据",
            content: "证据内容",
            cardType: KnowledgeCardKind.evidence.rawValue,
            sourceDocumentId: incompleteSource.id
        )
        let pathway = KnowledgePathway(
            title: "写作行动",
            sourceDocumentIDs: [unverifiedSource.id, incompleteSource.id],
            candidateDocumentIDs: [incompleteSource.id],
            knowledgeCardIDs: [claim.id, evidence.id]
        )

        let actions = actionService.actions(
            for: pathway,
            cards: [claim, evidence],
            relations: [],
            documents: [unverifiedSource, incompleteSource]
        )

        XCTAssertTrue(actions.contains {
            $0.id == "verify-claim-sources"
                && $0.priority == .high
                && $0.relatedCount == 1
                && $0.target == KnowledgePathwayWritingActionTarget(
                    nodeKind: .argument,
                    nodeSourceQuality: .needsVerification
                )
                && $0.relatedTitles == ["待核验观点"]
        })
        XCTAssertTrue(actions.contains {
            $0.id == "complete-evidence-metadata"
                && $0.priority == .medium
                && $0.relatedCount == 1
                && $0.target == KnowledgePathwayWritingActionTarget(
                    nodeKind: .evidence,
                    nodeSourceQuality: .missingMetadata
                )
                && $0.relatedTitles == ["待补证据"]
        })
        XCTAssertTrue(actions.contains { $0.id == "connect-claim-evidence" })
        XCTAssertTrue(actions.contains {
            $0.id == "review-candidate-sources"
                && $0.target == KnowledgePathwayWritingActionTarget(focusesCandidates: true)
                && $0.relatedTitles == ["Incomplete Source"]
        })
    }
}
