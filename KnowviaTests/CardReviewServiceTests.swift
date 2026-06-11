import Foundation
import XCTest
@testable import Knowvia

final class CardReviewServiceTests: XCTestCase {
    private let service = CardReviewService()

    // MARK: - Due Detection

    func testCardWithNoNextReviewAtIsDue() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")
        XCTAssertTrue(service.isDue(card))
    }

    func testCardWithPastNextReviewAtIsDue() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")
        card.nextReviewAt = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        XCTAssertTrue(service.isDue(card))
    }

    func testCardWithFutureNextReviewAtIsNotDue() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")
        card.nextReviewAt = Date(timeIntervalSinceNow: 3600) // 1 hour from now
        XCTAssertFalse(service.isDue(card))
    }

    func testCardWithNowAsNextReviewAtIsDue() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")
        card.nextReviewAt = Date()
        XCTAssertTrue(service.isDue(card))
    }

    // MARK: - Due Cards Filtering

    func testDueCardsReturnsOnlyDueCardsSortedByUrgency() {
        let now = Date()
        let overdueCard = TestFactories.makeKnowledgeCard(title: "Overdue")
        overdueCard.nextReviewAt = now.addingTimeInterval(-7200) // 2 hours ago

        let dueNowCard = TestFactories.makeKnowledgeCard(title: "Due Now")
        dueNowCard.nextReviewAt = now

        let futureCard = TestFactories.makeKnowledgeCard(title: "Future")
        futureCard.nextReviewAt = now.addingTimeInterval(86_400) // 1 day from now

        let neverReviewed = TestFactories.makeKnowledgeCard(title: "Never")
        // nextReviewAt is nil → most urgent

        let dueCards = service.dueCards(in: [futureCard, overdueCard, neverReviewed, dueNowCard], now: now)

        XCTAssertEqual(dueCards.count, 3)
        XCTAssertFalse(dueCards.map(\.id).contains(futureCard.id))
        // Never-reviewed cards (nil nextReviewAt) should be first
        XCTAssertEqual(dueCards.first?.id, neverReviewed.id)
    }

    func testDueCardsEmptyWhenAllCardsAreInFuture() {
        let now = Date()
        let cards = [
            TestFactories.makeKnowledgeCard(title: "A"),
            TestFactories.makeKnowledgeCard(title: "B"),
        ]
        cards.forEach { $0.nextReviewAt = now.addingTimeInterval(86_400) }

        let dueCards = service.dueCards(in: cards, now: now)
        XCTAssertTrue(dueCards.isEmpty)
    }

    // MARK: - Schedule Review

    func testScheduleReviewSetsAllFields() {
        let now = Date()
        let card = TestFactories.makeKnowledgeCard(title: "Test")

        service.scheduleReview(card, rating: .medium, now: now)

        XCTAssertEqual(card.lastReviewedAt, now)
        XCTAssertNotNil(card.nextReviewAt)
        XCTAssertEqual(card.reviewCount, 1)
        XCTAssertEqual(card.easeFactor, 2.5) // medium doesn't change ease
    }

    func testEasyRatingIncreasesEaseFactor() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")
        let originalEase = card.easeFactor

        service.scheduleReview(card, rating: .easy)

        XCTAssertEqual(card.easeFactor, originalEase + 0.15)
        XCTAssertEqual(card.reviewCount, 1)
    }

    func testHardRatingDecreasesEaseFactorWithMinimum() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")

        service.scheduleReview(card, rating: .hard)
        XCTAssertEqual(card.easeFactor, max(1.3, 2.5 - 0.15))

        // Test floor at 1.3
        card.easeFactor = 1.35
        service.scheduleReview(card, rating: .hard)
        XCTAssertEqual(card.easeFactor, 1.3)
    }

    func testEasyRatingProducesLongestInterval() {
        let now = Date()
        let easyCard = TestFactories.makeKnowledgeCard(title: "Easy")
        let mediumCard = TestFactories.makeKnowledgeCard(title: "Medium")
        let hardCard = TestFactories.makeKnowledgeCard(title: "Hard")

        // Give them a known review history
        easyCard.lastReviewedAt = now.addingTimeInterval(-86_400)
        mediumCard.lastReviewedAt = now.addingTimeInterval(-86_400)
        hardCard.lastReviewedAt = now.addingTimeInterval(-86_400)

        service.scheduleReview(easyCard, rating: .easy, now: now)
        service.scheduleReview(mediumCard, rating: .medium, now: now)
        service.scheduleReview(hardCard, rating: .hard, now: now)

        let easyInterval = easyCard.nextReviewAt!.timeIntervalSince(now)
        let mediumInterval = mediumCard.nextReviewAt!.timeIntervalSince(now)
        let hardInterval = hardCard.nextReviewAt!.timeIntervalSince(now)

        XCTAssertGreaterThan(easyInterval, mediumInterval)
        XCTAssertGreaterThan(mediumInterval, hardInterval)
    }

    func testReviewCountIncrementsWithEachReview() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")

        service.scheduleReview(card, rating: .medium)
        XCTAssertEqual(card.reviewCount, 1)

        service.scheduleReview(card, rating: .easy)
        XCTAssertEqual(card.reviewCount, 2)

        service.scheduleReview(card, rating: .hard)
        XCTAssertEqual(card.reviewCount, 3)
    }

    // MARK: - Next Review Description

    func testNextReviewDescriptionForUnreviewedCard() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")
        XCTAssertEqual(service.nextReviewDescription(for: card), "待复习")
    }

    func testNextReviewDescriptionForDueCard() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")
        card.nextReviewAt = Date(timeIntervalSinceNow: -60)
        XCTAssertEqual(service.nextReviewDescription(for: card), "现在")
    }

    func testNextReviewDescriptionForFutureReview() {
        let card = TestFactories.makeKnowledgeCard(title: "Test")
        card.nextReviewAt = Date(timeIntervalSinceNow: 2 * 86_400 + 3600) // 2 days + 1 hour
        XCTAssertTrue(service.nextReviewDescription(for: card).contains("天后"))
    }
}
