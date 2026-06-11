import Foundation
import SwiftData

enum KnowledgeRelationKind: String, CaseIterable, Identifiable {
    case defines
    case supports
    case challenges
    case extends
    case relatedTo = "related_to"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defines: "定义"
        case .supports: "支持"
        case .challenges: "挑战"
        case .extends: "扩展"
        case .relatedTo: "相关"
        }
    }
}

@Model
final class KnowledgeRelation {
    @Attribute(.unique) var id: UUID
    var pathwayID: UUID
    var sourceCardID: UUID
    var targetCardID: UUID
    var relationType: String
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        pathwayID: UUID,
        sourceCardID: UUID,
        targetCardID: UUID,
        relationType: String,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.pathwayID = pathwayID
        self.sourceCardID = sourceCardID
        self.targetCardID = targetCardID
        self.relationType = relationType
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: KnowledgeRelationKind {
        KnowledgeRelationKind(rawValue: relationType) ?? .relatedTo
    }
}
