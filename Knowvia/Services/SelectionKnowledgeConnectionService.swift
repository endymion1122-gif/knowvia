import Foundation

struct SelectionKnowledgeConnections {
    let documents: [DocumentItem]
    let cards: [KnowledgeCard]

    var isEmpty: Bool {
        documents.isEmpty && cards.isEmpty
    }
}

struct SelectionKnowledgeConnectionService {
    func connections(
        for selectedText: String,
        activeDocumentID: UUID?,
        documents: [DocumentItem],
        cards: [KnowledgeCard]
    ) -> SelectionKnowledgeConnections {
        let searchTerms = searchTerms(for: selectedText)
        guard !searchTerms.isEmpty else {
            return SelectionKnowledgeConnections(documents: [], cards: [])
        }

        let matchingDocuments = documents.filter { document in
            document.id != activeDocumentID
                && containsAnyTerm(
                    in: [document.title, document.extractedText, document.summary],
                    searchTerms: searchTerms
                )
        }

        let matchingCards = cards.filter { card in
            containsAnyTerm(
                in: [card.title, card.content, card.summary, card.sourceDocumentTitle],
                searchTerms: searchTerms
            )
        }

        return SelectionKnowledgeConnections(
            documents: matchingDocuments,
            cards: matchingCards
        )
    }

    private func searchTerms(for selectedText: String) -> [String] {
        let normalizedText = selectedText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.count >= 2 else {
            return []
        }

        let shortSegments = normalizedText
            .components(separatedBy: CharacterSet(charactersIn: "，。！？；,.!?;：:"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { (2...32).contains($0.count) }

        return Array(Set([normalizedText] + shortSegments))
    }

    private func containsAnyTerm(
        in values: [String?],
        searchTerms: [String]
    ) -> Bool {
        let searchableText = values
            .compactMap { $0 }
            .joined(separator: "\n")
        return searchTerms.contains { searchableText.localizedCaseInsensitiveContains($0) }
    }
}
