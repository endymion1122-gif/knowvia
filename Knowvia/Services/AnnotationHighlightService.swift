import Foundation
import PDFKit

struct AnnotationHighlightService {
    private let textSearchService = TextDocumentSearchService()

    func textRanges(
        for annotations: [DocumentAnnotation],
        in text: String
    ) -> [NSRange] {
        annotations.compactMap { annotation in
            textSearchService.matches(for: annotation.selectedText, in: text).first
        }
    }

    func pdfSelections(
        for annotations: [DocumentAnnotation],
        in document: PDFDocument
    ) -> [PDFSelection] {
        annotations.compactMap { annotation in
            let selections = document.findString(
                annotation.selectedText,
                withOptions: [.caseInsensitive, .diacriticInsensitive]
            )

            guard let pageNumber = annotation.pageNumber else {
                return selections.first
            }

            return selections.first { selection in
                selection.pages.contains { page in
                    document.index(for: page) + 1 == pageNumber
                }
            }
        }
    }
}
