import XCTest
@testable import Knowvia

final class KnowledgeCardSourceServiceTests: XCTestCase {
    private let service = KnowledgeCardSourceService()

    func testFindsLinkedDocumentAndUsesPDFPageNumber() throws {
        let document = TestFactories.makeDocumentItem(fileType: "pdf")
        let card = TestFactories.makeKnowledgeCard(
            title: "测试卡片",
            content: "用于验证来源跳转。",
            sourceDocumentId: document.id,
            pageNumber: 12
        )

        XCTAssertEqual(try service.sourceDocument(for: card, in: [document]).id, document.id)
        XCTAssertEqual(service.targetPageNumber(for: card, in: document), 12)
    }

    func testIgnoresPageNumberForTextDocument() {
        let document = TestFactories.makeDocumentItem(fileType: "md")
        let card = TestFactories.makeKnowledgeCard(
            title: "测试卡片",
            content: "用于验证来源跳转。",
            sourceDocumentId: document.id,
            pageNumber: 12
        )

        XCTAssertNil(service.targetPageNumber(for: card, in: document))
    }

    func testRejectsMissingSourceReferenceAndMissingDocument() {
        let cardWithoutSource = TestFactories.makeKnowledgeCard(
            title: "测试卡片",
            content: "用于验证来源跳转。"
        )
        let cardWithDeletedSource = TestFactories.makeKnowledgeCard(
            title: "测试卡片",
            content: "用于验证来源跳转。",
            sourceDocumentId: UUID()
        )

        XCTAssertThrowsError(try service.sourceDocument(for: cardWithoutSource, in: [])) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "这张卡片没有关联资料，暂时无法打开原文。"
            )
        }
        XCTAssertThrowsError(try service.sourceDocument(for: cardWithDeletedSource, in: [])) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "关联资料已不在资料库中，但卡片内容仍然保留。"
            )
        }
    }
}

@MainActor
final class ReaderViewModelPageIndexTests: XCTestCase {
    func testConvertsRequestedPageNumberToClampedZeroBasedIndex() {
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: nil, pageCount: 10), 0)
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: 1, pageCount: 10), 0)
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: 3, pageCount: 10), 2)
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: 99, pageCount: 10), 9)
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: 0, pageCount: 10), 0)
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: 3, pageCount: 0), 0)
    }

    func testConvertsValidPageNumberInputAndRejectsOutOfRangeValues() {
        XCTAssertEqual(ReaderViewModel.pageIndex(forPageNumberInput: " 3 ", pageCount: 10), 2)
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "0", pageCount: 10))
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "11", pageCount: 10))
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "page", pageCount: 10))
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "1", pageCount: 0))
    }
}
