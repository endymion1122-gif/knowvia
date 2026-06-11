import Foundation

struct KnowledgeCardTopicGroup: Identifiable {
    let topic: String
    let cards: [KnowledgeCard]

    var id: String { topic }
}

struct KnowledgeCardTopicService {
    static let uncategorizedTopic = "未归类"

    func availableTopics(in cards: [KnowledgeCard]) -> [String] {
        LearningPathService().availableTopics(in: cards)
    }

    func topics(for card: KnowledgeCard) -> [String] {
        normalizedTopics(
            card.tags.filter { !LearningPathService.reservedTags.contains($0) }
        )
    }

    func groups(in cards: [KnowledgeCard]) -> [KnowledgeCardTopicGroup] {
        let availableTopics = availableTopics(in: cards)
        var groups = availableTopics.map { topic in
            KnowledgeCardTopicGroup(
                topic: topic,
                cards: cards.filter { $0.tags.contains(topic) }
            )
        }

        let uncategorizedCards = cards.filter { topics(for: $0).isEmpty }
        if !uncategorizedCards.isEmpty {
            groups.append(
                KnowledgeCardTopicGroup(
                    topic: Self.uncategorizedTopic,
                    cards: uncategorizedCards
                )
            )
        }
        return groups
    }

    func assignTopics(_ topics: [String], to card: KnowledgeCard) {
        let reservedTags = card.tags.filter { LearningPathService.reservedTags.contains($0) }
        card.tags = reservedTags + normalizedTopics(topics)
        card.updatedAt = Date()
    }

    private func normalizedTopics(_ topics: [String]) -> [String] {
        Array(
            Set(
                topics
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !LearningPathService.reservedTags.contains($0) }
            )
        )
        .sorted()
    }
}
