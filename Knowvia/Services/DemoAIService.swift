import Foundation

struct DemoAIService {
    private let selectionCardService = SelectionKnowledgeCardService()
    private let annotationCardService = AnnotationKnowledgeCardService()

    func documentSummary(title: String, text: String) -> String {
        let excerpt = excerpt(from: text)

        return """
        [本地 Demo 示例]
        以下内容由本机示例生成器生成，用于体验知径 Knowvia 的阅读闭环，不代表真实 AI 分析结果。

        1. 核心主题
        当前材料《\(title)》围绕所导入文本展开。建议先确认材料的研究对象、核心问题与结论范围。

        2. 关键概念
        - 从原文摘录中识别反复出现的术语；
        - 将术语整理为概念卡，并补充定义与上下文。

        3. 主要观点
        - 当前 Demo 建议把材料拆分为“概念、观点、证据”三类卡片；
        - 阅读时应保留来源信息，方便后续核验。

        4. 重要证据
        原文片段：\(excerpt)

        5. 可转化为知识卡片的内容
        - 概念卡：提取一个核心术语并解释；
        - 观点卡：记录作者提出的主要判断；
        - 证据卡：保存支持观点的原文片段。

        6. 建议的下一步
        选择一段关键文本，使用“AI 解释选区”，再将结果保存为概念卡。
        """
    }

    func conceptExplanation(_ text: String) -> String {
        let excerpt = excerpt(from: text)

        return """
        [本地 Demo 示例]
        以下内容由本机示例生成器生成，用于体验概念卡流程，不代表真实 AI 分析结果。

        1. 概念定义
        当前选区包含一个需要进一步确认的核心概念。建议结合上下文补充准确术语和定义。

        2. 在当前材料中的含义
        选区原文：\(excerpt)

        3. 与其他概念的关系
        可以继续向前后文查找：该概念的前提、作用机制、相关观点和支持证据。

        4. 可以如何整理为知识卡片
        - 标题：使用原文中的核心术语；
        - 正文：保留简洁定义和当前选区；
        - 标签：补充主题词；
        - 来源：保存当前文档和页码。

        5. 需要继续核验或追问的地方
        请回到原文确认概念边界，并在真实 AI 模式下获得更具体的解释。
        """
    }

    func knowledgeCardDrafts(documentTitle: String, text: String) -> [KnowledgeCardDraft] {
        let sourceExcerpt = excerpt(from: text)
        let commonTags = ["AI 草稿", "待核验"]

        return [
            KnowledgeCardDraft(
                title: "\(documentTitle)：核心概念",
                content: """
                建议从材料中确认一个反复出现的核心术语，并补充它在当前上下文中的准确含义。

                原文线索：\(sourceExcerpt)
                """,
                kind: .concept,
                tags: commonTags + ["概念"]
            ),
            KnowledgeCardDraft(
                title: "\(documentTitle)：主要观点",
                content: """
                建议将作者希望读者理解或接受的关键判断整理为一句可核验的观点。

                原文线索：\(sourceExcerpt)
                """,
                kind: .argument,
                tags: commonTags + ["观点"]
            ),
            KnowledgeCardDraft(
                title: "\(documentTitle)：证据摘录",
                content: """
                请回到原文确认上下文后，将以下片段整理为支持观点的证据。

                原文摘录：\(sourceExcerpt)
                """,
                kind: .evidence,
                tags: commonTags + ["证据"]
            ),
        ]
    }

    func selectionKnowledgeCardDraft(
        documentTitle: String,
        selectedText: String
    ) -> KnowledgeCardDraft {
        selectionCardService.draft(
            documentTitle: documentTitle,
            selectedText: selectedText
        )
    }

    func annotationKnowledgeCardDraft(
        documentTitle: String,
        selectedText: String,
        note: String
    ) -> KnowledgeCardDraft {
        annotationCardService.draft(
            documentTitle: documentTitle,
            selectedText: selectedText,
            note: note
        )
    }

    private func excerpt(from text: String) -> String {
        let collapsedText = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let includedText = String(collapsedText.prefix(180))
        return includedText + (collapsedText.count > includedText.count ? "……" : "")
    }
}
