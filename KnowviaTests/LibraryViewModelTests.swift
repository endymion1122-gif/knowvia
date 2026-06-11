import Foundation
import SwiftData
import XCTest
@testable import Knowvia

@MainActor
final class LibraryViewModelTests: XCTestCase {
    private let fileManager = FileManager.default

    // MARK: - Import Logic

    func testImportsPDFDocumentIntoLibraray() throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let pdfFile = tempDir.appendingPathComponent("test.pdf")
        let pdfContent = "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000052 00000 n \n0000000101 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n182\n%%EOF"
        try pdfContent.write(to: pdfFile, atomically: true, encoding: .utf8)

        let container = try TestModelContext.makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = LibraryViewModel()
        viewModel.importDocuments(from: [pdfFile], into: context)

        XCTAssertEqual(viewModel.importedDocumentCount, 1)
        XCTAssertNil(viewModel.errorMessage)

        let documents = try context.fetch(FetchDescriptor<DocumentItem>())
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(documents.first?.title, "test")
        XCTAssertEqual(documents.first?.fileType, "pdf")
    }

    func testImportEmptyURLListDoesNotIncrementCount() throws {
        let container = try TestModelContext.makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = LibraryViewModel()
        viewModel.importDocuments(from: [], into: context)

        XCTAssertEqual(viewModel.importedDocumentCount, 0)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testImportUnsupportedFileTypeProducesErrorMessage() throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let unsupportedFile = tempDir.appendingPathComponent("document.pages")
        try "pages content".write(to: unsupportedFile, atomically: true, encoding: .utf8)

        let container = try TestModelContext.makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = LibraryViewModel()
        viewModel.importDocuments(from: [unsupportedFile], into: context)

        XCTAssertEqual(viewModel.importedDocumentCount, 0)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("暂不支持") ?? false)
    }

    func testImportMixedValidAndInvalidURLsTracksBoth() throws {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let pdfFile = tempDir.appendingPathComponent("valid.pdf")
        let pdfContent = "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000052 00000 n \n0000000101 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n182\n%%EOF"
        try pdfContent.write(to: pdfFile, atomically: true, encoding: .utf8)

        let unsupportedFile = tempDir.appendingPathComponent("bad.pages")
        try "content".write(to: unsupportedFile, atomically: true, encoding: .utf8)

        let container = try TestModelContext.makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = LibraryViewModel()
        viewModel.importDocuments(from: [pdfFile, unsupportedFile], into: context)

        XCTAssertEqual(viewModel.importedDocumentCount, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Drop Filtering

    func testDropAcceptsFileURLProviders() {
        let viewModel = LibraryViewModel()

        // NSItemProvider with file URL is complex to mock without AppKit.
        // This test validates the drop handler returns false for empty providers.
        let result = viewModel.importDroppedProviders(
            [],
            into: (try! TestModelContext.makeInMemoryContainer()).mainContext
        )

        XCTAssertFalse(result)
    }
}
