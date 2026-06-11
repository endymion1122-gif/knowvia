import XCTest
@testable import Knowvia

final class AnnotationKnowledgeCardServiceTests: XCTestCase {
    private let service = AnnotationKnowledgeCardService()

    func testBuildsConceptDraftFromAnnotationNoteAndExcerpt() {
        let draft = service.draft(
            documentTitle: "学习材料",
            selectedText: "反馈循环",
            note: "连接行动后的结果与下一轮调整。"
        )

        XCTAssertEqual(draft.kind, .concept)
        XCTAssertTrue(draft.title.contains("连接行动后的结果"))
        XCTAssertTrue(draft.content.contains("用户批注\n连接行动后的结果与下一轮调整。"))
        XCTAssertTrue(draft.content.contains("原文选区\n反馈循环"))
        XCTAssertTrue(draft.tags.contains("批注转卡片"))
        XCTAssertTrue(draft.tags.contains("学习材料"))
    }

    func testUsesGeneratedSummaryForArgumentDraft() {
        let draft = service.draft(
            documentTitle: "研究笔记",
            selectedText: "学习者需要持续连接概念、观点与证据。",
            note: "可以作为知识路径设计原则。",
            generatedSummary: "这句话强调知识资产需要形成可复用的连接。"
        )

        XCTAssertEqual(draft.kind, .argument)
        XCTAssertTrue(draft.content.contains("这句话强调知识资产需要形成可复用的连接。"))
        XCTAssertTrue(draft.content.contains("可以作为知识路径设计原则。"))
    }
}
