import XCTest
@testable import Knowvia

final class AnnotationMarkdownExportServiceTests: XCTestCase {
    private let service = AnnotationMarkdownExportService()

    func testExportsAnnotationSourceNoteAndExcerpt() throws {
        let annotation = DocumentAnnotation(
            documentId: UUID(),
            documentTitle: "Learning Notes",
            selectedText: "Knowledge becomes a path.",
            note: "Connect this idea to the learning path.",
            pageNumber: 7,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let markdown = try service.markdown(
            for: [annotation],
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        XCTAssertTrue(markdown.contains("# 知径 Knowvia 阅读批注"))
        XCTAssertTrue(markdown.contains("- 批注数量：1"))
        XCTAssertTrue(markdown.contains("## Connect this idea to the learning path."))
        XCTAssertTrue(markdown.contains("- 来源：Learning Notes，p.7"))
        XCTAssertTrue(markdown.contains("> Knowledge becomes a path."))
    }

    func testRejectsEmptyExport() {
        XCTAssertThrowsError(try service.markdown(for: [])) { error in
            XCTAssertEqual(error as? AnnotationMarkdownExportError, .noAnnotations)
        }
    }
}
