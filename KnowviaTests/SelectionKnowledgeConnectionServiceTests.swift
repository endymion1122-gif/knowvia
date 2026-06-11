import XCTest
@testable import Knowvia

final class SelectionKnowledgeConnectionServiceTests: XCTestCase {
    private let service = SelectionKnowledgeConnectionService()

    func testFindsRelatedDocumentsAndCardsButExcludesActiveDocument() {
        let activeDocument = DocumentItem(
            title: "当前材料",
            filePath: "/tmp/current.md",
            fileType: "md",
            extractedText: "反馈循环有助于持续调整。"
        )
        let relatedDocument = DocumentItem(
            title: "历史笔记",
            filePath: "/tmp/history.md",
            fileType: "md",
            summary: "这份笔记也讨论了反馈循环。"
        )
        let unrelatedDocument = DocumentItem(
            title: "无关材料",
            filePath: "/tmp/other.md",
            fileType: "md",
            extractedText: "这里只讨论阅读策略。"
        )
        let relatedCard = KnowledgeCard(
            title: "概念：反馈循环",
            content: "反馈循环可以用于持续调整学习策略。"
        )

        let connections = service.connections(
            for: "反馈循环",
            activeDocumentID: activeDocument.id,
            documents: [activeDocument, relatedDocument, unrelatedDocument],
            cards: [relatedCard]
        )

        XCTAssertEqual(connections.documents.map(\.id), [relatedDocument.id])
        XCTAssertEqual(connections.cards.map(\.id), [relatedCard.id])
    }

    func testIgnoresSingleCharacterSelection() {
        let document = DocumentItem(
            title: "材料",
            filePath: "/tmp/document.md",
            fileType: "md",
            extractedText: "知识成为路径。"
        )

        let connections = service.connections(
            for: "知",
            activeDocumentID: nil,
            documents: [document],
            cards: []
        )

        XCTAssertTrue(connections.isEmpty)
    }
}
