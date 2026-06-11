import SwiftData
import XCTest
@testable import Knowvia

@MainActor
final class DemoExperienceServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var defaults: UserDefaults!
    private var container: ModelContainer!
    private var service: DemoExperienceService!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let suiteName = "DemoExperienceServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: DocumentItem.self,
            KnowledgeCard.self,
            configurations: configuration
        )
        service = DemoExperienceService(
            importService: FileImportService(libraryRootURL: temporaryDirectory),
            defaults: defaults
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testInstallsSampleDocumentAndCardsIntoEmptyLibrary() throws {
        let result = try service.installIfNeeded(into: container.mainContext)
        let documents = try container.mainContext.fetch(FetchDescriptor<DocumentItem>())
        let cards = try container.mainContext.fetch(FetchDescriptor<KnowledgeCard>())

        XCTAssertEqual(result?.document.id, DemoExperienceService.sampleDocumentID)
        XCTAssertEqual(result?.addedCardCount, 3)
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(cards.count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: documents[0].filePath))
        XCTAssertTrue(defaults.bool(forKey: DemoExperienceService.installedKey))
    }

    func testRestoringSampleExperienceDoesNotCreateDuplicates() throws {
        _ = try service.installOrRestore(into: container.mainContext)
        let secondResult = try service.installOrRestore(into: container.mainContext)
        let documents = try container.mainContext.fetch(FetchDescriptor<DocumentItem>())
        let cards = try container.mainContext.fetch(FetchDescriptor<KnowledgeCard>())

        XCTAssertEqual(secondResult.addedCardCount, 0)
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(cards.count, 3)
    }

    func testAutomaticInstallLeavesExistingUserLibraryUntouched() throws {
        container.mainContext.insert(
            DocumentItem(
                title: "用户资料",
                filePath: "/tmp/user-notes.md",
                fileType: "md"
            )
        )
        try container.mainContext.save()

        XCTAssertNil(try service.installIfNeeded(into: container.mainContext))
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<DocumentItem>()).count, 1)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<KnowledgeCard>()).count, 0)
        XCTAssertTrue(defaults.bool(forKey: DemoExperienceService.installedKey))
    }
}
