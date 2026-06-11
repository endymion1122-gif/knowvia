import Foundation

enum LearningPathExportError: LocalizedError, Equatable {
    case noCards
    case cannotWriteFile

    var errorDescription: String? {
        switch self {
        case .noCards:
            "当前主题下没有可生成任务的知识卡片。"
        case .cannotWriteFile:
            "无法写入任务清单，请检查保存位置后重试。"
        }
    }
}

struct LearningPathCardReference: Identifiable, Equatable {
    let id: UUID
    let title: String
    let kind: KnowledgeCardKind
    let sourceDocumentId: UUID?
    let pageNumber: Int?
    let sourceDescription: String?
}

struct LearningPathStep: Identifiable, Equatable {
    enum Stage: String, CaseIterable {
        case concepts
        case arguments
        case evidence
        case review
        case action

        var title: String {
            switch self {
            case .concepts: "理解概念"
            case .arguments: "阅读观点"
            case .evidence: "核验证据"
            case .review: "复习卡片"
            case .action: "导出行动"
            }
        }

        var detail: String {
            switch self {
            case .concepts: "建立基础认知"
            case .arguments: "梳理观点链条"
            case .evidence: "回到来源核验"
            case .review: "巩固主题卡片"
            case .action: "转为任务清单"
            }
        }

        var symbolName: String {
            switch self {
            case .concepts: "sparkle"
            case .arguments: "point.3.connected.trianglepath.dotted"
            case .evidence: "link"
            case .review: "arrow.clockwise"
            case .action: "checkmark.circle"
            }
        }
    }

    let stage: Stage
    let cards: [LearningPathCardReference]

    var id: String { stage.rawValue }
}

struct DayCabinTaskDraft: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

struct LearningPathSnapshot: Equatable {
    let topic: String?
    let cards: [LearningPathCardReference]
    let steps: [LearningPathStep]
    let tasks: [DayCabinTaskDraft]

    var displayTopic: String {
        topic ?? "全部卡片"
    }
}

struct LearningPathService {
    static let reservedTags: Set<String> = ["AI 草稿", "待核验", "概念", "观点", "证据"]

    func availableTopics(in cards: [KnowledgeCard]) -> [String] {
        Array(
            Set(
                cards
                    .flatMap(\.tags)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !Self.reservedTags.contains($0) }
            )
        )
        .sorted()
    }

    func snapshot(for cards: [KnowledgeCard], topic: String?) -> LearningPathSnapshot {
        let selectedCards = cards
            .filter { topic == nil || $0.tags.contains(topic ?? "") }
            .map(reference)
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }

        let concepts = selectedCards.filter { $0.kind == .concept }
        let arguments = selectedCards.filter { [.argument, .summary].contains($0.kind) }
        let evidence = selectedCards.filter { [.evidence, .quote].contains($0.kind) }

        let steps = [
            LearningPathStep(stage: .concepts, cards: concepts),
            LearningPathStep(stage: .arguments, cards: arguments),
            LearningPathStep(stage: .evidence, cards: evidence),
            LearningPathStep(stage: .review, cards: selectedCards),
            LearningPathStep(stage: .action, cards: selectedCards),
        ]

        return LearningPathSnapshot(
            topic: topic,
            cards: selectedCards,
            steps: steps,
            tasks: tasks(topic: topic, concepts: concepts, arguments: arguments, evidence: evidence, allCards: selectedCards)
        )
    }

    func taskMarkdown(
        for snapshot: LearningPathSnapshot,
        exportedAt: Date = Date()
    ) throws -> String {
        guard !snapshot.cards.isEmpty else {
            throw LearningPathExportError.noCards
        }

        var sections = [
            "# 一日舱 DayCabin 学习任务草稿",
            "",
            "> 从知径 Knowvia 导出的本地概念清单。请在一日舱中核验并安排时间。",
            "",
            "- 主题：\(snapshot.displayTopic)",
            "- 导出时间：\(timestamp(for: exportedAt))",
            "- 关联卡片：\(snapshot.cards.count) 张",
            "",
            "## 待办任务",
        ]

        for task in snapshot.tasks {
            sections.append("- [ ] \(task.title)")
            sections.append("  - \(task.detail)")
        }

        sections.append(contentsOf: [
            "",
            "## 关联知识卡片",
        ])

        for card in snapshot.cards {
            let source = card.sourceDescription ?? "来源待补充"
            sections.append("- \(card.title)（\(card.kind.title)）｜\(source)")
        }

        return sections.joined(separator: "\n") + "\n"
    }

    func exportTasks(
        for snapshot: LearningPathSnapshot,
        to url: URL,
        exportedAt: Date = Date()
    ) throws {
        let content = try taskMarkdown(for: snapshot, exportedAt: exportedAt)

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw LearningPathExportError.cannotWriteFile
        }
    }

    private func reference(_ card: KnowledgeCard) -> LearningPathCardReference {
        LearningPathCardReference(
            id: card.id,
            title: card.title,
            kind: card.kind,
            sourceDocumentId: card.sourceDocumentId,
            pageNumber: card.pageNumber,
            sourceDescription: card.sourceDescription
        )
    }

    private func tasks(
        topic: String?,
        concepts: [LearningPathCardReference],
        arguments: [LearningPathCardReference],
        evidence: [LearningPathCardReference],
        allCards: [LearningPathCardReference]
    ) -> [DayCabinTaskDraft] {
        let displayTopic = topic ?? "全部卡片"

        return [
            DayCabinTaskDraft(
                id: "concepts",
                title: "复习 \(displayTopic) 的概念卡",
                detail: "\(concepts.count) 张概念卡。补充定义，并确认术语边界。"
            ),
            DayCabinTaskDraft(
                id: "arguments",
                title: "梳理 \(displayTopic) 的观点卡",
                detail: "\(arguments.count) 张观点或摘要卡。整理观点之间的关系。"
            ),
            DayCabinTaskDraft(
                id: "evidence",
                title: "核验 \(displayTopic) 的证据来源",
                detail: "\(evidence.count) 张证据或摘录卡。回到原文确认上下文。"
            ),
            DayCabinTaskDraft(
                id: "review",
                title: "安排一次主题复习",
                detail: "复习当前路径中的 \(allCards.count) 张知识卡片，并记录仍需追问的问题。"
            ),
        ]
    }

    private func timestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
