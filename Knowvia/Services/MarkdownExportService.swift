import Foundation

enum MarkdownExportError: LocalizedError, Equatable {
    case noCards
    case cannotWriteFile

    var errorDescription: String? {
        switch self {
        case .noCards:
            "当前没有可导出的知识卡片。"
        case .cannotWriteFile:
            "无法写入 Markdown 文件，请检查保存位置后重试。"
        }
    }
}

struct MarkdownExportService {
    func markdown(
        for cards: [KnowledgeCard],
        exportedAt: Date = Date()
    ) throws -> String {
        guard !cards.isEmpty else {
            throw MarkdownExportError.noCards
        }

        let sortedCards = cards.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
            return $0.createdAt > $1.createdAt
        }

        var sections = [
            "# 知径 Knowvia 知识卡片",
            "",
            "> 导出自知径 Knowvia · 让知识成为路径。",
            "",
            "- 导出时间：\(timestamp(for: exportedAt))",
            "- 卡片数量：\(sortedCards.count)",
        ]

        for card in sortedCards {
            sections.append(contentsOf: [
                "",
                "---",
                "",
                "## \(singleLine(card.title))",
                "",
                "- 类型：\(card.kind.title)",
                "- 来源：\(card.sourceDescription.map(singleLine) ?? "未填写")",
                "- 标签：\(card.tags.isEmpty ? "未填写" : card.tags.map(singleLine).joined(separator: "，"))",
                "- 创建时间：\(dateString(for: card.createdAt))",
                "",
                card.content.trimmingCharacters(in: .whitespacesAndNewlines),
            ])
        }

        return sections.joined(separator: "\n") + "\n"
    }

    func export(
        cards: [KnowledgeCard],
        to url: URL,
        exportedAt: Date = Date()
    ) throws {
        let content = try markdown(for: cards, exportedAt: exportedAt)

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw MarkdownExportError.cannotWriteFile
        }
    }

    private func singleLine(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func timestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func dateString(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
