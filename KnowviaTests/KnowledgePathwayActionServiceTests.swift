import XCTest
@testable import Knowvia

final class KnowledgePathwayActionServiceTests: XCTestCase {
    private let service = KnowledgePathwayActionService()

    func testBuildsPrioritizedActionsFromPathwayState() {
        let source = DocumentItem(
            title: "Feedback Study",
            filePath: "/tmp/feedback.md",
            fileType: "md",
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )
        let claim = KnowledgeCard(
            title: "反馈促进校准",
            content: "反馈可以帮助学习者修正理解。",
            cardType: KnowledgeCardKind.argument.rawValue
        )
        let evidence = KnowledgeCard(
            title: "实验摘录",
            content: "学习者根据反馈调整策略。",
            cardType: KnowledgeCardKind.evidence.rawValue,
            calibrationStatus: KnowledgeCardCalibrationStatus.confirmed.rawValue
        )
        let question = KnowledgeCard(
            title: "反馈频率如何设置？",
            content: "仍需确认不同任务中的节奏。",
            cardType: KnowledgeCardKind.question.rawValue
        )
        let pathway = KnowledgePathway(
            title: "反馈闭环",
            sourceDocumentIDs: [source.id],
            knowledgeCardIDs: [claim.id, evidence.id, question.id]
        )

        let actions = service.actions(
            for: pathway,
            cards: [claim, evidence, question],
            relations: [],
            documents: [source]
        )

        XCTAssertEqual(actions.first?.id, "connect-claims-evidence")
        XCTAssertTrue(actions.contains {
            $0.id == "calibrate-nodes"
                && $0.title == "校准 2 个知识节点"
        })
        XCTAssertTrue(actions.contains {
            $0.id == "verify-sources"
                && $0.detail.contains("确认作者、年份、网页链接和可信度")
        })
        XCTAssertTrue(actions.contains {
            $0.id == "complete-source-metadata"
                && $0.title == "补全 1 份来源元数据"
        })
        XCTAssertTrue(actions.contains {
            $0.id == "resolve-questions"
                && $0.title == "处理 1 个待补全问题"
        })
    }

    func testCandidateActionUsesLocalProcessingAdvice() {
        let candidate = DocumentItem(
            title: "候选资料",
            filePath: "/tmp/candidate.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.externalEnrichment.rawValue
        )
        let pathway = KnowledgePathway(
            title: "反馈闭环",
            candidateDocumentIDs: [candidate.id]
        )

        let actions = service.actions(
            for: pathway,
            cards: [],
            relations: [],
            documents: [candidate]
        )

        XCTAssertTrue(actions.contains {
            $0.id == "process-candidates"
                && $0.detail.contains("先补链接或来源线索")
        })
    }

    func testSupportRelationRemovesClaimEvidenceAction() {
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
        let pathway = KnowledgePathway(
            title: "反馈闭环",
            knowledgeCardIDs: [claim.id, evidence.id]
        )
        let relation = KnowledgeRelation(
            pathwayID: pathway.id,
            sourceCardID: evidence.id,
            targetCardID: claim.id,
            relationType: KnowledgeRelationKind.supports.rawValue
        )

        let actions = service.actions(
            for: pathway,
            cards: [claim, evidence],
            relations: [relation]
        )

        XCTAssertFalse(actions.contains { $0.id == "connect-claims-evidence" })
    }
}
