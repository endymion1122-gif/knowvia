import XCTest
@testable import Knowvia

final class AIKnowledgeCardDraftServiceTests: XCTestCase {
    private let service = AIKnowledgeCardDraftService()

    func testBuildsVerificationFirstDraftsFromRealAISummary() {
        let drafts = service.drafts(
            documentTitle: "研究材料",
            text: "原文指出，反馈循环可以把行动结果带回下一轮决策，因此学习者需要持续校准。",
            generatedSummary: "1. 核心主题\n材料讨论反馈循环与学习校准。"
        )

        XCTAssertEqual(drafts.map(\.kind), [.concept, .argument, .evidence])
        XCTAssertTrue(drafts.allSatisfy { $0.title.contains("研究材料") })
        XCTAssertTrue(drafts.allSatisfy { $0.tags.contains("真实 AI") })
        XCTAssertTrue(drafts.allSatisfy { $0.tags.contains("待核验") })
        XCTAssertTrue(drafts.allSatisfy { $0.content.contains("AI 归纳") })
        XCTAssertTrue(drafts.allSatisfy { $0.content.contains("核验提示") })
        XCTAssertTrue(drafts.last?.content.contains("反馈循环可以把行动结果") == true)
    }

    func testNormalizesMarkdownFencedModelOutput() {
        let normalized = service.normalizedResponse("""
        ```markdown
        1. 核心主题
        材料讨论学习策略。
        ```
        """)

        XCTAssertFalse(normalized.contains("```"))
        XCTAssertTrue(normalized.contains("材料讨论学习策略。"))
    }

    func testFallsBackWhenModelOutputIsBlank() {
        let normalized = service.normalizedResponse("   \n\t")

        XCTAssertTrue(normalized.contains("模型未返回可整理的摘要"))
    }
}
