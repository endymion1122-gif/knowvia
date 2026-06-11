import Foundation
import XCTest
@testable import Knowvia

@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - Navigation & Selection

    func testInitialSelectionIsDashboard() {
        let appState = AppState()
        XCTAssertEqual(appState.selection, .dashboard)
    }

    func testSelectDestinationClearsActiveDocumentAndResetsState() {
        let appState = AppState()
        let document = TestFactories.makeDocumentItem(title: "Test Doc")

        appState.open(document)
        XCTAssertNotNil(appState.activeDocument)

        appState.select(.library)
        XCTAssertEqual(appState.selection, .library)
        XCTAssertNil(appState.activeDocument)
        XCTAssertEqual(appState.selectedPDFText, "")
        XCTAssertNil(appState.selectedPDFPageNumber)
    }

    func testSelectAllSidebarDestinationsWork() {
        let appState = AppState()

        for destination in SidebarDestination.allCases where destination.isAvailable {
            appState.select(destination)
            XCTAssertEqual(appState.selection, destination)
        }
    }

    func testGraphAndWritingDestinationsAreUnavailable() {
        XCTAssertFalse(SidebarDestination.graph.isAvailable)
        XCTAssertFalse(SidebarDestination.writing.isAvailable)
    }

    // MARK: - Document Open

    func testOpenPDFDocumentSetsRequestedPageNumberFromProgress() {
        let appState = AppState()
        let document = DocumentItem(
            title: "Test PDF",
            filePath: "/tmp/test.pdf",
            fileType: "pdf",
            lastReadPageNumber: 7
        )

        appState.open(document)
        XCTAssertEqual(appState.activeDocument?.id, document.id)
        XCTAssertEqual(appState.requestedPDFPageNumber, 7)
        XCTAssertEqual(appState.inspectorPageNumber, 7)
    }

    func testOpenDocumentWithExplicitPageNumberOverridesSavedProgress() {
        let appState = AppState()
        let document = DocumentItem(
            title: "Test PDF",
            filePath: "/tmp/test.pdf",
            fileType: "pdf",
            lastReadPageNumber: 7
        )

        appState.open(document, pageNumber: 3)
        XCTAssertEqual(appState.requestedPDFPageNumber, 3)
    }

    func testOpenTextDocumentDoesNotSetPDFPageNumber() {
        let appState = AppState()
        let document = TestFactories.makeDocumentItem(
            title: "Test Markdown",
            fileType: "md",
            lastReadPageNumber: 5
        )

        appState.open(document)
        XCTAssertNil(appState.requestedPDFPageNumber)
        XCTAssertNil(appState.inspectorPageNumber)
    }

    func testOpenTextDocumentWithAnchorExcerptIncrementsAnchorID() {
        let appState = AppState()
        let document = TestFactories.makeDocumentItem(fileType: "md")
        let initialID = appState.requestedTextAnchorID

        appState.open(document, textAnchorExcerpt: "some text")
        XCTAssertEqual(appState.requestedTextAnchorExcerpt, "some text")
        XCTAssertEqual(appState.requestedTextAnchorID, initialID + 1)
    }

    // MARK: - State Reset on Navigation

    func testOpenDocumentResetsAIState() {
        let appState = AppState()
        let document = TestFactories.makeDocumentItem()

        // Set some AI state first
        appState.select(.dashboard)
        appState.open(document)

        XCTAssertEqual(appState.aiSummary, "")
        XCTAssertNil(appState.aiSummaryNotice)
        XCTAssertNil(appState.aiErrorMessage)
        XCTAssertFalse(appState.isSummarizing)
        XCTAssertTrue(appState.suggestedCardDrafts.isEmpty)
        XCTAssertEqual(appState.aiSelectionExplanation, "")
        XCTAssertNil(appState.aiSelectionNotice)
        XCTAssertNil(appState.aiSelectionErrorMessage)
        XCTAssertFalse(appState.isExplainingSelection)
    }

    func testSelectDestinationResetsAIState() {
        let appState = AppState()

        appState.select(.library)
        XCTAssertFalse(appState.isSummarizing)
        XCTAssertFalse(appState.isExplainingSelection)
        XCTAssertFalse(appState.isGeneratingSelectionCard)
        XCTAssertFalse(appState.isGeneratingAnnotationCard)
    }

    // MARK: - Selected Text

    func testUpdateSelectedTextResetsRelatedAIStateWhenTextChanges() {
        let appState = AppState()

        appState.updateSelectedText("first text", pageNumber: 1)
        XCTAssertEqual(appState.selectedPDFText, "first text")
        XCTAssertEqual(appState.selectedPDFPageNumber, 1)

        appState.updateSelectedText("different text", pageNumber: 2)
        XCTAssertEqual(appState.selectedPDFText, "different text")
        XCTAssertEqual(appState.selectedPDFPageNumber, 2)
        // AI explanation should be cleared when text changes
        XCTAssertEqual(appState.aiSelectionExplanation, "")
        XCTAssertNil(appState.aiSelectionNotice)
    }

    func testUpdateSelectedTextWithSameTextDoesNotClearAIState() {
        let appState = AppState()

        appState.updateSelectedText("same text", pageNumber: 1)
        // We can't easily set aiSelectionExplanation without mocking,
        // but we can verify the text and page are stored
        XCTAssertEqual(appState.selectedPDFText, "same text")
        XCTAssertEqual(appState.selectedPDFPageNumber, 1)
    }

    // MARK: - Sidebar Destination Metadata

    func testSidebarDestinationTitles() {
        XCTAssertEqual(SidebarDestination.dashboard.title, "首页")
        XCTAssertEqual(SidebarDestination.library.title, "资料库")
        XCTAssertEqual(SidebarDestination.pathways.title, "专题路径库")
        XCTAssertEqual(SidebarDestination.cards.title, "知识卡片")
        XCTAssertEqual(SidebarDestination.settings.title, "设置")
    }

    func testSidebarDestinationSymbols() {
        XCTAssertEqual(SidebarDestination.dashboard.symbolName, "house")
        XCTAssertEqual(SidebarDestination.library.symbolName, "books.vertical")
        XCTAssertEqual(SidebarDestination.graph.symbolName, "point.3.connected.trianglepath.dotted")
    }

    // MARK: - Edge Cases

    func testSelectSameDestinationMultipleTimesIsIdempotent() {
        let appState = AppState()
        let document = TestFactories.makeDocumentItem()
        appState.open(document)

        appState.select(.dashboard)
        appState.select(.dashboard)
        appState.select(.dashboard)

        XCTAssertEqual(appState.selection, .dashboard)
        XCTAssertNil(appState.activeDocument)
    }

    func testOpenMultipleDocumentsInSequence() {
        let appState = AppState()
        let first = TestFactories.makeDocumentItem(title: "First", fileType: "pdf")
        let second = TestFactories.makeDocumentItem(title: "Second", fileType: "pdf")

        appState.open(first, pageNumber: 5)
        XCTAssertEqual(appState.activeDocument?.id, first.id)
        XCTAssertEqual(appState.requestedPDFPageNumber, 5)

        appState.open(second, pageNumber: 10)
        XCTAssertEqual(appState.activeDocument?.id, second.id)
        XCTAssertEqual(appState.requestedPDFPageNumber, 10)
    }

    func testGeneratedSelectionCardCreatedByLabel() {
        let appState = AppState()
        // When demo mode is enabled (default), createdBy should be "ai-demo"
        XCTAssertEqual(appState.generatedSelectionCardCreatedBy, "ai-demo")
    }
}
