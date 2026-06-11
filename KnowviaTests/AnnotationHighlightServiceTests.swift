import AppKit
import PDFKit
import XCTest
@testable import Knowvia

final class AnnotationHighlightServiceTests: XCTestCase {
    private let service = AnnotationHighlightService()

    func testFindsFirstTextOccurrenceForEachAnnotation() {
        let first = TestFactories.makeDocumentAnnotation(
            documentTitle: "Notes",
            selectedText: "knowledge path",
            note: "Remember this"
        )
        let second = TestFactories.makeDocumentAnnotation(
            documentTitle: "Notes",
            selectedText: "cards",
            note: "Remember this"
        )

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
        let annotation = TestFactories.makeDocumentAnnotation(
            documentTitle: "Notes",
            selectedText: "Knowvia",
            note: "Remember this",
            page: 2
        )

        let selections = service.pdfSelections(for: [annotation], in: document)

        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.string, "Knowvia")
        XCTAssertEqual(selections.first?.pages.first.map(document.index(for:)), 1)
    }

    /// Specialized helper that creates a real PDFPage via AppKit rendering.
    /// Kept locally because it depends on AppKit and is specific to PDF highlight tests.
    private func makePage(text: String) -> PDFPage {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 720))
        let textField = NSTextField(labelWithString: text)
        textField.frame = NSRect(x: 42, y: 620, width: 420, height: 30)
        view.addSubview(textField)
        let document = PDFDocument(data: view.dataWithPDF(inside: view.bounds))!
        return document.page(at: 0)!
    }
}
