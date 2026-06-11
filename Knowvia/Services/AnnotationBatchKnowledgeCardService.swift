import Foundation

enum AnnotationBatchKnowledgeCardError: LocalizedError, Equatable {
    case notEnoughAnnotations

    var errorDescription: String? {
        "请至少选择两条批注，再进行批量整理。"
    }
}

struct AnnotationBatchKnowledgeCardBundle: Identifiable, Equatable {
    let id: UUID
    let topic: String
    let annotationCount: Int
    let drafts: [KnowledgeCardDraft]

    init(
        id: UUID = UUID(),
        topic: String,
        annotationCount: Int,
        drafts: [KnowledgeCardDraft]
    ) {
        self.id = id
        self.topic = topic
        self.annotationCount = annotationCount
        self.drafts = drafts
    }
}

struct AnnotationBatchKnowledgeCardService {
    func bundle(
        documentTitle: String,
        annotations: [DocumentAnnotation]
    ) throws -> AnnotationBatchKnowledgeCardBundle {
        guard annotations.count >= 2 else {
            throw AnnotationBatchKnowledgeCardError.notEnoughAnnotations
        }

        let topic = inferredTopic(from: annotations)
        let commonTags = ["AI 草稿", "批注批量整理", "待核验", topic]
        let annotationContext = context(from: annotations)

        return AnnotationBatchKnowledgeCardBundle(
            topic: topic,
            annotationCount: annotations.count,
            drafts: [
                KnowledgeCardDraft(
                    title: "\(topic)：核心概念",
                    content: """
                    批量整理建议
                    围绕“\(topic)”确认核心术语、定义边界，以及它与其他概念的关系。

                    关联批注
                    \(annotationContext)

                    核验提示
                    请结合原文继续补充准确概念，并删除与主题无关的线索。
                    """,
                    kind: .concept,
                    tags: commonTags + ["概念", documentTitle]
                ),
                KnowledgeCardDraft(
                    title: "\(topic)：主要观点",
                    content: """
                    批量整理建议
                    围绕“\(topic)”归纳一条可以复用的阅读判断，并确认它的适用范围。

                    关联批注
                    \(annotationContext)

                    核验提示
                    请区分原文观点与个人延伸，不要把批注意见直接当作作者结论。
                    """,
                    kind: .argument,
                    tags: commonTags + ["观点", documentTitle]
                ),
                KnowledgeCardDraft(
                    title: "\(topic)：证据线索",
                    content: """
                    批量整理建议
                    保留与“\(topic)”有关的原文选区，作为后续核验观点的证据线索。

                    关联批注
                    \(annotationContext)

                    核验提示
                    请回到原文确认上下文、页码与证据强度，再决定是否保留。
                    """,
                    kind: .evidence,
                    tags: commonTags + ["证据", documentTitle]
                ),
            ]
        )
    }

    private func inferredTopic(from annotations: [DocumentAnnotation]) -> String {
        let selectedTextCandidates = annotations
            .map(\.selectedText)
            .map(normalize)
            .filter { !$0.isEmpty && $0.count <= 18 }
        let noteCandidates = annotations
            .flatMap { topicCandidates(from: $0.note) }
        let candidates = selectedTextCandidates + noteCandidates
        let counts = Dictionary(grouping: candidates, by: { $0 })
            .mapValues(\.count)

        if let repeatedCandidate = counts
            .filter({ $0.value > 1 })
            .sorted(by: {
                if $0.value == $1.value {
                    return $0.key.count < $1.key.count
                }
                return $0.value > $1.value
            })
            .first?
            .key {
            return repeatedCandidate
        }

        if let firstSelection = selectedTextCandidates.first {
            return firstSelection
        }

        if let firstNote = noteCandidates.first {
            return firstNote
        }

        return "阅读批注整理"
    }

    private func topicCandidates(from note: String) -> [String] {
        note
            .components(separatedBy: CharacterSet(charactersIn: "，。！？；：,.!?;:\n\t "))
            .map(normalize)
            .filter { $0.count >= 2 && $0.count <= 12 }
    }

    private func context(from annotations: [DocumentAnnotation]) -> String {
        annotations.enumerated().map { index, annotation in
            """
            \(index + 1). [\(annotation.sourceDescription)] \(normalize(annotation.note))
               原文：\(excerpt(from: annotation.selectedText))
            """
        }
        .joined(separator: "\n")
    }

    private func excerpt(from text: String) -> String {
        let normalizedText = normalize(text)
        let includedText = String(normalizedText.prefix(160))
        return includedText + (normalizedText.count > includedText.count ? "……" : "")
    }

    private func normalize(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
