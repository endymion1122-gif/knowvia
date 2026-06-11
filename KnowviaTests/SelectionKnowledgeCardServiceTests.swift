import XCTest
@testable import Knowvia

final class SelectionKnowledgeCardServiceTests: XCTestCase {
    private let service = SelectionKnowledgeCardService()

    func testBuildsConceptDraftForShortTerm() {
        let draft = service.draft(
            documentTitle: "学习材料",
            selectedText: "反馈循环"
        )

        XCTAssertEqual(draft.kind, .concept)
        XCTAssertTrue(draft.title.contains("反馈循环"))
        XCTAssertTrue(draft.content.contains("核心术语"))
        XCTAssertTrue(draft.content.contains("原文选区\n反馈循环"))
        XCTAssertTrue(draft.tags.contains("待核验"))
        XCTAssertTrue(draft.tags.contains("学习材料"))
    }

    func testBuildsQuestionDraftForSelectedQuestion() {
        let draft = service.draft(
            documentTitle: "研究笔记",
            selectedText: "如何把知识转化为行动？"
        )

        XCTAssertEqual(draft.kind, .question)
        XCTAssertTrue(draft.content.contains("继续追问"))
    }

    func testBuildsArgumentDraftWithGeneratedSummary() {
        let draft = service.draft(
            documentTitle: "课程材料",
            selectedText: "学习者需要持续连接概念、观点与证据。",
            generatedSummary: "这句话强调知识资产需要形成可复用的连接。"
        )

        XCTAssertEqual(draft.kind, .argument)
        XCTAssertTrue(draft.content.contains("这句话强调知识资产需要形成可复用的连接。"))
        XCTAssertTrue(draft.content.contains("学习者需要持续连接概念、观点与证据。"))
    }
}
