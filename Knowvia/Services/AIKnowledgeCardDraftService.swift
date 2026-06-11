import Foundation

struct AIKnowledgeCardDraftService {
    func drafts(
        documentTitle: String,
        text: String,
        generatedSummary: String
    ) -> [KnowledgeCardDraft] {
        let normalizedSummary = normalizedResponse(generatedSummary)
        let sourceExcerpt = excerpt(from: text, limit: 220)
        let commonTags = ["AI 草稿", "待核验", "真实 AI"]

        return [
            KnowledgeCardDraft(
                title: "\(documentTitle)：核心概念",
                content: """
                AI 归纳：请从以下摘要中挑选一个核心术语，并回到原文确认它的定义、边界和上下文。

                \(normalizedSummary)

                原文线索：\(sourceExcerpt)

                核验提示：保存前请确认术语确实来自原文，避免把模型推断当成原文结论。
                """,
                kind: .concept,
                tags: commonTags + ["概念"]
            ),
            KnowledgeCardDraft(
                title: "\(documentTitle)：主要观点",
                content: """
                AI 归纳：请将以下摘要中最关键的判断整理为一句可核验的观点。

                \(normalizedSummary)

                原文线索：\(sourceExcerpt)

                核验提示：保存前请确认观点的主语、适用范围和证据是否都能在原文中找到。
                """,
                kind: .argument,
                tags: commonTags + ["观点"]
            ),
            KnowledgeCardDraft(
                title: "\(documentTitle)：证据摘录",
                content: """
                AI 归纳：请根据以下摘要定位能够支撑观点的原文证据。

                \(normalizedSummary)

                原文线索：\(sourceExcerpt)

                核验提示：保存前请替换为更准确的原文摘录，并保留来源位置。
                """,
                kind: .evidence,
                tags: commonTags + ["证据"]
            ),
        ]
    }

    func normalizedResponse(_ response: String) -> String {
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResponse.isEmpty else {
            return "模型未返回可整理的摘要，请回到原文手动补充。"
        }

        var lines = trimmedResponse.components(separatedBy: .newlines)
        if lines.first?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeFirst()
        }
        if lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeLast()
        }

        let unfencedResponse = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return unfencedResponse.isEmpty
            ? "模型未返回可整理的摘要，请回到原文手动补充。"
            : unfencedResponse
    }

    private func excerpt(from text: String, limit: Int) -> String {
        let collapsedText = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let includedText = String(collapsedText.prefix(limit))
        return includedText + (collapsedText.count > includedText.count ? "……" : "")
    }
}
