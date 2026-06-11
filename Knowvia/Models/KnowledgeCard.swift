import Foundation
import SwiftData

enum KnowledgeCardKind: String, CaseIterable, Identifiable {
    case concept
    case quote
    case summary
    case method
    case argument
    case evidence
    case question
    case reflection
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concept: "概念"
        case .quote: "摘录"
        case .summary: "摘要"
        case .method: "方法"
        case .argument: "观点"
        case .evidence: "证据"
        case .question: "问题"
        case .reflection: "反思"
        case .note: "笔记"
        }
    }
}

enum KnowledgeCardCalibrationStatus: String, CaseIterable, Identifiable {
    case pendingReview
    case confirmed
    case needsFollowUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pendingReview: "待核验"
        case .confirmed: "已确认"
        case .needsFollowUp: "需跟进"
        }
    }
}

struct KnowledgeCardDraft: Identifiable, Equatable {
    let id: UUID
    let title: String
    let content: String
    let kind: KnowledgeCardKind
    let tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        kind: KnowledgeCardKind,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.kind = kind
        self.tags = tags
    }
}

@Model
final class KnowledgeCard {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var summary: String?
    var cardType: String
    var tags: [String]
    var sourceDocumentId: UUID?
    var sourceDocumentTitle: String?
    var pageNumber: Int?
    var pathwayIDs: [UUID] = []
    var calibrationStatus: String = KnowledgeCardCalibrationStatus.pendingReview.rawValue
    var isHighlighted: Bool = false
    var isUnderstood: Bool = false
    var calibrationNote: String = ""
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        summary: String? = nil,
        cardType: String = KnowledgeCardKind.note.rawValue,
        tags: [String] = [],
        sourceDocumentId: UUID? = nil,
        sourceDocumentTitle: String? = nil,
        pageNumber: Int? = nil,
        pathwayIDs: [UUID] = [],
        calibrationStatus: String = KnowledgeCardCalibrationStatus.pendingReview.rawValue,
        isHighlighted: Bool = false,
        isUnderstood: Bool = false,
        calibrationNote: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String = "user"
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.summary = summary
        self.cardType = cardType
        self.tags = tags
        self.sourceDocumentId = sourceDocumentId
        self.sourceDocumentTitle = sourceDocumentTitle
        self.pageNumber = pageNumber
        self.pathwayIDs = pathwayIDs
        self.calibrationStatus = calibrationStatus
        self.isHighlighted = isHighlighted
        self.isUnderstood = isUnderstood
        self.calibrationNote = calibrationNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
    }

    var kind: KnowledgeCardKind {
        KnowledgeCardKind(rawValue: cardType) ?? .note
    }

    var sourceDescription: String? {
        guard let sourceDocumentTitle, !sourceDocumentTitle.isEmpty else {
            return nil
        }

        if let pageNumber {
            return "\(sourceDocumentTitle)，p.\(pageNumber)"
        }
        return sourceDocumentTitle
    }

    var calibrationState: KnowledgeCardCalibrationStatus {
        KnowledgeCardCalibrationStatus(rawValue: calibrationStatus) ?? .pendingReview
    }
}
