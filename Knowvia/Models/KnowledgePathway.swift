import Foundation
import SwiftData

@Model
final class KnowledgePathway {
    @Attribute(.unique) var id: UUID
    var title: String
    var overview: String
    var tags: [String]
    var sourceDocumentIDs: [UUID]
    var candidateDocumentIDs: [UUID] = []
    var knowledgeCardIDs: [UUID] = []
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        overview: String = "",
        tags: [String] = [],
        sourceDocumentIDs: [UUID] = [],
        candidateDocumentIDs: [UUID] = [],
        knowledgeCardIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.tags = tags
        self.sourceDocumentIDs = sourceDocumentIDs
        self.candidateDocumentIDs = candidateDocumentIDs
        self.knowledgeCardIDs = knowledgeCardIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
