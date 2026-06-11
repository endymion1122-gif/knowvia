import Foundation
import XCTest
@testable import Knowvia

final class WebSourceImportServiceTests: XCTestCase {
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

    func testImportsWebSourceAsLocalMarkdownCopy() throws {
        let fileImportService = FileImportService(libraryRootURL: libraryDirectory)
        let service = WebSourceImportService(fileImportService: fileImportService)

        let document = try service.importWebSource(
            title: "Attention Is All You Need",
            urlString: "https://example.com/paper",
            excerpt: "Transformer uses attention mechanisms.",
            author: "Vaswani et al.",
            publicationYear: 2017,
            note: "回到原文核验实验部分。"
        )

        XCTAssertEqual(document.sourceType, .webPage)
        XCTAssertEqual(document.credibility, .needsVerification)
        XCTAssertEqual(document.author, "Vaswani et al.")
        XCTAssertEqual(document.publicationYear, 2017)
        XCTAssertEqual(document.sourceURLString, "https://example.com/paper")
        XCTAssertTrue(FileManager.default.fileExists(atPath: document.filePath))
        XCTAssertTrue(document.extractedText?.contains("Transformer uses attention mechanisms.") == true)
    }

    func testRejectsInvalidURL() {
        let service = WebSourceImportService(
            fileImportService: FileImportService(libraryRootURL: libraryDirectory)
        )

        XCTAssertThrowsError(
            try service.importWebSource(
                title: "Invalid",
                urlString: "example.com/no-scheme",
                excerpt: "Excerpt"
            )
        ) { error in
            XCTAssertEqual(error as? WebSourceImportError, .invalidURL)
        }
    }

    func testRejectsMissingExcerpt() {
        let service = WebSourceImportService(
            fileImportService: FileImportService(libraryRootURL: libraryDirectory)
        )

        XCTAssertThrowsError(
            try service.importWebSource(
                title: "No Body",
                urlString: "https://example.com",
                excerpt: "   "
            )
        ) { error in
            XCTAssertEqual(error as? WebSourceImportError, .missingExcerpt)
        }
    }

    func testImportsExternalEnrichmentCandidate() throws {
        let service = WebSourceImportService(
            fileImportService: FileImportService(libraryRootURL: libraryDirectory)
        )

        let document = try service.importWebSource(
            title: "Candidate",
            urlString: "https://example.com/candidate",
            excerpt: "Candidate excerpt.",
            sourceKind: .externalEnrichment
        )

        XCTAssertEqual(document.sourceType, .externalEnrichment)
        XCTAssertEqual(document.credibility, .needsVerification)
    }
}
