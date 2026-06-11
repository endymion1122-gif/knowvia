import XCTest
@testable import Knowvia

final class KnowledgeCardTopicServiceTests: XCTestCase {
    private let service = KnowledgeCardTopicService()

    func testGroupsCardsByTopicAndIncludesUncategorizedCards() {
        let cards = [
            makeCard(title: "概念", tags: ["学习方法"]),
            makeCard(title: "证据", tags: ["学习方法", "研究方法"]),
            makeCard(title: "待整理", tags: ["AI 草稿", "待核验"]),
        ]

        let groups = service.groups(in: cards)

        XCTAssertEqual(groups.map(\.topic), ["学习方法", "研究方法", "未归类"])
        XCTAssertEqual(groups[0].cards.map(\.title), ["概念", "证据"])
        XCTAssertEqual(groups[1].cards.map(\.title), ["证据"])
        XCTAssertEqual(groups[2].cards.map(\.title), ["待整理"])
    }

    func testAssignsNormalizedTopicsAndPreservesReservedTags() {
        let card = makeCard(title: "概念", tags: ["AI 草稿", "待核验", "旧主题"])

        service.assignTopics([" 学习方法 ", "学习方法", "研究方法", ""], to: card)

        XCTAssertEqual(card.tags, ["AI 草稿", "待核验", "学习方法", "研究方法"])
    }

    private func makeCard(title: String, tags: [String]) -> KnowledgeCard {
        KnowledgeCard(
            title: title,
            content: "内容",
            tags: tags
        )
    }
}
