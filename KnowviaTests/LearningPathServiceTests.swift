import Foundation
import XCTest
@testable import Knowvia

final class LearningPathServiceTests: XCTestCase {
    private let service = LearningPathService()

    func testBuildsTopicsWithoutInternalDraftTags() {
        let cards = [
            TestFactories.makeKnowledgeCard(
                kind: .concept, tags: ["学习方法", "AI 草稿", "待核验"], content: "内容",
                sourceDocumentTitle: "测试资料"
            ),
            TestFactories.makeKnowledgeCard(
                kind: .argument, tags: ["研究方法", "观点"], content: "内容",
                sourceDocumentTitle: "测试资料"
            ),
        ]

        XCTAssertEqual(service.availableTopics(in: cards), ["学习方法", "研究方法"])
    }

    func testBuildsFiveStepPathForSelectedTopic() {
        let cards = [
            TestFactories.makeKnowledgeCard(
                title: "概念", cardType: .concept, tags: ["学习方法"], content: "内容",
                sourceDocumentTitle: "测试资料"
            ),
            TestFactories.makeKnowledgeCard(
                title: "观点", cardType: .argument, tags: ["学习方法"], content: "内容",
                sourceDocumentTitle: "测试资料"
            ),
            TestFactories.makeKnowledgeCard(
                title: "证据", cardType: .evidence, tags: ["学习方法"], content: "内容",
                sourceDocumentTitle: "测试资料"
            ),
            TestFactories.makeKnowledgeCard(
                title: "其他", tags: ["其他主题"], content: "内容",
                sourceDocumentTitle: "测试资料"
            ),
        ]

        let snapshot = service.snapshot(for: cards, topic: "学习方法")

        XCTAssertEqual(snapshot.cards.count, 3)
        XCTAssertEqual(snapshot.steps.map(\.stage), LearningPathStep.Stage.allCases)
        XCTAssertEqual(snapshot.steps[0].cards.count, 1)
        XCTAssertEqual(snapshot.steps[1].cards.count, 1)
        XCTAssertEqual(snapshot.steps[2].cards.count, 1)
        XCTAssertEqual(snapshot.steps[3].cards.count, 3)
    }

    func testExportsDayCabinStyleTaskMarkdown() throws {
        let snapshot = service.snapshot(
            for: [TestFactories.makeKnowledgeCard(
                title: "反馈循环", cardType: .concept, tags: ["学习方法"], content: "内容",
                sourceDocumentTitle: "测试资料"
            )],
            topic: "学习方法"
        )

        let markdown = try service.taskMarkdown(
            for: snapshot,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertTrue(markdown.contains("# 一日舱 DayCabin 学习任务草稿"))
        XCTAssertTrue(markdown.contains("- 主题：学习方法"))
        XCTAssertTrue(markdown.contains("- [ ] 复习 学习方法 的概念卡"))
        XCTAssertTrue(markdown.contains("反馈循环（概念）"))
    }

    func testRejectsEmptyTaskExport() {
        let snapshot = service.snapshot(for: [], topic: nil)

        XCTAssertThrowsError(try service.taskMarkdown(for: snapshot)) { error in
            XCTAssertEqual(error as? LearningPathExportError, .noCards)
        }
    }

    func testSnapshotPreservesSourceNavigationMetadata() {
        let sourceDocumentId = UUID()
        let card = KnowledgeCard(
            title: "证据",
            content: "内容",
            cardType: KnowledgeCardKind.evidence.rawValue,
            tags: ["研究方法"],
            sourceDocumentId: sourceDocumentId,
            sourceDocumentTitle: "测试资料",
            pageNumber: 8
        )

        let reference = service.snapshot(for: [card], topic: nil).cards[0]

        XCTAssertEqual(reference.sourceDocumentId, sourceDocumentId)
        XCTAssertEqual(reference.pageNumber, 8)
    }
}
