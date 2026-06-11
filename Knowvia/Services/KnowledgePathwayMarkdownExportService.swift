import Foundation

enum KnowledgePathwayMarkdownExportError: LocalizedError, Equatable {
    case emptyPathway
    case cannotWriteFile

    var errorDescription: String? {
        switch self {
        case .emptyPathway:
            "当前专题还没有来源资料或知识节点，暂时无法导出报告。"
        case .cannotWriteFile:
            "无法写入专题报告，请检查保存位置后重试。"
        }
    }
}

struct KnowledgePathwayMarkdownExportService {
    func markdown(
        for pathway: KnowledgePathway,
        documents: [DocumentItem],
        cards: [KnowledgeCard],
        relations: [KnowledgeRelation],
        exportedAt: Date = Date()
    ) throws -> String {
        let pathwayDocuments = documents
            .filter { pathway.sourceDocumentIDs.contains($0.id) }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        let pathwayCards = cards
            .filter { pathway.knowledgeCardIDs.contains($0.id) }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        let candidateDocuments = documents
            .filter { pathway.candidateDocumentIDs.contains($0.id) }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        guard !pathwayDocuments.isEmpty || !pathwayCards.isEmpty || !candidateDocuments.isEmpty else {
            throw KnowledgePathwayMarkdownExportError.emptyPathway
        }

        let pathwayRelations = relations
            .filter { $0.pathwayID == pathway.id }
            .sorted { $0.updatedAt > $1.updatedAt }
        let cardsByID = Dictionary(uniqueKeysWithValues: pathwayCards.map { ($0.id, $0) })
        let resolvedRelations = pathwayRelations.compactMap { relation -> (KnowledgeRelation, KnowledgeCard, KnowledgeCard)? in
            guard
                let source = cardsByID[relation.sourceCardID],
                let target = cardsByID[relation.targetCardID]
            else {
                return nil
            }
            return (relation, source, target)
        }
        let gaps = KnowledgePathwayGapService().gaps(
            for: pathway,
            cards: pathwayCards,
            relations: pathwayRelations,
            documents: documents
        )
        let sourceQuality = PathwaySourceFolderService().qualityOverview(
            sources: pathwayDocuments,
            candidates: candidateDocuments
        )
        let actions = KnowledgePathwayActionService().actions(
            for: pathway,
            cards: pathwayCards,
            relations: pathwayRelations,
            documents: documents
        )
        let writingReadiness = KnowledgePathwayWritingReadinessService().checks(
            for: pathway,
            cards: cards,
            relations: relations,
            documents: documents
        )
        let writingOutline = KnowledgePathwayWritingOutlineService().outline(
            for: pathway,
            cards: cards,
            relations: relations
        )
        let writingActions = KnowledgePathwayWritingActionService().actions(
            for: pathway,
            cards: cards,
            relations: relations,
            documents: documents
        )

        var sections = [
            "# \(singleLine(pathway.title))",
            "",
            "> 知径 Knowvia 专题 Knowledge Pathway 报告 · 让知识成为路径。",
            "",
            "- 导出时间：\(timestamp(for: exportedAt))",
            "- 来源资料：\(pathwayDocuments.count) 份",
            "- 外部补全候选：\(candidateDocuments.count) 份",
            "- 知识节点：\(pathwayCards.count) 个",
            "- 节点关系：\(resolvedRelations.count) 条",
            "",
            "## 专题总览",
            "",
            pathway.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "尚未填写专题总览。"
                : pathway.overview.trimmingCharacters(in: .whitespacesAndNewlines),
        ]

        if !pathway.tags.isEmpty {
            sections.append(contentsOf: [
                "",
                "- 标签：\(pathway.tags.map(singleLine).joined(separator: "，"))",
            ])
        }

        sections.append(contentsOf: [
            "",
            "## 来源列表",
            "",
        ])
        appendSources(pathwayDocuments, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 来源质量概览",
            "",
        ])
        appendSourceQuality(sourceQuality, sources: pathwayDocuments, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 外部补全候选",
            "",
        ])
        appendCandidates(candidateDocuments, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 文献 / 资料贡献矩阵",
            "",
            "| 来源资料 | 类型 | 作者 / 年份 | 可信度 | 关联节点 | 主要贡献 |",
            "| --- | --- | --- | --- | ---: | --- |",
        ])
        appendContributionMatrix(pathwayDocuments, cards: pathwayCards, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 知识节点",
        ])
        appendNodeGroups(pathwayCards, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 轻量校准",
            "",
        ])
        appendCalibration(pathwayCards, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 待补全提示",
            "",
        ])
        appendGaps(gaps, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 写作准备度",
            "",
        ])
        appendWritingReadiness(writingReadiness, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 写作准备大纲",
            "",
        ])
        appendWritingOutline(writingOutline, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 写作行动清单",
            "",
        ])
        appendWritingActions(writingActions, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 节点关系",
            "",
        ])
        appendRelations(resolvedRelations, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 观点—证据链",
            "",
        ])
        appendClaimEvidencePairs(resolvedRelations, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 学习路径建议",
            "",
        ])
        appendLearningPath(actions, to: &sections)

        sections.append(contentsOf: [
            "",
            "## 待补全问题",
            "",
        ])
        appendOpenQuestions(pathwayCards, to: &sections)

        return sections.joined(separator: "\n") + "\n"
    }

    func export(
        pathway: KnowledgePathway,
        documents: [DocumentItem],
        cards: [KnowledgeCard],
        relations: [KnowledgeRelation],
        to url: URL,
        exportedAt: Date = Date()
    ) throws {
        let content = try markdown(
            for: pathway,
            documents: documents,
            cards: cards,
            relations: relations,
            exportedAt: exportedAt
        )

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw KnowledgePathwayMarkdownExportError.cannotWriteFile
        }
    }

    private func appendSources(
        _ documents: [DocumentItem],
        to sections: inout [String]
    ) {
        guard !documents.isEmpty else {
            sections.append("- 尚未加入来源资料。")
            return
        }

        for document in documents {
            let attribution = document.attributionDescription.map { "｜\($0)" } ?? ""
            let url = document.sourceURLString.isEmpty ? "" : "｜\(document.sourceURLString)"
            sections.append("- \(singleLine(document.title))（\(document.sourceType.title) / \(document.displayFileType)｜\(document.credibility.title)\(attribution)\(url)）")
        }
    }

    private func appendContributionMatrix(
        _ documents: [DocumentItem],
        cards: [KnowledgeCard],
        to sections: inout [String]
    ) {
        guard !documents.isEmpty else {
            sections.append("| 尚未加入来源资料 | - | - | - | 0 | - |")
            return
        }

        for document in documents {
            let relatedCards = cards.filter { $0.sourceDocumentId == document.id }
            sections.append(
                "| \(tableCell(document.title)) | \(tableCell(document.sourceType.title)) | \(tableCell(document.attributionDescription ?? "-")) | \(tableCell(document.credibility.title)) | \(relatedCards.count) | \(tableCell(contribution(for: document, cards: relatedCards))) |"
            )
        }
    }

    private func appendSourceQuality(
        _ overview: SourceQualityOverview,
        sources: [DocumentItem],
        to sections: inout [String]
    ) {
        guard overview.totalSources > 0 else {
            sections.append("- 尚未加入正式来源。")
            return
        }

        sections.append("- 元数据完整：\(overview.completeMetadataSources) / \(overview.totalSources)（\(percent(overview.metadataCompletionRatio))）")
        sections.append("- 已核验来源：\(overview.totalSources - overview.unverifiedSources) / \(overview.totalSources)（\(percent(overview.verificationRatio))）")
        sections.append("- 权威来源：\(overview.authoritativeSources)")
        sections.append("- 外部补全候选：\(overview.candidateSources)")

        let sourceFolderService = PathwaySourceFolderService()
        let unverifiedSources = sourceFolderService.filter(sources, quality: .needsVerification)
        let incompleteSources = sourceFolderService.filter(sources, quality: .missingMetadata)

        if !unverifiedSources.isEmpty {
            sections.append("- 待核验来源：\(unverifiedSources.map(\.title).map(singleLine).joined(separator: "；"))")
        }

        if !incompleteSources.isEmpty {
            sections.append("- 元数据待补：\(incompleteSources.map(\.title).map(singleLine).joined(separator: "；"))")
        }
    }

    private func appendCandidates(
        _ documents: [DocumentItem],
        to sections: inout [String]
    ) {
        guard !documents.isEmpty else {
            sections.append("- 当前没有外部补全候选。")
            return
        }

        for document in documents {
            let attribution = document.attributionDescription.map { "｜\($0)" } ?? ""
            let url = document.sourceURLString.isEmpty ? "" : "｜\(document.sourceURLString)"
            let advice = PathwaySourceFolderService().candidateAdvice(for: document)
            sections.append("- [ ] \(singleLine(document.title))（待核验\(attribution)\(url)）")
            sections.append("  - 处理建议：\(singleLine(advice.title))：\(singleLine(advice.detail))")
        }
    }

    private func appendNodeGroups(
        _ cards: [KnowledgeCard],
        to sections: inout [String]
    ) {
        guard !cards.isEmpty else {
            sections.append(contentsOf: ["", "- 尚未加入知识节点。"])
            return
        }

        let groups = [
            ("核心概念", cards.filter { $0.kind == .concept }),
            ("主要观点", cards.filter { $0.kind == .argument }),
            ("关键证据", cards.filter { $0.kind == .evidence }),
            ("待补全问题", cards.filter { $0.kind == .question }),
            (
                "其他节点",
                cards.filter {
                    ![.concept, .argument, .evidence, .question].contains($0.kind)
                }
            ),
        ]

        for (title, groupedCards) in groups where !groupedCards.isEmpty {
            sections.append(contentsOf: ["", "### \(title)", ""])
            for card in groupedCards {
                sections.append("- **\(singleLine(card.title))**（\(card.kind.title)）｜\(card.sourceDescription.map(singleLine) ?? "来源待补充")")
                sections.append("  - \(singleLine(card.content))")
            }
        }
    }

    private func appendRelations(
        _ relations: [(KnowledgeRelation, KnowledgeCard, KnowledgeCard)],
        to sections: inout [String]
    ) {
        guard !relations.isEmpty else {
            sections.append("- 尚未建立节点关系。")
            return
        }

        for (relation, source, target) in relations {
            let note = relation.note.isEmpty ? "" : "｜\(singleLine(relation.note))"
            sections.append("- \(singleLine(source.title)) → **\(relation.kind.title)** → \(singleLine(target.title)) \(note)")
        }
    }

    private func appendCalibration(
        _ cards: [KnowledgeCard],
        to sections: inout [String]
    ) {
        let confirmed = cards.filter { $0.calibrationState == .confirmed }
        let highlighted = cards.filter(\.isHighlighted)
        let understood = cards.filter(\.isUnderstood)
        sections.append("- 已确认节点：\(confirmed.count) / \(cards.count)")
        sections.append("- 重点节点：\(highlighted.count)")
        sections.append("- 已理解节点：\(understood.count)")
    }

    private func appendGaps(
        _ gaps: [KnowledgePathwayGap],
        to sections: inout [String]
    ) {
        guard !gaps.isEmpty else {
            sections.append("- 当前路径的基础结构已经比较完整。")
            return
        }

        for gap in gaps {
            sections.append("- **\(singleLine(gap.title))**：\(singleLine(gap.detail))")
        }
    }

    private func appendWritingReadiness(
        _ checks: [KnowledgePathwayWritingReadinessCheck],
        to sections: inout [String]
    ) {
        for check in checks {
            sections.append("- **[\(check.status.title)] \(singleLine(check.title))**：\(singleLine(check.detail))")
        }
        sections.append("- 说明：准备度由本地结构规则生成，只用于写作前检查，不会自动生成论文。")
    }

    private func appendWritingOutline(
        _ outline: [KnowledgePathwayWritingOutlineSection],
        to sections: inout [String]
    ) {
        for outlineSection in outline {
            sections.append(contentsOf: ["### \(singleLine(outlineSection.title))", ""])
            for bullet in outlineSection.bullets {
                sections.append("- \(singleLine(bullet))")
            }
            sections.append("")
        }
        sections.append("- 说明：大纲草稿只按本地节点和关系整理写作前材料，不会自动生成正文。")
    }

    private func appendWritingActions(
        _ actions: [KnowledgePathwayWritingAction],
        to sections: inout [String]
    ) {
        guard !actions.isEmpty else {
            sections.append("- 当前没有明显的写作前阻塞项。")
            sections.append("- 说明：行动清单只整理写作前任务，不会生成正文。")
            return
        }

        for action in actions {
            let count = action.relatedCount > 0 ? "（\(action.relatedCount) 项）" : ""
            sections.append(
                "- **[\(action.priority.title)] \(singleLine(action.title))\(count)**：\(singleLine(action.detail))"
            )
            for title in action.relatedTitles {
                sections.append("  - 相关对象：\(singleLine(title))")
            }
        }
        sections.append("- 说明：行动清单只整理写作前需要补证据、核来源和校准节点的任务，不会生成正文。")
    }

    private func appendClaimEvidencePairs(
        _ relations: [(KnowledgeRelation, KnowledgeCard, KnowledgeCard)],
        to sections: inout [String]
    ) {
        let pairs = relations.compactMap { relation, source, target -> (KnowledgeCard, KnowledgeCard)? in
            guard relation.kind == .supports else {
                return nil
            }
            if source.kind == .evidence, target.kind == .argument {
                return (target, source)
            }
            if source.kind == .argument, target.kind == .evidence {
                return (source, target)
            }
            return nil
        }
        guard !pairs.isEmpty else {
            sections.append("- 尚未建立观点与证据的支持关系。")
            return
        }

        for (claim, evidence) in pairs {
            sections.append("- **观点：** \(singleLine(claim.title))")
            sections.append("  - **支持证据：** \(singleLine(evidence.title))｜\(evidence.sourceDescription.map(singleLine) ?? "来源待补充")")
        }
    }

    private func appendLearningPath(
        _ actions: [KnowledgePathwayAction],
        to sections: inout [String]
    ) {
        for action in actions {
            sections.append("- [ ] \(singleLine(action.title))，\(singleLine(action.detail))")
        }
    }

    private func appendOpenQuestions(
        _ cards: [KnowledgeCard],
        to sections: inout [String]
    ) {
        let questions = cards.filter { $0.kind == .question }
        guard !questions.isEmpty else {
            sections.append("- 当前没有问题节点。建议补充尚未澄清的概念、证据缺口或应用边界。")
            return
        }

        for question in questions {
            sections.append("- [ ] \(singleLine(question.title))")
            sections.append("  - \(singleLine(question.content))")
        }
    }

    private func contribution(
        for document: DocumentItem,
        cards: [KnowledgeCard]
    ) -> String {
        let contributionNote = document.contributionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !contributionNote.isEmpty {
            return contributionNote
        }
        let cardTitles = cards.prefix(3).map(\.title).map(singleLine)
        if !cardTitles.isEmpty {
            return cardTitles.joined(separator: "；")
        }
        if let summary = document.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            return summary
        }
        return "尚待整理"
    }

    private func singleLine(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tableCell(_ value: String) -> String {
        singleLine(value).replacingOccurrences(of: "|", with: "\\|")
    }

    private func timestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
