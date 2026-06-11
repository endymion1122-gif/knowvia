import Foundation
import PDFKit
import XCTest
@testable import Knowvia

@MainActor
final class ReaderViewModelTests: XCTestCase {

    // MARK: - Page Index Calculation (static methods)

    func testPageIndexForRequestedPageNumberWithNilPageNumberReturnsZero() {
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: nil, pageCount: 10), 0)
    }

    func testPageIndexForRequestedPageNumberClampsHighValue() {
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: 99, pageCount: 10), 9)
    }

    func testPageIndexForRequestedPageNumberClampsZeroOrNegativeValue() {
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: 0, pageCount: 10), 0)
    }

    func testPageIndexForRequestedPageNumberWithZeroPageCountReturnsZero() {
        XCTAssertEqual(ReaderViewModel.pageIndex(forRequestedPageNumber: 3, pageCount: 0), 0)
    }

    func testPageIndexForValidNumberInputReturnsZeroBasedIndex() {
        XCTAssertEqual(ReaderViewModel.pageIndex(forPageNumberInput: "3", pageCount: 10), 2)
        XCTAssertEqual(ReaderViewModel.pageIndex(forPageNumberInput: "1", pageCount: 10), 0)
        XCTAssertEqual(ReaderViewModel.pageIndex(forPageNumberInput: "10", pageCount: 10), 9)
    }

    func testPageIndexForPageNumberInputTrimsWhitespace() {
        XCTAssertEqual(ReaderViewModel.pageIndex(forPageNumberInput: " 5 ", pageCount: 10), 4)
    }

    func testPageIndexRejectsOutOfRangeAndNonNumericInput() {
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "0", pageCount: 10))
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "11", pageCount: 10))
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "page", pageCount: 10))
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "1", pageCount: 0))
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "-1", pageCount: 10))
        XCTAssertNil(ReaderViewModel.pageIndex(forPageNumberInput: "", pageCount: 10))
    }

    // MARK: - Page Label

    func testPageLabelWithZeroPageCount() {
        let document = TestFactories.makeDocumentItem(filePath: "/nonexistent.pdf", fileType: "pdf")
        let viewModel = ReaderViewModel(document: document)
        XCTAssertEqual(viewModel.pageLabel, "0 / 0")
    }

    // MARK: - Zoom

    func testZoomOperations() {
        let document = TestFactories.makeDocumentItem(filePath: "/nonexistent.pdf", fileType: "pdf")
        let viewModel = ReaderViewModel(document: document)

        viewModel.zoomIn()
        XCTAssertEqual(viewModel.zoomScale, 1.15)

        viewModel.zoomOut()
        XCTAssertEqual(viewModel.zoomScale, 1.0, accuracy: 0.0001)
    }

    func testZoomInClampedAtThree() {
        let document = TestFactories.makeDocumentItem(filePath: "/nonexistent.pdf", fileType: "pdf")
        let viewModel = ReaderViewModel(document: document)
        viewModel.zoomScale = 2.95
        viewModel.zoomIn()
        XCTAssertEqual(viewModel.zoomScale, 3.0)
        viewModel.zoomIn()
        XCTAssertEqual(viewModel.zoomScale, 3.0)
    }

    func testZoomOutClampedAtPointFive() {
        let document = TestFactories.makeDocumentItem(filePath: "/nonexistent.pdf", fileType: "pdf")
        let viewModel = ReaderViewModel(document: document)
        viewModel.zoomScale = 0.55
        viewModel.zoomOut()
        XCTAssertEqual(viewModel.zoomScale, 0.5)
        viewModel.zoomOut()
        XCTAssertEqual(viewModel.zoomScale, 0.5)
    }

    func testResetZoomReturnsToOne() {
        let document = TestFactories.makeDocumentItem(filePath: "/nonexistent.pdf", fileType: "pdf")
        let viewModel = ReaderViewModel(document: document)
        viewModel.zoomScale = 2.5
        viewModel.resetZoom()
        XCTAssertEqual(viewModel.zoomScale, 1.0)
    }

    // MARK: - Page Navigation

    func testPageNavigationWithNonExistentPDF() {
        let document = TestFactories.makeDocumentItem(filePath: "/nonexistent.pdf", fileType: "pdf")
        let viewModel = ReaderViewModel(document: document)

        // With 0 pages, navigation should be no-ops
        viewModel.showNextPage()
        XCTAssertEqual(viewModel.currentPageIndex, 0)

        viewModel.showPreviousPage()
        XCTAssertEqual(viewModel.currentPageIndex, 0)
    }

    func testGoToPageNumberWithInvalidInput() {
        let document = TestFactories.makeDocumentItem(filePath: "/nonexistent.pdf", fileType: "pdf")
        let viewModel = ReaderViewModel(document: document)

        XCTAssertFalse(viewModel.goToPageNumber("page"))
        XCTAssertFalse(viewModel.goToPageNumber("0"))
        XCTAssertFalse(viewModel.goToPageNumber(""))
    }

    // MARK: - Initial Page Number

    func testInitializesWithZeroPageIndexForNilInitialPage() {
        let document = TestFactories.makeDocumentItem(filePath: "/nonexistent.pdf", fileType: "pdf")
        let viewModel = ReaderViewModel(document: document, initialPageNumber: nil)
        XCTAssertEqual(viewModel.currentPageIndex, 0)
    }

    func testExtractCurrentPageReturnsEmptyForNonExistentPDF() {
        let document = TestFactories.makeDocumentItem(filePath: "/nonexistent.pdf", fileType: "pdf")
        let viewModel = ReaderViewModel(document: document)

        viewModel.extractCurrentPage()

        XCTAssertTrue(viewModel.extractedPageText.isEmpty)
    }
}
