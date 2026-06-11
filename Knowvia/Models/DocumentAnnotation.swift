import Foundation
import SwiftData

@Model
final class DocumentAnnotation {
    @Attribute(.unique) var id: UUID
    var documentId: UUID
    var documentTitle: String
    var selectedText: String
    var note: String
    var pageNumber: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        documentId: UUID,
        documentTitle: String,
        selectedText: String,
        note: String,
        pageNumber: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.selectedText = selectedText
        self.note = note
        self.pageNumber = pageNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sourceDescription: String {
        guard let pageNumber else {
            return documentTitle
        }
        return "\(documentTitle)，p.\(pageNumber)"
    }
}
