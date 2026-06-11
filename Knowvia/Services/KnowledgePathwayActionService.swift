import Foundation

struct KnowledgePathwayAction: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let priority: Int
}

struct KnowledgePathwayActionService {
    func actions(
        for pathway: KnowledgePathway,
        cards: [KnowledgeCard],
        relations: [KnowledgeRelation],
        documents: [DocumentItem] = []
    ) -> [KnowledgePathwayAction] {
        let pathwayCards = cards.filter { pathway.knowledgeCardIDs.contains($0.id) }
        let pathwayRelations = relations.filter { $0.pathwayID == pathway.id }
        let pathwayDocuments = documents.filter { pathway.sourceDocumentIDs.contains($0.id) }
        let candidateDocuments = documents.filter { pathway.candidateDocumentIDs.contains($0.id) }
        let cardsByID = Dictionary(uniqueKeysWithValues: pathwayCards.map { ($0.id, $0) })
        let sourceFolderService = PathwaySourceFolderService()

        var actions: [KnowledgePathwayAction] = []

        let concepts = pathwayCards.filter { $0.kind == .concept }
        actions.append(
            KnowledgePathwayAction(
                id: "review-concepts",
                title: "复习 \(concepts.count) 个核心概念",
                detail: concepts.isEmpty
                    ? "补充至少一个概念节点，明确专题中的关键术语和边界。"
                    : "检查定义、术语边界和容易混淆的相邻概念。",
                priority: concepts.isEmpty ? 10 : 40
            )
        )

        let arguments = pathwayCards.filter { [.argument, .summary].contains($0.kind) }
        actions.append(
            KnowledgePathwayAction(
                id: "organize-arguments",
                title: "梳理 \(arguments.count) 条主要观点",
                detail: arguments.isEmpty
                    ? "从来源资料或摘要中提取至少一条可讨论的核心判断。"
                    : "检查观点之间的支持、挑战、扩展或相关关系。",
                priority: arguments.isEmpty ? 20 : 50
            )
        )

        let evidence = pathwayCards.filter { [.evidence, .quote].contains($0.kind) }
        actions.append(
            KnowledgePathwayAction(
                id: "verify-evidence",
                title: "核验 \(evidence.count) 条证据或摘录",
                detail: evidence.isEmpty
                    ? "回到原文补充证据节点，让关键判断可追溯。"
                    : "回到原文确认上下文、页码和证据适用范围。",
                priority: evidence.isEmpty ? 30 : 60
            )
        )

        let unsupportedClaims = arguments.filter { claim in
            !pathwayRelations.contains { relation in
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
        if !unsupportedClaims.isEmpty {
            actions.append(
                KnowledgePathwayAction(
                    id: "connect-claims-evidence",
                    title: "连接 \(unsupportedClaims.count) 条观点与证据",
                    detail: "为关键观点建立支持证据，或标记仍需核验的判断。",
                    priority: 5
                )
            )
        }

        let pendingCards = pathwayCards.filter { $0.calibrationState != .confirmed }
        if !pendingCards.isEmpty {
            actions.append(
                KnowledgePathwayAction(
                    id: "calibrate-nodes",
                    title: "校准 \(pendingCards.count) 个知识节点",
                    detail: "确认 AI 草稿、重点节点和需要继续跟进的内容。",
                    priority: 15
                )
            )
        }

        let unverifiedDocuments = pathwayDocuments.filter {
            [.unreviewed, .needsVerification].contains($0.credibility)
        }
        if !unverifiedDocuments.isEmpty {
            actions.append(
                KnowledgePathwayAction(
                    id: "verify-sources",
                    title: "核验 \(unverifiedDocuments.count) 份来源资料",
                    detail: "确认作者、年份、网页链接和可信度，优先处理关键来源。",
                    priority: 25
                )
            )
        }

        let incompleteDocuments = sourceFolderService.filter(pathwayDocuments, quality: .missingMetadata)
        if !incompleteDocuments.isEmpty {
            actions.append(
                KnowledgePathwayAction(
                    id: "complete-source-metadata",
                    title: "补全 \(incompleteDocuments.count) 份来源元数据",
                    detail: "补充作者、年份和网页链接，让报告来源列表更适合核验与引用。",
                    priority: 28
                )
            )
        }

        if !candidateDocuments.isEmpty {
            let firstAdvice = candidateDocuments
                .map { sourceFolderService.candidateAdvice(for: $0) }
                .sorted { $0.priority < $1.priority }
                .first
            actions.append(
                KnowledgePathwayAction(
                    id: "process-candidates",
                    title: "处理 \(candidateDocuments.count) 份外部补全候选",
                    detail: firstAdvice.map { "\($0.title)：\($0.detail)" }
                        ?? "阅读候选资料后，决定纳入正式路径或移出候选区。",
                    priority: 35
                )
            )
        }

        let questions = pathwayCards.filter { $0.kind == .question }
        actions.append(
            KnowledgePathwayAction(
                id: "resolve-questions",
                title: "处理 \(questions.count) 个待补全问题",
                detail: questions.isEmpty
                    ? "主动记录尚未澄清的概念、证据缺口或应用边界。"
                    : "为问题寻找定义、证据、应用案例或不同观点。",
                priority: questions.isEmpty ? 70 : 45
            )
        )

        return actions.sorted {
            if $0.priority == $1.priority {
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
            return $0.priority < $1.priority
        }
    }
}
