import AppKit
import PDFKit
import XCTest
@testable import Knowvia

final class AnnotationHighlightServiceTests: XCTestCase {
    private let service = AnnotationHighlightService()

    func testFindsFirstTextOccurrenceForEachAnnotation() {
        let first = makeAnnotation(selectedText: "knowledge path")
        let second = makeAnnotation(selectedText: "cards")

        let ranges = service.textRanges(
            for: [first, second],
            in: "knowledge path, cards, knowledge path"
        )

        XCTAssertEqual(ranges, [
            NSRange(location: 0, length: 14),
            NSRange(location: 16, length: 5),
        ])
    }

    func testFindsPDFSelectionOnRecordedPage() throws {
        let document = PDFDocument()
        document.insert(makePage(text: "Knowvia first page"), at: 0)
        document.insert(makePage(text: "Knowvia second page"), at: 1)
        let annotation = makeAnnotation(selectedText: "Knowvia", pageNumber: 2)

        let selections = service.pdfSelections(for: [annotation], in: document)

        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.string, "Knowvia")
        XCTAssertEqual(selections.first?.pages.first.map(document.index(for:)), 1)
    }

    private func makeAnnotation(
        selectedText: String,
        pageNumber: Int? = nil
    ) -> DocumentAnnotation {
        DocumentAnnotation(
            documentId: UUID(),
            documentTitle: "Notes",
            selectedText: selectedText,
            note: "Remember this",
            pageNumber: pageNumber
        )
    }

    private func makePage(text: String) -> PDFPage {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 720))
        let textField = NSTextField(labelWithString: text)
        textField.frame = NSRect(x: 42, y: 620, width: 420, height: 30)
        view.addSubview(textField)
        let document = PDFDocument(data: view.dataWithPDF(inside: view.bounds))!
        return document.page(at: 0)!
    }
}
