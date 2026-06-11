import AppKit
import Foundation
import PDFKit
import XCTest
@testable import Knowvia

final class PDFTextExtractionServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private let service = PDFTextExtractionService()
    private let searchService = PDFDocumentSearchService()

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testExtractsTextFromWholePDFAndSinglePage() throws {
        let url = temporaryDirectory.appendingPathComponent("readable.pdf")
        try makePDF(text: "Knowvia readable PDF text", at: url)

        XCTAssertTrue(service.extractText(from: url).contains("Knowvia readable PDF text"))
        XCTAssertTrue(service.extractText(from: url, pageIndex: 0).contains("Knowvia readable PDF text"))
    }

    func testReturnsEmptyTextForImageOnlyOrBlankPDF() throws {
        let url = temporaryDirectory.appendingPathComponent("blank.pdf")
        try makePDF(text: nil, at: url)

        XCTAssertEqual(service.extractText(from: url), "")
        XCTAssertEqual(service.extractText(from: url, pageIndex: 0), "")
    }

    func testSearchFindsCaseInsensitivePDFSelections() throws {
        let url = temporaryDirectory.appendingPathComponent("searchable.pdf")
        try makePDF(text: "KNOWVIA searchable PDF text", at: url)
        let document = try XCTUnwrap(PDFDocument(url: url))

        let matches = searchService.selections(for: "knowvia", in: document)

        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.contains { $0.string == "KNOWVIA" })
    }

    func testSearchIgnoresBlankQuery() throws {
        let url = temporaryDirectory.appendingPathComponent("searchable.pdf")
        try makePDF(text: "Knowvia searchable PDF text", at: url)
        let document = try XCTUnwrap(PDFDocument(url: url))

        XCTAssertTrue(searchService.selections(for: " \n", in: document).isEmpty)
    }

    private func makePDF(text: String?, at url: URL) throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 720))

        if let text {
            let textField = NSTextField(labelWithString: text)
            textField.frame = NSRect(x: 42, y: 620, width: 420, height: 30)
            view.addSubview(textField)
        }

        try view.dataWithPDF(inside: view.bounds).write(to: url)
    }
}
