import XCTest
@testable import Knowvia

final class DocumentReadingProgressServiceTests: XCTestCase {
    private let service = DocumentReadingProgressService()

    func testMarksUnreadDocumentAsReadingAndPreservesCompletedState() {
        let openedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let unreadDocument = TestFactories.makeDocumentItem(fileType: "pdf")
        let completedDocument = TestFactories.makeDocumentItem(
            fileType: "pdf",
            readingStatus: "completed"
        )

        service.markOpened(unreadDocument, at: openedAt)
        service.markOpened(completedDocument, at: openedAt)

        XCTAssertEqual(unreadDocument.readingState, .reading)
        XCTAssertEqual(unreadDocument.lastOpenedAt, openedAt)
        XCTAssertEqual(completedDocument.readingState, .completed)
    }

    func testStoresAndRestoresPDFProgressButIgnoresTextDocuments() {
        let pdf = TestFactories.makeDocumentItem(fileType: "pdf")
        let markdown = TestFactories.makeDocumentItem(fileType: "md")

        service.updatePDFProgress(pdf, pageNumber: 12)
        service.updatePDFProgress(markdown, pageNumber: 12)

        XCTAssertEqual(pdf.lastReadPageNumber, 12)
        XCTAssertEqual(service.resumePageNumber(for: pdf), 12)
        XCTAssertNil(markdown.lastReadPageNumber)
        XCTAssertNil(service.resumePageNumber(for: markdown))
    }

    func testTogglesCompletedState() {
        let document = TestFactories.makeDocumentItem(
            fileType: "pdf",
            readingStatus: "reading"
        )

        service.toggleCompleted(document)
        XCTAssertEqual(document.readingState, .completed)

        service.toggleCompleted(document)
        XCTAssertEqual(document.readingState, .reading)
    }

    func testSortsRecentlyOpenedDocumentsByLatestOpenTime() {
        let older = TestFactories.makeDocumentItem(
            fileType: "pdf",
            lastOpenedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = TestFactories.makeDocumentItem(
            fileType: "pdf",
            lastOpenedAt: Date(timeIntervalSince1970: 200)
        )
        let unopened = TestFactories.makeDocumentItem(fileType: "pdf")

        XCTAssertEqual(service.recentDocuments(in: [older, unopened, newer]).map(\.id), [newer.id, older.id])
    }
}

@MainActor
final class AppStateReadingProgressTests: XCTestCase {
    func testRestoresSavedPDFPageUnlessExplicitPageWasRequested() {
        let document = DocumentItem(
            title: "测试 PDF",
            filePath: "/tmp/knowvia-reading-progress.pdf",
            fileType: "pdf",
            lastReadPageNumber: 7
        )
        let appState = AppState()

        appState.open(document)
        XCTAssertEqual(appState.requestedPDFPageNumber, 7)

        appState.open(document, pageNumber: 3)
        XCTAssertEqual(appState.requestedPDFPageNumber, 3)
    }
}
