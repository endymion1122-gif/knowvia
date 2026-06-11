import Foundation

struct SimilarCard: Identifiable {
    let card: KnowledgeCard
    let score: Double

    var id: UUID { card.id }
}

struct ConceptSimilarityService {

    /// Returns the top N most similar cards from the pool, excluding the source card.
    func findSimilar(
        to card: KnowledgeCard,
        in pool: [KnowledgeCard],
        maxCount: Int = 5,
        minScore: Double = 0.05
    ) -> [SimilarCard] {
        let candidates = pool.filter { $0.id != card.id }
        guard !candidates.isEmpty else { return [] }

        let documents = candidates.map { tokenize($0) }
        let query = tokenize(card)
        let idf = computeIDF(documents: documents)

        let queryVector = tfidfVector(tokens: query, idf: idf)
        let candidateVectors = documents.map { tfidfVector(tokens: $0, idf: idf) }

        return zip(candidates, candidateVectors)
            .map { card, vector in
                SimilarCard(card: card, score: cosineSimilarity(queryVector, vector))
            }
            .filter { $0.score >= minScore }
            .sorted { $0.score > $1.score }
            .prefix(maxCount)
            .map { $0 }
    }

    /// Returns cross-pathway similar cards — cards that are similar but belong to different pathways.
    func crossPathwaySimilar(
        to card: KnowledgeCard,
        in pool: [KnowledgeCard],
        maxCount: Int = 3
    ) -> [SimilarCard] {
        findSimilar(to: card, in: pool, maxCount: maxCount)
            .filter { similar in
                let sourcePathways = Set(card.pathwayIDs)
                let targetPathways = Set(similar.card.pathwayIDs)
                return sourcePathways.isDisjoint(with: targetPathways)
                    || (sourcePathways.isEmpty && !targetPathways.isEmpty)
                    || (!sourcePathways.isEmpty && targetPathways.isEmpty)
            }
    }

    // MARK: - Tokenization

    private func tokenize(_ card: KnowledgeCard) -> [String] {
        let text = [card.title, card.content]
            .joined(separator: " ")
            .lowercased()

        // Split into space-delimited words first (for English text)
        let spaceDelimited = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var tokens: [String] = []
        for segment in spaceDelimited {
            // Check if segment contains CJK characters
            if segment.unicodeScalars.contains(where: isCJK) {
                // Character bigrams for Chinese text
                let chars = Array(segment).map(String.init)
                if chars.count == 1 {
                    tokens.append(segment)
                } else {
                    for i in 0..<(chars.count - 1) {
                        tokens.append("\(chars[i])\(chars[i + 1])")
                    }
                    // Also add individual chars for partial matching
                    tokens.append(contentsOf: chars)
                }
            } else {
                // Word tokenization for English text
                let words = segment
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count >= 2 }
                tokens.append(contentsOf: words)
                // Bigrams
                if words.count > 1 {
                    for i in 0..<(words.count - 1) {
                        tokens.append("\(words[i])_\(words[i + 1])")
                    }
                }
            }
        }
        return tokens
    }

    private func isCJK(_ scalar: UnicodeScalar) -> Bool {
        let value = scalar.value
        return (0x4E00...0x9FFF).contains(value)      // CJK Unified
            || (0x3400...0x4DBF).contains(value)      // CJK Extension A
            || (0x20000...0x2A6DF).contains(value)    // CJK Extension B
            || (0xF900...0xFAFF).contains(value)      // CJK Compatibility
            || (0x2F800...0x2FA1F).contains(value)    // CJK Compatibility Supplement
            || (0x3000...0x303F).contains(value)      // CJK Symbols
            || (0xFF00...0xFFEF).contains(value)      // Halfwidth/Fullwidth
            || (0x3040...0x309F).contains(value)      // Hiragana
            || (0x30A0...0x30FF).contains(value)      // Katakana
    }

    // MARK: - TF-IDF

    private func computeIDF(documents: [[String]]) -> [String: Double] {
        let documentCount = Double(documents.count)
        guard documentCount > 0 else { return [:] }

        var documentFrequency: [String: Int] = [:]
        for doc in documents {
            let uniqueTokens = Set(doc)
            for token in uniqueTokens {
                documentFrequency[token, default: 0] += 1
            }
        }

        return documentFrequency.mapValues { count in
            natLog((documentCount + 1) / (Double(count) + 1)) + 1
        }
    }

    private func tfidfVector(tokens: [String], idf: [String: Double]) -> [String: Double] {
        var tf: [String: Double] = [:]
        for token in tokens {
            tf[token, default: 0] += 1
        }
        let maxTF = tf.values.max() ?? 1
        return Dictionary(uniqueKeysWithValues: tf.map { key, value in
            (key, (value / maxTF) * (idf[key] ?? 0))
        })
    }

    // MARK: - Cosine Similarity

    private func cosineSimilarity(_ a: [String: Double], _ b: [String: Double]) -> Double {
        let allKeys = Set(a.keys).union(b.keys)
        var dotProduct: Double = 0
        var normA: Double = 0
        var normB: Double = 0

        for key in allKeys {
            let valA = a[key] ?? 0
            let valB = b[key] ?? 0
            dotProduct += valA * valB
            normA += valA * valA
            normB += valB * valB
        }

        guard normA > 0, normB > 0 else { return 0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }

    private func natLog(_ value: Double) -> Double {
        Darwin.log(value)
    }
}
