import Foundation

enum ReviewRating: String, CaseIterable {
    case easy
    case medium
    case hard

    var title: String {
        switch self {
        case .easy: "轻松"
        case .medium: "一般"
        case .hard: "困难"
        }
    }

    /// Interval multiplier applied to the current spacing.
    var multiplier: Double {
        switch self {
        case .easy: 1.5
        case .medium: 1.0
        case .hard: 0.5
        }
    }

    /// Adjustment to ease factor after rating.
    var easeDelta: Double {
        switch self {
        case .easy: 0.15
        case .medium: 0
        case .hard: -0.15
        }
    }
}

struct CardReviewService {
    /// Minimum interval between reviews (1 day).
    private let minimumInterval: TimeInterval = 86_400

    /// Cards whose `nextReviewAt` is nil or in the past are considered due.
    func isDue(_ card: KnowledgeCard, now: Date = Date()) -> Bool {
        guard let nextReview = card.nextReviewAt else {
            return true
        }
        return nextReview <= now
    }

    /// Returns cards that are due for review, sorted by urgency.
    func dueCards(in cards: [KnowledgeCard], now: Date = Date()) -> [KnowledgeCard] {
        cards
            .filter { isDue($0, now: now) }
            .sorted { dueDate($0).compare(dueDate($1)) == .orderedAscending }
    }

    /// Schedule the next review based on the user's rating.
    func scheduleReview(
        _ card: KnowledgeCard,
        rating: ReviewRating,
        now: Date = Date()
    ) {
        let previousInterval = intervalSinceLastReview(card, now: now)
        let newEaseFactor = max(1.3, card.easeFactor + rating.easeDelta)
        let newInterval = previousInterval * rating.multiplier * newEaseFactor
        let clampedInterval = max(minimumInterval, newInterval)

        card.lastReviewedAt = now
        card.nextReviewAt = now.addingTimeInterval(clampedInterval)
        card.reviewCount += 1
        card.easeFactor = newEaseFactor
        card.updatedAt = now
    }

    /// Human-readable description of when the card is next due.
    func nextReviewDescription(for card: KnowledgeCard, now: Date = Date()) -> String {
        guard let nextReview = card.nextReviewAt else {
            return "待复习"
        }
        if nextReview <= now {
            return "现在"
        }
        let interval = nextReview.timeIntervalSince(now)
        let hours = Int(interval / 3600)
        if hours < 24 {
            return "\(hours) 小时后"
        }
        let days = hours / 24
        return "\(days) 天后"
    }

    // MARK: - Helpers

    private func dueDate(_ card: KnowledgeCard) -> Date {
        card.nextReviewAt ?? .distantPast
    }

    private func intervalSinceLastReview(_ card: KnowledgeCard, now: Date) -> TimeInterval {
        guard let lastReview = card.lastReviewedAt else {
            return minimumInterval
        }
        let elapsed = now.timeIntervalSince(lastReview)
        return max(minimumInterval, elapsed)
    }
}
