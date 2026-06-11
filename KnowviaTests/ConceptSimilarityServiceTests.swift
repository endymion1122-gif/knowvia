import XCTest
@testable import Knowvia

final class ConceptSimilarityServiceTests: XCTestCase {
    private let service = ConceptSimilarityService()

    func testFindsSimilarCardsByContent() {
        let source = TestFactories.makeKnowledgeCard(
            title: "认知负荷理论",
            content: "工作记忆容量有限，需要通过分段呈现减少外在认知负荷。"
        )
        let similar = TestFactories.makeKnowledgeCard(
            title: "外在认知负荷",
            content: "分段呈现可降低外在认知负荷，提升学习效果。"
        )
        let unrelated = TestFactories.makeKnowledgeCard(
            title: "光合作用",
            content: "植物通过光合作用将光能转化为化学能。"
        )

        let results = service.findSimilar(to: source, in: [similar, unrelated])

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.card.id, similar.id)
        XCTAssertGreaterThan(results.first?.score ?? 0, 0.05)
    }

    func testExcludesSourceCardFromResults() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")

        let results = service.findSimilar(to: card, in: [card])

        XCTAssertTrue(results.isEmpty)
    }

    func testReturnsMaxCountResults() {
        let source = TestFactories.makeKnowledgeCard(title: "学习")
        let pool = (0..<10).map { i in
            TestFactories.makeKnowledgeCard(title: "卡片 \(i)", content: "学习 方法 策略")
        }

        let results = service.findSimilar(to: source, in: pool, maxCount: 3)

        XCTAssertEqual(results.count, 3)
    }

    func testFiltersBelowMinScore() {
        let source = TestFactories.makeKnowledgeCard(title: "认知负荷", content: "工作记忆")
        let unrelated = TestFactories.makeKnowledgeCard(title: "光合作用", content: "植物 阳光 叶绿素")

        let results = service.findSimilar(to: source, in: [unrelated], minScore: 0.3)

        XCTAssertTrue(results.isEmpty)
    }

    func testCrossPathwaySimilarFiltersSharedPathways() {
        let pathwayA = UUID()
        let pathwayB = UUID()

        let source = TestFactories.makeKnowledgeCard(
            title: "认知负荷",
            pathwayIDs: [pathwayA]
        )
        let samePathway = TestFactories.makeKnowledgeCard(
            title: "认知负荷理论",
            content: "工作记忆 认知负荷",
            pathwayIDs: [pathwayA]
        )
        let differentPathway = TestFactories.makeKnowledgeCard(
            title: "认知负荷理论",
            content: "工作记忆 认知负荷",
            pathwayIDs: [pathwayB]
        )

        let crossResults = service.crossPathwaySimilar(to: source, in: [samePathway, differentPathway])

        XCTAssertEqual(crossResults.count, 1)
        XCTAssertEqual(crossResults.first?.card.id, differentPathway.id)
    }

    func testEmptyPoolReturnsEmpty() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")

        XCTAssertTrue(service.findSimilar(to: card, in: []).isEmpty)
    }
}
