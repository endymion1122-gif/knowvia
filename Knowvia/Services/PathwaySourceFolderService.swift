import Foundation

struct SourceQualityOverview: Equatable {
    let totalSources: Int
    let authoritativeSources: Int
    let unverifiedSources: Int
    let completeMetadataSources: Int
    let candidateSources: Int

    var metadataCompletionRatio: Double {
        guard totalSources > 0 else {
            return 0
        }
        return Double(completeMetadataSources) / Double(totalSources)
    }

    var verificationRatio: Double {
        guard totalSources > 0 else {
            return 0
        }
        return Double(totalSources - unverifiedSources) / Double(totalSources)
    }
}

enum SourceQualityFilter: String, CaseIterable, Identifiable {
    case needsVerification
    case missingMetadata
    case authoritative

    var id: String { rawValue }

    var title: String {
        switch self {
        case .needsVerification: "待核验来源"
        case .missingMetadata: "缺作者年份"
        case .authoritative: "权威来源"
        }
    }
}

struct ExternalCandidateAdvice: Equatable {
    let title: String
    let detail: String
    let priority: Int
}

struct PathwaySourceFolderService {
    func filter(
        _ documents: [DocumentItem],
        query: String = "",
        sourceKind: DocumentSourceKind? = nil,
        credibility: SourceCredibilityLevel? = nil,
        quality: SourceQualityFilter? = nil
    ) -> [DocumentItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return documents
            .filter { document in
                let matchesKind = sourceKind == nil || document.sourceType == sourceKind
                let matchesCredibility = credibility == nil || document.credibility == credibility
                let matchesQuality = quality == nil || matches(document, quality: quality)
                let matchesQuery = normalizedQuery.isEmpty
                    || searchableText(for: document).localizedCaseInsensitiveContains(normalizedQuery)
                return matchesKind && matchesCredibility && matchesQuality && matchesQuery
            }
            .sorted { lhs, rhs in
                if lhs.credibility == rhs.credibility {
                    return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                }
                return credibilityRank(lhs.credibility) < credibilityRank(rhs.credibility)
            }
    }

    func relatedCards(
        for document: DocumentItem,
        in cards: [KnowledgeCard]
    ) -> [KnowledgeCard] {
        cards
            .filter { $0.sourceDocumentId == document.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func qualityOverview(
        sources: [DocumentItem],
        candidates: [DocumentItem]
    ) -> SourceQualityOverview {
        SourceQualityOverview(
            totalSources: sources.count,
            authoritativeSources: sources.filter { $0.credibility == .authoritative }.count,
            unverifiedSources: sources.filter { [.unreviewed, .needsVerification].contains($0.credibility) }.count,
            completeMetadataSources: sources.filter(hasCompleteMetadata).count,
            candidateSources: candidates.count
        )
    }

    func candidateAdvice(for document: DocumentItem) -> ExternalCandidateAdvice {
        if document.sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ExternalCandidateAdvice(
                title: "先补链接或来源线索",
                detail: "缺少可回溯链接时，先补充网址、书名或出处，再决定是否纳入路径。",
                priority: 10
            )
        }

        if !hasCompleteMetadata(document) {
            return ExternalCandidateAdvice(
                title: "补全作者与年份",
                detail: "纳入正式路径前，建议补充作者、年份和网页链接，降低后续引用核验成本。",
                priority: 20
            )
        }

        if document.sourceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && document.contributionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ExternalCandidateAdvice(
                title: "记录纳入理由",
                detail: "写一句它能补哪类缺口：定义、证据、案例、不同观点或背景资料。",
                priority: 30
            )
        }

        return ExternalCandidateAdvice(
            title: "阅读后再纳入路径",
            detail: "如果正文能支持当前专题问题，就纳入正式来源；否则保留为候选或移出。",
            priority: 40
        )
    }

    private func searchableText(for document: DocumentItem) -> String {
        [
            document.title,
            document.author,
            document.publicationYear.map(String.init) ?? "",
            document.sourceURLString,
            document.sourceNote,
            document.contributionNote,
            document.tags.joined(separator: " "),
        ]
        .joined(separator: " ")
    }

    private func credibilityRank(_ credibility: SourceCredibilityLevel) -> Int {
        switch credibility {
        case .needsVerification: 0
        case .unreviewed: 1
        case .userProvided: 2
        case .authoritative: 3
        }
    }

    private func matches(_ document: DocumentItem, quality: SourceQualityFilter?) -> Bool {
        switch quality {
        case nil:
            true
        case .needsVerification:
            [.unreviewed, .needsVerification].contains(document.credibility)
        case .missingMetadata:
            !hasCompleteMetadata(document)
        case .authoritative:
            document.credibility == .authoritative
        }
    }

    private func hasCompleteMetadata(_ document: DocumentItem) -> Bool {
        !document.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && document.publicationYear != nil
            && (document.sourceType != .webPage || !document.sourceURLString.isEmpty)
    }
}
