import Foundation

struct AnnotationKnowledgeCardService {
    private let selectionCardService = SelectionKnowledgeCardService()

    func draft(
        documentTitle: String,
        selectedText: String,
        note: String,
        generatedSummary: String? = nil
    ) -> KnowledgeCardDraft {
        let normalizedText = normalize(selectedText)
        let normalizedNote = normalize(note)
        let kind = selectionCardService.inferredKind(for: normalizedText)
        let title = inferredTitle(note: normalizedNote, text: normalizedText, kind: kind)
        let summary = generatedSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let content = cardContent(
            selectedText: normalizedText,
            note: normalizedNote,
            kind: kind,
            generatedSummary: summary
        )

        return KnowledgeCardDraft(
            title: title,
            content: content,
            kind: kind,
            tags: ["AI 草稿", "批注转卡片", "待核验", kind.title, documentTitle]
        )
    }

    private func inferredTitle(
        note: String,
        text: String,
        kind: KnowledgeCardKind
    ) -> String {
        let titleSource = note.isEmpty ? text : note
        let includedText = String(titleSource.prefix(34))
        let suffix = titleSource.count > includedText.count ? "……" : ""
        return "\(kind.title)：\(includedText)\(suffix)"
    }

    private func cardContent(
        selectedText: String,
        note: String,
        kind: KnowledgeCardKind,
        generatedSummary: String?
    ) -> String {
        let summary = generatedSummary.flatMap { $0.isEmpty ? nil : $0 }
            ?? localSummary(note: note, kind: kind)

        return """
        AI 归纳
        \(summary)

        用户批注
        \(note)

        原文选区
        \(selectedText)

        核验提示
        请结合原文上下文确认卡片表述，并按需要继续修改。
        """
    }

    private func localSummary(note: String, kind: KnowledgeCardKind) -> String {
        switch kind {
        case .concept:
            "这条批注围绕一个核心概念展开。可以从“\(note)”继续补充定义、语境与相关概念。"
        case .question:
            "这条批注保留了一个值得继续追问的问题。可以从“\(note)”回到原文寻找回答与证据。"
        default:
            "这条批注记录了一个可复用的阅读判断。可以从“\(note)”继续确认适用范围，并连接支持证据。"
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
