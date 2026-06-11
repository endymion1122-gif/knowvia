import XCTest
@testable import Knowvia

final class WebSourceExtractionServiceTests: XCTestCase {
    private let service = WebSourceExtractionService()

    func testExtractsTitleAuthorYearAndReadableTextFromHTML() throws {
        let html = """
        <html>
          <head>
            <title>Attention Is All You Need</title>
            <meta name="author" content="Vaswani et al.">
          </head>
          <body>
            <script>ignore()</script>
            <h1>Attention Is All You Need</h1>
            <p>Published in 2017. Transformer uses attention mechanisms.</p>
          </body>
        </html>
        """

        let draft = try service.extract(from: html)

        XCTAssertEqual(draft.title, "Attention Is All You Need")
        XCTAssertEqual(draft.author, "Vaswani et al.")
        XCTAssertEqual(draft.publicationYear, 2017)
        XCTAssertTrue(draft.excerpt.contains("Transformer uses attention mechanisms."))
        XCTAssertFalse(draft.excerpt.contains("ignore()"))
    }

    func testExtractsFromPlainText() throws {
        let draft = try service.extract(
            from: """
            作者：Learning Lab
            2026
            这是一段网页正文。
            """
        )

        XCTAssertEqual(draft.author, "Learning Lab")
        XCTAssertEqual(draft.publicationYear, 2026)
        XCTAssertTrue(draft.excerpt.contains("这是一段网页正文。"))
    }

    func testRejectsBlankContent() {
        XCTAssertThrowsError(try service.extract(from: "  ")) { error in
            XCTAssertEqual(error as? WebSourceExtractionError, .missingContent)
        }
    }
}
