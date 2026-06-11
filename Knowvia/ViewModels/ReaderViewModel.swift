import Foundation
import PDFKit

@MainActor
final class ReaderViewModel: ObservableObject {
    let documentItem: DocumentItem
    let pdfDocument: PDFDocument?

    @Published var currentPageIndex = 0
    @Published var zoomScale: CGFloat = 1
    @Published var extractedPageText = ""
    @Published var extractionMessage: String?

    private let extractionService: PDFTextExtractionService

    init(
        document: DocumentItem,
        initialPageNumber: Int? = nil,
        extractionService: PDFTextExtractionService = PDFTextExtractionService()
    ) {
        documentItem = document
        let loadedPDFDocument = PDFDocument(url: document.fileURL)
        pdfDocument = loadedPDFDocument
        currentPageIndex = Self.pageIndex(
            forRequestedPageNumber: initialPageNumber,
            pageCount: loadedPDFDocument?.pageCount ?? 0
        )
        self.extractionService = extractionService
    }

    static func pageIndex(forRequestedPageNumber pageNumber: Int?, pageCount: Int) -> Int {
        guard pageCount > 0, let pageNumber else {
            return 0
        }
        return min(max(pageNumber - 1, 0), pageCount - 1)
    }

    static func pageIndex(forPageNumberInput input: String, pageCount: Int) -> Int? {
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            pageCount > 0,
            let pageNumber = Int(normalizedInput),
            (1...pageCount).contains(pageNumber)
        else {
            return nil
        }

        return pageNumber - 1
    }

    var pageCount: Int {
        pdfDocument?.pageCount ?? 0
    }

    var pageLabel: String {
        pageCount == 0 ? "0 / 0" : "\(currentPageIndex + 1) / \(pageCount)"
    }

    func showPreviousPage() {
        currentPageIndex = max(currentPageIndex - 1, 0)
    }

    func showNextPage() {
        currentPageIndex = min(currentPageIndex + 1, max(pageCount - 1, 0))
    }

    @discardableResult
    func goToPageNumber(_ input: String) -> Bool {
        guard let pageIndex = Self.pageIndex(forPageNumberInput: input, pageCount: pageCount) else {
            return false
        }

        currentPageIndex = pageIndex
        return true
    }

    func zoomIn() {
        zoomScale = min(zoomScale + 0.15, 3)
    }

    func zoomOut() {
        zoomScale = max(zoomScale - 0.15, 0.5)
    }

    func resetZoom() {
        zoomScale = 1
    }

    func extractCurrentPage() {
        let text = extractionService.extractText(
            from: documentItem.fileURL,
            pageIndex: currentPageIndex
        )
        extractedPageText = text
        extractionMessage = text.isEmpty
            ? "该 PDF 可能是扫描版，当前 Demo 暂不支持 OCR。"
            : nil
    }
}
