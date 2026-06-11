import SwiftData
import XCTest
@testable import Knowvia

@MainActor
final class KnowledgeCardPersistenceTests: XCTestCase {
    func testPersistsKnowledgeCardSourceMetadata() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: KnowledgeCard.self,
            configurations: configuration
        )
        let context = container.mainContext
        let sourceDocumentId = UUID()
        let pathwayID = UUID()
        let card = KnowledgeCard(
            title: "Feedback loop",
            content: "Deliberate practice needs immediate feedback.",
            cardType: KnowledgeCardKind.quote.rawValue,
            tags: ["practice"],
            sourceDocumentId: sourceDocumentId,
            sourceDocumentTitle: "Learning Notes",
            pageNumber: 12,
            pathwayIDs: [pathwayID],
            calibrationStatus: KnowledgeCardCalibrationStatus.confirmed.rawValue,
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
