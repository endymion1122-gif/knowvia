import Foundation

enum KnowledgePathwayGapKind: String {
    case missingOverview
    case missingSources
    case missingConcepts
    case missingEvidence
    case sourceTraceability
    case missingSourceMetadata
    case unverifiedSources
    case missingAuthoritativeSources
    case pendingExternalCandidates
    case pendingCalibration
    case unsupportedClaims
    case openQuestions
}

struct KnowledgePathwayGap: Identifiable, Equatable {
    let kind: KnowledgePathwayGapKind
    let title: String
    let detail: String

    var id: String { kind.rawValue }
}

struct KnowledgePathwayGapService {
    func gaps(
        for pathway: KnowledgePathway,
        cards: [KnowledgeCard],
        relations: [KnowledgeRelation],
        documents: [DocumentItem] = []
    ) -> [KnowledgePathwayGap] {
        let pathwayCards = cards.filter { pathway.knowledgeCardIDs.contains($0.id) }
        let pathwayRelations = relations.filter { $0.pathwayID == pathway.id }
        let pathwayDocuments = documents.filter { pathway.sourceDocumentIDs.contains($0.id) }
        let candidateDocuments = documents.filter { pathway.candidateDocumentIDs.contains($0.id) }
        let cardsByID = Dictionary(uniqueKeysWithValues: pathwayCards.map { ($0.id, $0) })
        var gaps: [KnowledgePathwayGap] = []

        if pathway.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            gaps.append(
                KnowledgePathwayGap(
                    kind: .missingOverview,
                    title: "专题总览尚待补充",
                    detail: "先写清楚当前路径关注的核心问题和知识边界。"
                )
            )
        }

        if pathway.sourceDocumentIDs.isEmpty {
            gaps.append(
                KnowledgePathwayGap(
                    kind: .missingSources,
                    title: "还没有来源资料",
                    detail: "加入论文、课程资料或笔记，让节点能够回到来源核验。"
                )
            )
        }

        if !pathwayCards.contains(where: { $0.kind == .concept }) {
            gaps.append(
                KnowledgePathwayGap(
                    kind: .missingConcepts,
                    title: "缺少核心概念",
                    detail: "补充至少一个概念节点，明确专题中的关键术语。"
                )
            )
        }

        if !pathwayCards.contains(where: { $0.kind == .evidence }) {
            gaps.append(
                KnowledgePathwayGap(
                    kind: .missingEvidence,
                    title: "缺少关键证据",
                    detail: "从原文摘录或研究结果中补充证据节点。"
                )
            )
        }

        let cardsWithoutSource = pathwayCards.filter { $0.sourceDocumentId == nil }
        if !cardsWithoutSource.isEmpty {
            gaps.append(
                KnowledgePathwayGap(
                    kind: .sourceTraceability,
                    title: "\(cardsWithoutSource.count) 个节点缺少来源",
                    detail: "为重要观点和证据补充来源资料与页码。"
                )
            )
        }

        if !pathwayDocuments.isEmpty {
            let incompleteDocuments = pathwayDocuments.filter {
                $0.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || $0.publicationYear == nil
                    || ($0.sourceType == .webPage && $0.sourceURLString.isEmpty)
            }
            if !incompleteDocuments.isEmpty {
                gaps.append(
                    KnowledgePathwayGap(
                        kind: .missingSourceMetadata,
                        title: "\(incompleteDocuments.count) 份来源元数据待补充",
                        detail: "补全作者、年份和网页链接，让来源列表更适合后续核验与写作引用。"
                    )
                )
            }

            let unverifiedDocuments = pathwayDocuments.filter {
                [.unreviewed, .needsVerification].contains($0.credibility)
            }
            if !unverifiedDocuments.isEmpty {
                gaps.append(
                    KnowledgePathwayGap(
                        kind: .unverifiedSources,
                        title: "\(unverifiedDocuments.count) 份来源仍需核验",
                        detail: "阅读原文并确认可信度，重要结论优先回到权威来源。"
                    )
                )
            }

            if !pathwayDocuments.contains(where: { $0.credibility == .authoritative }) {
                gaps.append(
                    KnowledgePathwayGap(
                        kind: .missingAuthoritativeSources,
                        title: "尚未标记权威来源",
                        detail: "为专题补充或确认至少一份核心权威来源，帮助校准关键观点。"
                    )
                )
            }
        }

        if !candidateDocuments.isEmpty {
            gaps.append(
                KnowledgePathwayGap(
                    kind: .pendingExternalCandidates,
                    title: "\(candidateDocuments.count) 份外部补全候选待处理",
                    detail: "阅读候选资料后，决定纳入正式路径或移出候选区。"
                )
            )
        }

        let pendingCards = pathwayCards.filter { $0.calibrationState != .confirmed }
        if !pendingCards.isEmpty {
            gaps.append(
                KnowledgePathwayGap(
                    kind: .pendingCalibration,
                    title: "\(pendingCards.count) 个节点仍待校准",
                    detail: "逐步确认 AI 草稿、重点节点和需要继续跟进的内容。"
                )
            )
        }

        let unsupportedClaims = pathwayCards.filter { card in
            guard card.kind == .argument else {
                return false
            }
            return !pathwayRelations.contains { relation in
                guard relation.kind == .supports else {
                    return false
                }
                if relation.sourceCardID == card.id {
                    return cardsByID[relation.targetCardID]?.kind == .evidence
                }
                if relation.targetCardID == card.id {
                    return cardsByID[relation.sourceCardID]?.kind == .evidence
                }
                return false
            }
        }
        if !unsupportedClaims.isEmpty {
            gaps.append(
                KnowledgePathwayGap(
                    kind: .unsupportedClaims,
                    title: "\(unsupportedClaims.count) 条观点尚未连接证据",
                    detail: "为关键判断补充支持证据，或标记仍需核验。"
                )
            )
        }

        let questions = pathwayCards.filter { $0.kind == .question }
        if !questions.isEmpty {
            gaps.append(
                KnowledgePathwayGap(
                    kind: .openQuestions,
                    title: "\(questions.count) 个问题仍待补全",
                    detail: "继续寻找定义、证据、应用案例或不同观点。"
                )
            )
        }

        return gaps
    }
}

enum KnowledgePathwayWritingReadinessStatus: String {
    case ready
    case attention
    case blocker

    var title: String {
        switch self {
        case .ready: "已准备"
        case .attention: "需留意"
        case .blocker: "需补全"
        }
    }
}

struct KnowledgePathwayWritingReadinessCheck: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let status: KnowledgePathwayWritingReadinessStatus
}

struct KnowledgePathwayWritingReadinessService {
    func checks(
        for pathway: KnowledgePathway,
        cards: [KnowledgeCard],
        relations: [KnowledgeRelation],
        documents: [DocumentItem] = []
    ) -> [KnowledgePathwayWritingReadinessCheck] {
        let pathwayCards = cards.filter { pathway.knowledgeCardIDs.contains($0.id) }
        let pathwayRelations = relations.filter { $0.pathwayID == pathway.id }
        let pathwayDocuments = documents.filter { pathway.sourceDocumentIDs.contains($0.id) }
        let cardsByID = Dictionary(uniqueKeysWithValues: pathwayCards.map { ($0.id, $0) })
        let sourceFolderService = PathwaySourceFolderService()

        let claims = pathwayCards.filter { [.argument, .summary].contains($0.kind) }
        let supportedClaims = claims.filter { claim in
            pathwayRelations.contains { relation in
                guard relation.kind == .supports else {
                    return false
                }
                if relation.sourceCardID == claim.id {
                    return cardsByID[relation.targetCardID]?.kind == .evidence
                }
                if relation.targetCardID == claim.id {
                    return cardsByID[relation.sourceCardID]?.kind == .evidence
                }
                return false
            }
        }

        let evidence = pathwayCards.filter { [.evidence, .quote].contains($0.kind) }
        let sourcedEvidence = evidence.filter { $0.sourceDocumentId != nil }
        let incompleteSources = sourceFolderService.filter(pathwayDocuments, quality: .missingMetadata)
        let unverifiedSources = sourceFolderService.filter(pathwayDocuments, quality: .needsVerification)
        let questions = pathwayCards.filter { $0.kind == .question }
        let unconfirmedCards = pathwayCards.filter { $0.calibrationState != .confirmed }

        return [
            KnowledgePathwayWritingReadinessCheck(
                id: "claims-supported",
                title: "观点有证据支撑",
                detail: claims.isEmpty
                    ? "还没有主要观点，先整理至少一条可讨论的判断。"
                    : "\(supportedClaims.count) / \(claims.count) 条观点已连接支持证据。",
                status: claims.isEmpty ? .blocker : supportedClaims.count == claims.count ? .ready : .attention
            ),
            KnowledgePathwayWritingReadinessCheck(
                id: "evidence-traceable",
                title: "证据可回到来源",
                detail: evidence.isEmpty
                    ? "还没有证据或摘录节点，写作前需要补充可追溯材料。"
                    : "\(sourcedEvidence.count) / \(evidence.count) 条证据带有来源记录。",
                status: evidence.isEmpty ? .blocker : sourcedEvidence.count == evidence.count ? .ready : .attention
            ),
            KnowledgePathwayWritingReadinessCheck(
                id: "sources-citable",
                title: "来源适合引用核验",
                detail: pathwayDocuments.isEmpty
                    ? "还没有正式来源，暂时不适合进入写作整理。"
                    : "\(incompleteSources.count) 份来源元数据待补，\(unverifiedSources.count) 份来源仍需核验。",
                status: pathwayDocuments.isEmpty
                    ? .blocker
                    : incompleteSources.isEmpty && unverifiedSources.isEmpty ? .ready : .attention
            ),
            KnowledgePathwayWritingReadinessCheck(
                id: "questions-resolved",
                title: "待补问题已处理",
                detail: questions.isEmpty
                    ? "当前没有问题节点阻塞写作准备。"
                    : "\(questions.count) 个问题仍待补全，建议先确认是否影响核心论述。",
                status: questions.isEmpty ? .ready : .attention
            ),
            KnowledgePathwayWritingReadinessCheck(
                id: "nodes-calibrated",
                title: "知识节点已校准",
                detail: unconfirmedCards.isEmpty
                    ? "所有路径节点均已确认。"
                    : "\(unconfirmedCards.count) 个节点仍待确认或跟进。",
                status: unconfirmedCards.isEmpty ? .ready : .attention
            ),
        ]
    }
}

struct KnowledgePathwayWritingOutlineSection: Identifiable, Equatable {
    let id: String
    let title: String
    let bullets: [String]
}

enum KnowledgePathwayWritingActionPriority: Int, Comparable {
    case high = 0
    case medium = 1
    case low = 2

    var title: String {
        switch self {
        case .high: "优先处理"
        case .medium: "继续补强"
        case .low: "写前确认"
        }
    }

    static func < (
        lhs: KnowledgePathwayWritingActionPriority,
        rhs: KnowledgePathwayWritingActionPriority
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct KnowledgePathwayWritingAction: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let priority: KnowledgePathwayWritingActionPriority
    let relatedCount: Int
    let relatedTitles: [String]
    let target: KnowledgePathwayWritingActionTarget?

    init(
        id: String,
        title: String,
        detail: String,
        priority: KnowledgePathwayWritingActionPriority,
        relatedCount: Int,
        relatedTitles: [String] = [],
        target: KnowledgePathwayWritingActionTarget? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.priority = priority
        self.relatedCount = relatedCount
        self.relatedTitles = relatedTitles
        self.target = target
    }
}

struct KnowledgePathwayWritingActionTarget: Equatable {
    let nodeKind: KnowledgeCardKind?
    let nodeSourceQuality: SourceQualityFilter?
    let sourceQuality: SourceQualityFilter?
    let focusesCandidates: Bool

    init(
        nodeKind: KnowledgeCardKind? = nil,
        nodeSourceQuality: SourceQualityFilter? = nil,
        sourceQuality: SourceQualityFilter? = nil,
        focusesCandidates: Bool = false
    ) {
        self.nodeKind = nodeKind
        self.nodeSourceQuality = nodeSourceQuality
        self.sourceQuality = sourceQuality
        self.focusesCandidates = focusesCandidates
    }
}

struct KnowledgePathwayWritingActionService {
    func actions(
        for pathway: KnowledgePathway,
        cards: [KnowledgeCard],
        relations: [KnowledgeRelation],
        documents: [DocumentItem] = []
    ) -> [KnowledgePathwayWritingAction] {
        let pathwayCards = cards.filter { pathway.knowledgeCardIDs.contains($0.id) }
        let pathwayDocuments = documents.filter { pathway.sourceDocumentIDs.contains($0.id) }
        let candidateDocuments = documents.filter { pathway.candidateDocumentIDs.contains($0.id) }
        let sourceFolderService = PathwaySourceFolderService()
        let nodeFilterService = KnowledgePathwayNodeFilterService()

        let checks = KnowledgePathwayWritingReadinessService().checks(
            for: pathway,
            cards: cards,
            relations: relations,
            documents: documents
        )
        var actions = checks.compactMap { action(for: $0) }

        let unverifiedClaims = nodeFilterService.filter(
            pathwayCards,
            documents: pathwayDocuments,
            kind: .argument,
            sourceQuality: .needsVerification
        )
        if !unverifiedClaims.isEmpty {
            actions.append(
                KnowledgePathwayWritingAction(
                    id: "verify-claim-sources",
                    title: "核验待引用观点来源",
                    detail: "有 \(unverifiedClaims.count) 条观点连接到待核验来源，写作前先确认出处是否可靠。",
                    priority: .high,
                    relatedCount: unverifiedClaims.count,
                    relatedTitles: previewTitles(unverifiedClaims),
                    target: KnowledgePathwayWritingActionTarget(
                        nodeKind: .argument,
                        nodeSourceQuality: .needsVerification
                    )
                )
            )
        }

        let incompleteEvidence = nodeFilterService.filter(
            pathwayCards,
            documents: pathwayDocuments,
            kind: .evidence,
            sourceQuality: .missingMetadata
        )
        if !incompleteEvidence.isEmpty {
            actions.append(
                KnowledgePathwayWritingAction(
                    id: "complete-evidence-metadata",
                    title: "补齐证据来源元数据",
                    detail: "有 \(incompleteEvidence.count) 条证据连接到作者或年份不完整的来源，先补齐再引用。",
                    priority: .medium,
                    relatedCount: incompleteEvidence.count,
                    relatedTitles: previewTitles(incompleteEvidence),
                    target: KnowledgePathwayWritingActionTarget(
                        nodeKind: .evidence,
                        nodeSourceQuality: .missingMetadata
                    )
                )
            )
        }

        let candidateCount = pathway.candidateDocumentIDs.count
        if candidateCount > 0 {
            actions.append(
                KnowledgePathwayWritingAction(
                    id: "review-candidate-sources",
                    title: "处理外部补全候选",
                    detail: "还有 \(candidateCount) 份候选资料未决定是否纳入正式来源。",
                    priority: .low,
                    relatedCount: candidateCount,
                    relatedTitles: previewTitles(candidateDocuments),
                    target: KnowledgePathwayWritingActionTarget(focusesCandidates: true)
                )
            )
        }

        let unverifiedSources = sourceFolderService.filter(pathwayDocuments, quality: .needsVerification)
        if !unverifiedSources.isEmpty {
            actions.append(
                KnowledgePathwayWritingAction(
                    id: "verify-source-folder",
                    title: "集中核验来源资料夹",
                    detail: "来源资料夹中仍有 \(unverifiedSources.count) 份资料处于待核验状态。",
                    priority: .medium,
                    relatedCount: unverifiedSources.count,
                    relatedTitles: previewTitles(unverifiedSources),
                    target: KnowledgePathwayWritingActionTarget(sourceQuality: .needsVerification)
                )
            )
        }

        return actions
            .uniquedByID()
            .sorted {
                if $0.priority == $1.priority {
                    return $0.title.localizedCompare($1.title) == .orderedAscending
                }
                return $0.priority < $1.priority
            }
    }

    private func action(
        for check: KnowledgePathwayWritingReadinessCheck
    ) -> KnowledgePathwayWritingAction? {
        guard check.status != .ready else {
            return nil
        }

        switch check.id {
        case "claims-supported":
            return KnowledgePathwayWritingAction(
                id: "connect-claim-evidence",
                title: check.status == .blocker ? "整理至少一条核心观点" : "补齐观点与证据连接",
                detail: check.detail,
                priority: check.status == .blocker ? .high : .medium,
                relatedCount: 0,
                relatedTitles: [],
                target: check.status == .blocker
                    ? nil
                    : KnowledgePathwayWritingActionTarget(nodeKind: .argument)
            )
        case "evidence-traceable":
            return KnowledgePathwayWritingAction(
                id: "add-traceable-evidence",
                title: check.status == .blocker ? "补充可追溯证据" : "补齐证据来源记录",
                detail: check.detail,
                priority: check.status == .blocker ? .high : .medium,
                relatedCount: 0,
                relatedTitles: [],
                target: check.status == .blocker
                    ? nil
                    : KnowledgePathwayWritingActionTarget(nodeKind: .evidence)
            )
        case "sources-citable":
            return KnowledgePathwayWritingAction(
                id: "prepare-citable-sources",
                title: check.status == .blocker ? "加入正式来源资料" : "补全引用来源信息",
                detail: check.detail,
                priority: check.status == .blocker ? .high : .medium,
                relatedCount: 0,
                relatedTitles: [],
                target: check.status == .blocker
                    ? nil
                    : KnowledgePathwayWritingActionTarget(sourceQuality: .missingMetadata)
            )
        case "questions-resolved":
            return KnowledgePathwayWritingAction(
                id: "resolve-writing-questions",
                title: "处理仍待补全的问题",
                detail: check.detail,
                priority: .low,
                relatedCount: 0,
                relatedTitles: []
            )
        case "nodes-calibrated":
            return KnowledgePathwayWritingAction(
                id: "calibrate-writing-nodes",
                title: "确认待核验或需跟进节点",
                detail: check.detail,
                priority: .medium,
                relatedCount: 0,
                relatedTitles: []
            )
        default:
            return nil
        }
    }

    private func previewTitles(_ cards: [KnowledgeCard]) -> [String] {
        cards.prefix(3).map(\.title)
    }

    private func previewTitles(_ documents: [DocumentItem]) -> [String] {
        documents.prefix(3).map(\.title)
    }
}

struct KnowledgePathwayWritingOutlineService {
    func outline(
        for pathway: KnowledgePathway,
        cards: [KnowledgeCard],
        relations: [KnowledgeRelation]
    ) -> [KnowledgePathwayWritingOutlineSection] {
        let pathwayCards = cards.filter { pathway.knowledgeCardIDs.contains($0.id) }
        let pathwayRelations = relations.filter { $0.pathwayID == pathway.id }
        let concepts = pathwayCards.filter { $0.kind == .concept }
        let claims = pathwayCards.filter { [.argument, .summary].contains($0.kind) }
        let evidence = pathwayCards.filter { [.evidence, .quote].contains($0.kind) }
        let questions = pathwayCards.filter { $0.kind == .question }
        let cardsByID = Dictionary(uniqueKeysWithValues: pathwayCards.map { ($0.id, $0) })

        let claimBullets = claims.map { claim in
            let supportingEvidence = pathwayRelations.compactMap { relation -> KnowledgeCard? in
                guard relation.kind == .supports else {
                    return nil
                }
                if relation.sourceCardID == claim.id {
                    let target = cardsByID[relation.targetCardID]
                    return target?.kind == .evidence ? target : nil
                }
                if relation.targetCardID == claim.id {
                    let source = cardsByID[relation.sourceCardID]
                    return source?.kind == .evidence ? source : nil
                }
                return nil
            }
            let evidenceText = supportingEvidence.isEmpty
                ? "证据待连接"
                : "支持证据：\(supportingEvidence.prefix(3).map(\.title).joined(separator: "；"))"
            return "\(claim.title)：\(evidenceText)"
        }

        return [
            KnowledgePathwayWritingOutlineSection(
                id: "scope",
                title: "问题界定与概念边界",
                bullets: scopeBullets(pathway: pathway, concepts: concepts)
            ),
            KnowledgePathwayWritingOutlineSection(
                id: "claims",
                title: "核心论点安排",
                bullets: claimBullets.isEmpty ? ["尚未整理主要观点。"] : claimBullets
            ),
            KnowledgePathwayWritingOutlineSection(
                id: "evidence",
                title: "证据与来源材料",
                bullets: evidence.isEmpty
                    ? ["尚未补充证据或摘录节点。"]
                    : evidence.map { evidenceBullet(for: $0) }
            ),
            KnowledgePathwayWritingOutlineSection(
                id: "questions",
                title: "写作前待处理问题",
                bullets: questions.isEmpty
                    ? ["当前没有问题节点阻塞写作准备。"]
                    : questions.map { "\($0.title)：\($0.content)" }
            ),
        ]
    }

    private func scopeBullets(
        pathway: KnowledgePathway,
        concepts: [KnowledgeCard]
    ) -> [String] {
        var bullets: [String] = []
        let overview = pathway.overview.trimmingCharacters(in: .whitespacesAndNewlines)
        bullets.append(overview.isEmpty ? "专题总览尚待补充。" : overview)

        if concepts.isEmpty {
            bullets.append("尚未整理核心概念。")
        } else {
            bullets.append("核心概念：\(concepts.prefix(5).map(\.title).joined(separator: "；"))")
        }
        return bullets
    }

    private func evidenceBullet(for card: KnowledgeCard) -> String {
        let source = card.sourceDescription.map { "｜\($0)" } ?? "｜来源待补充"
        return "\(card.title)\(source)"
    }
}

private extension Array where Element == KnowledgePathwayWritingAction {
    func uniquedByID() -> [KnowledgePathwayWritingAction] {
        var seenIDs: Set<String> = []
        return filter { action in
            seenIDs.insert(action.id).inserted
        }
    }
}

struct KnowledgePathwayNodeFilterService {
    func filter(
        _ cards: [KnowledgeCard],
        documents: [DocumentItem],
        kind: KnowledgeCardKind? = nil,
        sourceQuality: SourceQualityFilter? = nil
    ) -> [KnowledgeCard] {
        let documentsByID = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        let sourceFolderService = PathwaySourceFolderService()
        return cards.filter { card in
            let matchesKind = kind == nil || card.kind == kind
            let matchesSourceQuality: Bool
            if let sourceQuality {
                guard
                    let sourceDocumentId = card.sourceDocumentId,
                    let document = documentsByID[sourceDocumentId]
                else {
                    return false
                }
                matchesSourceQuality = sourceFolderService.filter(
                    [document],
                    quality: sourceQuality
                ).contains { $0.id == document.id }
            } else {
                matchesSourceQuality = true
            }
            return matchesKind && matchesSourceQuality
        }
        .sorted { lhs, rhs in
            if lhs.kind == rhs.kind {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.kind.title.localizedCompare(rhs.kind.title) == .orderedAscending
        }
    }
}
