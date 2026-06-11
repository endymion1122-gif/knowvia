import Foundation
import PDFKit

struct PDFTextExtractionService {
    func extractText(from url: URL) -> String {
        guard let document = PDFDocument(url: url) else {
            return ""
        }

        return (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func extractText(from url: URL, pageIndex: Int) -> String {
        guard
            let document = PDFDocument(url: url),
            pageIndex >= 0,
            pageIndex < document.pageCount
        else {
            return ""
        }

        return document.page(at: pageIndex)?
            .string?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
