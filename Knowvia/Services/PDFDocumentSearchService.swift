import Foundation
import PDFKit

struct PDFDocumentSearchService {
    func selections(for query: String, in document: PDFDocument) -> [PDFSelection] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        return document.findString(
            normalizedQuery,
            withOptions: [.caseInsensitive, .diacriticInsensitive]
        )
    }
}
