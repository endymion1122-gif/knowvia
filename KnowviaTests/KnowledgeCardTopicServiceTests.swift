import XCTest
@testable import Knowvia

final class KnowledgeCardTopicServiceTests: XCTestCase {
    private let service = KnowledgeCardTopicService()

    func testGroupsCardsByTopicAndIncludesUncategorizedCards() {
        let cards = [
            TestFactories.makeKnowledgeCard(title: "概念", tags: ["学习方法"], content: "内容"),
            TestFactories.makeKnowledgeCard(title: "证据", tags: ["学习方法", "研究方法"], content: "内容"),
            TestFactories.makeKnowledgeCard(title: "待整理", tags: ["AI 草稿", "待核验"], content: "内容"),
        ]

        let groups = service.groups(in: cards)

        XCTAssertEqual(groups.map(\.topic), ["学习方法", "研究方法", "未归类"])
        XCTAssertEqual(groups[0].cards.map(\.title), ["概念", "证据"])
        XCTAssertEqual(groups[1].cards.map(\.title), ["证据"])
        XCTAssertEqual(groups[2].cards.map(\.title), ["待整理"])
    }

    func testAssignsNormalizedTopicsAndPreservesReservedTags() {
        let card = TestFactories.makeKnowledgeCard(title: "概念", tags: ["AI 草稿", "待核验", "旧主题"], content: "内容")

        service.assignTopics([" 学习方法 ", "学习方法", "研究方法", ""], to: card)

        XCTAssertEqual(card.tags, ["AI 草稿", "待核验", "学习方法", "研究方法"])
    }
}
