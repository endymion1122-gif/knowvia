import Foundation

enum KnowledgeCardSourceError: LocalizedError {
    case missingSourceReference
    case sourceDocumentNotFound

    var errorDescription: String? {
        switch self {
        case .missingSourceReference:
            "这张卡片没有关联资料，暂时无法打开原文。"
        case .sourceDocumentNotFound:
            "关联资料已不在资料库中，但卡片内容仍然保留。"
        }
    }
}

struct KnowledgeCardSourceService {
    func sourceDocument(
        for card: KnowledgeCard,
        in documents: [DocumentItem]
    ) throws -> DocumentItem {
        try sourceDocument(sourceDocumentId: card.sourceDocumentId, in: documents)
    }

    func sourceDocument(
        for reference: LearningPathCardReference,
        in documents: [DocumentItem]
    ) throws -> DocumentItem {
        try sourceDocument(sourceDocumentId: reference.sourceDocumentId, in: documents)
    }

    func targetPageNumber(for card: KnowledgeCard, in document: DocumentItem) -> Int? {
        targetPageNumber(pageNumber: card.pageNumber, in: document)
    }

    func targetPageNumber(
        for reference: LearningPathCardReference,
        in document: DocumentItem
    ) -> Int? {
        targetPageNumber(pageNumber: reference.pageNumber, in: document)
    }

    private func sourceDocument(
        sourceDocumentId: UUID?,
        in documents: [DocumentItem]
    ) throws -> DocumentItem {
        guard let sourceDocumentId else {
            throw KnowledgeCardSourceError.missingSourceReference
        }
        guard let document = documents.first(where: { $0.id == sourceDocumentId }) else {
            throw KnowledgeCardSourceError.sourceDocumentNotFound
        }
        return document
    }

    private func targetPageNumber(pageNumber: Int?, in document: DocumentItem) -> Int? {
        guard document.isPDF, let pageNumber, pageNumber > 0 else {
            return nil
        }
        return pageNumber
    }
}
