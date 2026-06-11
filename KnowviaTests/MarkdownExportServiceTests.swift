import Foundation
import XCTest
@testable import Knowvia

final class MarkdownExportServiceTests: XCTestCase {
    private let service = MarkdownExportService()

    func testExportsCardsWithTypeSourceTagsAndContent() throws {
        let card = KnowledgeCard(
            title: "Transformer 的核心结构",
            content: "Self-attention 允许模型建立序列中不同位置之间的联系。",
            cardType: KnowledgeCardKind.concept.rawValue,
            tags: ["Transformer", "深度学习"],
            sourceDocumentTitle: "Attention Is All You Need",
            pageNumber: 3,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let markdown = try service.markdown(
            for: [card],
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        XCTAssertTrue(markdown.contains("# 知径 Knowvia 知识卡片"))
        XCTAssertTrue(markdown.contains("- 卡片数量：1"))
        XCTAssertTrue(markdown.contains("## Transformer 的核心结构"))
        XCTAssertTrue(markdown.contains("- 类型：概念"))
        XCTAssertTrue(markdown.contains("- 来源：Attention Is All You Need，p.3"))
        XCTAssertTrue(markdown.contains("- 标签：Transformer，深度学习"))
        XCTAssertTrue(markdown.contains("Self-attention 允许模型建立序列中不同位置之间的联系。"))
    }

    func testWritesMarkdownFile() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destinationURL = temporaryDirectory.appendingPathComponent("cards.md")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let card = KnowledgeCard(title: "阅读笔记", content: "保留可复用的知识资产。")
        try service.export(cards: [card], to: destinationURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertTrue(try String(contentsOf: destinationURL, encoding: .utf8).contains("## 阅读笔记"))
    }

    func testRejectsEmptyExport() {
        XCTAssertThrowsError(try service.markdown(for: [])) { error in
            XCTAssertEqual(error as? MarkdownExportError, .noCards)
        }
    }
}
