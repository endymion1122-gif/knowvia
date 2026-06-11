import SwiftData
import XCTest
@testable import Knowvia

@MainActor
final class DocumentItemPersistenceTests: XCTestCase {
    func testPersistsDocumentMetadataInMemory() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DocumentItem.self,
            configurations: configuration
        )
        let context = container.mainContext
        let document = DocumentItem(
            title: "Research Notes",
            filePath: "/tmp/research-notes.md",
            fileType: "md",
            tags: ["course", "methods"],
            readingStatus: "reading",
            lastReadPageNumber: 6,
            sourceKind: DocumentSourceKind.webPage.rawValue,
            author: "Research Group",
            publicationYear: 2026,
            sourceURLString: "https://example.com/research",
            sourceNote: "待回到原文核验。",
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue,
            contributionNote: "补充方法背景。"
        )

        context.insert(document)
        try context.save()

        let documents = try context.fetch(FetchDescriptor<DocumentItem>())
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(documents.first?.title, "Research Notes")
        XCTAssertEqual(documents.first?.tags, ["course", "methods"])
        XCTAssertEqual(documents.first?.readingState, .reading)
        XCTAssertEqual(documents.first?.lastReadPageNumber, 6)
        XCTAssertEqual(documents.first?.sourceType, .webPage)
        XCTAssertEqual(documents.first?.author, "Research Group")
        XCTAssertEqual(documents.first?.publicationYear, 2026)
        XCTAssertEqual(documents.first?.sourceURLString, "https://example.com/research")
        XCTAssertEqual(documents.first?.credibility, .needsVerification)
        XCTAssertEqual(documents.first?.contributionNote, "补充方法背景。")
    }
}
