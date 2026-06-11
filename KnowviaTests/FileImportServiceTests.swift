import Foundation
import XCTest
@testable import Knowvia

final class FileImportServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var libraryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        libraryDirectory = temporaryDirectory.appendingPathComponent("Library", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testImportsSupportedTextAndMarkdownFiles() throws {
        let service = FileImportService(libraryRootURL: libraryDirectory)
        let txt = try makeSourceFile(named: "lecture.txt", contents: "Local TXT content")
        let markdown = try makeSourceFile(named: "notes.md", contents: "# Local Markdown")

        let txtDocument = try service.importDocument(from: txt)
        let markdownDocument = try service.importDocument(from: markdown)

        XCTAssertEqual(txtDocument.fileType, "txt")
        XCTAssertEqual(txtDocument.extractedText, "Local TXT content")
        XCTAssertEqual(markdownDocument.fileType, "md")
        XCTAssertEqual(markdownDocument.extractedText, "# Local Markdown")
        XCTAssertEqual(txtDocument.sourceType, .uploadedFile)
        XCTAssertEqual(txtDocument.credibility, .userProvided)
        XCTAssertTrue(FileManager.default.fileExists(atPath: txtDocument.filePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: markdownDocument.filePath))
    }

    func testRejectsUnsupportedFileType() throws {
        let service = FileImportService(libraryRootURL: libraryDirectory)
        let source = try makeSourceFile(named: "archive.zip", contents: "not supported")

        XCTAssertThrowsError(try service.importDocument(from: source)) { error in
            guard case FileImportError.unsupportedFileType("zip") = error else {
                return XCTFail("Expected unsupportedFileType, received \(error)")
            }
        }
    }

    func testSameNamedFilesAreStoredSeparately() throws {
        let service = FileImportService(libraryRootURL: libraryDirectory)
        let firstFolder = temporaryDirectory.appendingPathComponent("One", isDirectory: true)
        let secondFolder = temporaryDirectory.appendingPathComponent("Two", isDirectory: true)
        try FileManager.default.createDirectory(at: firstFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondFolder, withIntermediateDirectories: true)

        let first = firstFolder.appendingPathComponent("notes.txt")
        let second = secondFolder.appendingPathComponent("notes.txt")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)

        let firstDocument = try service.importDocument(from: first)
        let secondDocument = try service.importDocument(from: second)

        XCTAssertNotEqual(firstDocument.filePath, secondDocument.filePath)
        XCTAssertEqual(try String(contentsOf: firstDocument.fileURL, encoding: .utf8), "first")
        XCTAssertEqual(try String(contentsOf: secondDocument.fileURL, encoding: .utf8), "second")
    }

    func testDeletesImportedCopyFolder() throws {
        let service = FileImportService(libraryRootURL: libraryDirectory)
        let source = try makeSourceFile(named: "delete-me.txt", contents: "temporary")
        let document = try service.importDocument(from: source)
        let documentFolder = document.fileURL.deletingLastPathComponent()

        try service.deleteImportedCopy(for: document)

        XCTAssertFalse(FileManager.default.fileExists(atPath: documentFolder.path))
    }

    func testRefusesToDeleteFileOutsideLibrary() throws {
        let service = FileImportService(libraryRootURL: libraryDirectory)
        let source = try makeSourceFile(named: "keep-me.txt", contents: "important")
        let document = DocumentItem(
            title: "External File",
            filePath: source.path,
            fileType: "txt"
        )

        XCTAssertThrowsError(try service.deleteImportedCopy(for: document)) { error in
            guard case FileImportError.cannotDeleteImportedCopy = error else {
                return XCTFail("Expected cannotDeleteImportedCopy, received \(error)")
            }
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    private func makeSourceFile(named name: String, contents: String) throws -> URL {
        let url = temporaryDirectory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }
}
