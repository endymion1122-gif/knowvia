import Foundation

struct SelectionKnowledgeCardService {
    func draft(
        documentTitle: String,
        selectedText: String,
        generatedSummary: String? = nil
    ) -> KnowledgeCardDraft {
        let normalizedText = normalize(selectedText)
        let kind = inferredKind(for: normalizedText)
        let title = inferredTitle(for: normalizedText, kind: kind)
        let summary = generatedSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return KnowledgeCardDraft(
            title: title,
            content: cardContent(
                for: normalizedText,
                kind: kind,
                generatedSummary: summary
            ),
            kind: kind,
            tags: ["AI 草稿", "待核验", kind.title, documentTitle]
        )
    }

    func inferredKind(for selectedText: String) -> KnowledgeCardKind {
        let normalizedText = normalize(selectedText)
        if normalizedText.contains("?") || normalizedText.contains("？") {
            return .question
        }
        if normalizedText.count <= 24, !containsSentenceEnding(normalizedText) {
            return .concept
        }
        return .argument
    }

    private func inferredTitle(
        for selectedText: String,
        kind: KnowledgeCardKind
    ) -> String {
        let maximumTitleCharacters = kind == .concept ? 28 : 34
        let includedText = String(selectedText.prefix(maximumTitleCharacters))
        let suffix = selectedText.count > includedText.count ? "……" : ""
        return "\(kind.title)：\(includedText)\(suffix)"
    }

    private func cardContent(
        for selectedText: String,
        kind: KnowledgeCardKind,
        generatedSummary: String?
    ) -> String {
        let summary = generatedSummary.flatMap { $0.isEmpty ? nil : $0 }
            ?? localSummary(for: selectedText, kind: kind)

        return """
        AI 归纳
        \(summary)

        原文选区
        \(selectedText)

        核验提示
        请结合原文上下文确认卡片表述，并按需要继续修改。
        """
    }

    private func localSummary(for selectedText: String, kind: KnowledgeCardKind) -> String {
        switch kind {
        case .concept:
            "这是一个值得继续追踪的核心术语。建议补充它在当前材料中的定义、使用语境，以及它与其他概念的关系。"
        case .question:
            "这是一个可以继续追问的问题。建议回到前后文寻找作者给出的回答、证据和仍未解决的部分。"
        default:
            "这段选区包含一个可复用的观点或论述片段。建议确认它的适用范围，并继续连接支持证据与相关概念。"
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsSentenceEnding(_ text: String) -> Bool {
        text.rangeOfCharacter(from: CharacterSet(charactersIn: "。！？.!?；;")) != nil
    }
}
