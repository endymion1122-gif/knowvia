import XCTest
@testable import Knowvia

final class PromptTemplatesTests: XCTestCase {
    func testDocumentSpeedReadTruncatesLongDocuments() {
        let text = String(repeating: "知", count: PromptTemplates.maximumDocumentCharacters + 20)

        let prompt = PromptTemplates.documentSpeedRead(text)

        XCTAssertTrue(prompt.wasTruncated)
        XCTAssertTrue(prompt.content.contains("核心主题"))
        XCTAssertTrue(
            prompt.content.hasSuffix(String(text.prefix(PromptTemplates.maximumDocumentCharacters)))
        )
    }

    func testConceptExplanationTruncatesLongSelection() {
        let text = String(repeating: "径", count: PromptTemplates.maximumSelectionCharacters + 20)

        let prompt = PromptTemplates.conceptExplanation(text)

        XCTAssertTrue(prompt.wasTruncated)
        XCTAssertTrue(prompt.content.contains("概念定义"))
        XCTAssertTrue(
            prompt.content.hasSuffix(String(text.prefix(PromptTemplates.maximumSelectionCharacters)))
        )
    }

    func testSelectionKnowledgeCardTruncatesLongSelection() {
        let text = String(repeating: "卡", count: PromptTemplates.maximumSelectionCharacters + 20)

        let prompt = PromptTemplates.selectionKnowledgeCard(text)

        XCTAssertTrue(prompt.wasTruncated)
        XCTAssertTrue(prompt.content.contains("知识卡片正文"))
        XCTAssertTrue(
            prompt.content.hasSuffix(String(text.prefix(PromptTemplates.maximumSelectionCharacters)))
        )
    }

    func testAnnotationKnowledgeCardIncludesNoteAndTruncatesCombinedContext() {
        let text = String(repeating: "注", count: PromptTemplates.maximumSelectionCharacters + 20)

        let prompt = PromptTemplates.annotationKnowledgeCard(
            selectedText: text,
            note: "连接原文与用户判断"
        )

        XCTAssertTrue(prompt.wasTruncated)
        XCTAssertTrue(prompt.content.contains("用户的阅读批注"))
        XCTAssertTrue(prompt.content.contains("连接原文与用户判断"))
    }
}
