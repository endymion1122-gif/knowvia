import SwiftData
import XCTest
@testable import Knowvia

@MainActor
final class KnowledgeCardPersistenceTests: XCTestCase {
    func testPersistsKnowledgeCardSourceMetadata() throws {
        let container = try TestModelContext.makeInMemoryContainer(for: KnowledgeCard.self)
        let context = container.mainContext
        let sourceDocumentId = UUID()
        let pathwayID = UUID()
        let card = TestFactories.makeKnowledgeCard(
            title: "Feedback loop",
            content: "Deliberate practice needs immediate feedback.",
            cardType: .quote,
            tags: ["practice"],
            sourceDocumentId: sourceDocumentId,
            sourceDocumentTitle: "Learning Notes",
            pageNumber: 12,
            pathwayIDs: [pathwayID],
            calibrationStatus: .confirmed,
            isHighlighted: true,
            isUnderstood: true,
            calibrationNote: "已结合原文确认。"
        )

        context.insert(card)
        try context.save()

        let cards = try context.fetch(FetchDescriptor<KnowledgeCard>())
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.kind, .quote)
        XCTAssertEqual(cards.first?.sourceDocumentId, sourceDocumentId)
        XCTAssertEqual(cards.first?.sourceDescription, "Learning Notes，p.12")
        XCTAssertEqual(cards.first?.pathwayIDs, [pathwayID])
        XCTAssertEqual(cards.first?.calibrationState, .confirmed)
        XCTAssertEqual(cards.first?.isHighlighted, true)
        XCTAssertEqual(cards.first?.isUnderstood, true)
        XCTAssertEqual(cards.first?.calibrationNote, "已结合原文确认。")
    }
}
