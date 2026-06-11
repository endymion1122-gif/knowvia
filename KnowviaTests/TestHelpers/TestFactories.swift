import Foundation
@testable import Knowvia

/// Shared factory methods for creating test model instances.
/// Replaces duplicated `makeCard()`, `makeDocument()`, etc. across test files.

enum TestFactories {

    // MARK: - KnowledgeCard

    static func makeKnowledgeCard(
        title: String = "测试卡片",
        content: String = "测试内容",
        cardType: KnowledgeCardKind = .concept,
        tags: [String] = [],
        sourceDocumentId: UUID? = nil,
        sourceDocumentTitle: String? = nil,
        pageNumber: Int? = nil,
        pathwayIDs: [UUID] = [],
        calibrationStatus: KnowledgeCardCalibrationStatus = .pendingReview,
        isHighlighted: Bool = false,
        isUnderstood: Bool = false,
        calibrationNote: String = "",
        createdBy: String = "test"
    ) -> KnowledgeCard {
        KnowledgeCard(
            title: title,
            content: content,
            cardType: cardType.rawValue,
            tags: tags,
            sourceDocumentId: sourceDocumentId,
            sourceDocumentTitle: sourceDocumentTitle,
            pageNumber: pageNumber,
            pathwayIDs: pathwayIDs,
            calibrationStatus: calibrationStatus.rawValue,
            isHighlighted: isHighlighted,
            isUnderstood: isUnderstood,
            calibrationNote: calibrationNote,
            createdBy: createdBy
        )
    }

    // MARK: - DocumentItem

    static func makeDocumentItem(
        title: String = "测试资料",
        filePath: String = "/tmp/knowvia-test-doc.md",
        fileType: String = "md",
        tags: [String] = [],
        readingStatus: String = "unread",
        lastOpenedAt: Date? = nil,
        lastReadPageNumber: Int? = nil,
        sourceKind: DocumentSourceKind = .uploadedFile,
        author: String = "",
        publicationYear: Int? = nil,
        sourceURLString: String = "",
        sourceNote: String = "",
        credibilityLevel: SourceCredibilityLevel = .unreviewed,
        contributionNote: String = ""
    ) -> DocumentItem {
        DocumentItem(
            title: title,
            filePath: filePath,
            fileType: fileType,
            tags: tags,
            readingStatus: readingStatus,
            lastOpenedAt: lastOpenedAt,
            lastReadPageNumber: lastReadPageNumber,
            sourceKind: sourceKind.rawValue,
            author: author,
            publicationYear: publicationYear,
            sourceURLString: sourceURLString,
            sourceNote: sourceNote,
            credibilityLevel: credibilityLevel.rawValue,
            contributionNote: contributionNote
        )
    }

    // MARK: - DocumentAnnotation

    static func makeDocumentAnnotation(
        documentId: UUID = UUID(),
        documentTitle: String = "测试资料",
        selectedText: String = "选中文本",
        note: String = "测试备注",
        pageNumber: Int? = nil
    ) -> DocumentAnnotation {
        DocumentAnnotation(
            documentId: documentId,
            documentTitle: documentTitle,
            selectedText: selectedText,
            note: note,
            pageNumber: pageNumber
        )
    }

    // MARK: - KnowledgePathway

    static func makeKnowledgePathway(
        title: String = "测试路径",
        overview: String = "",
        tags: [String] = [],
        sourceDocumentIDs: [UUID] = [],
        candidateDocumentIDs: [UUID] = [],
        knowledgeCardIDs: [UUID] = []
    ) -> KnowledgePathway {
        KnowledgePathway(
            title: title,
            overview: overview,
            tags: tags,
            sourceDocumentIDs: sourceDocumentIDs,
            candidateDocumentIDs: candidateDocumentIDs,
            knowledgeCardIDs: knowledgeCardIDs
        )
    }

    // MARK: - KnowledgeRelation

    static func makeKnowledgeRelation(
        pathwayID: UUID = UUID(),
        sourceCardID: UUID = UUID(),
        targetCardID: UUID = UUID(),
        relationType: KnowledgeRelationKind = .relatedTo,
        note: String = ""
    ) -> KnowledgeRelation {
        KnowledgeRelation(
            pathwayID: pathwayID,
            sourceCardID: sourceCardID,
            targetCardID: targetCardID,
            relationType: relationType.rawValue,
            note: note
        )
    }
}
