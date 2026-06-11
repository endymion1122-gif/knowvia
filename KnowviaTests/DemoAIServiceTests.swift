import XCTest
@testable import Knowvia

final class DemoAIServiceTests: XCTestCase {
    private let service = DemoAIService()

    func testBuildsClearlyLabeledDocumentSummary() {
        let summary = service.documentSummary(
            title: "学习材料",
            text: "这是用于测试摘要流程的原文内容。"
        )

        XCTAssertTrue(summary.contains("[本地 Demo 示例]"))
        XCTAssertTrue(summary.contains("《学习材料》"))
        XCTAssertTrue(summary.contains("这是用于测试摘要流程的原文内容。"))
        XCTAssertTrue(summary.contains("概念卡"))
    }

    func testBuildsClearlyLabeledConceptExplanation() {
        let explanation = service.conceptExplanation("反馈循环有助于持续调整学习策略。")

        XCTAssertTrue(explanation.contains("[本地 Demo 示例]"))
        XCTAssertTrue(explanation.contains("反馈循环有助于持续调整学习策略。"))
        XCTAssertTrue(explanation.contains("保存当前文档和页码"))
    }

    func testBuildsThreeEditableKnowledgeCardDrafts() {
        let drafts = service.knowledgeCardDrafts(
            documentTitle: "学习材料",
            text: "反馈循环有助于持续调整学习策略。"
        )

        XCTAssertEqual(drafts.map(\.kind), [.concept, .argument, .evidence])
        XCTAssertTrue(drafts.allSatisfy { $0.title.contains("学习材料") })
        XCTAssertTrue(drafts.allSatisfy { $0.tags.contains("待核验") })
        XCTAssertTrue(drafts.last?.content.contains("反馈循环有助于持续调整学习策略。") == true)
    }

    func testBuildsEditableSelectionKnowledgeCardDraft() {
        let draft = service.selectionKnowledgeCardDraft(
            documentTitle: "学习材料",
            selectedText: "反馈循环"
        )

        XCTAssertEqual(draft.kind, .concept)
        XCTAssertTrue(draft.title.contains("反馈循环"))
        XCTAssertTrue(draft.content.contains("AI 归纳"))
        XCTAssertTrue(draft.content.contains("原文选区"))
    }

    func testBuildsEditableAnnotationKnowledgeCardDraft() {
        let draft = service.annotationKnowledgeCardDraft(
            documentTitle: "学习材料",
            selectedText: "反馈循环",
            note: "连接行动结果与下一轮调整。"
        )

        XCTAssertEqual(draft.kind, .concept)
        XCTAssertTrue(draft.content.contains("用户批注"))
        XCTAssertTrue(draft.content.contains("连接行动结果与下一轮调整。"))
        XCTAssertTrue(draft.tags.contains("批注转卡片"))
    }
}
