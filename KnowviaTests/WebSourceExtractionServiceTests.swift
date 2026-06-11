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

    // MARK: - JSON-LD Extraction

    func testExtractsMetadataFromJSONLD() throws {
        let html = """
        <html>
          <head>
            <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "Article",
              "headline": "The Future of AI",
              "author": "Jane Smith",
              "datePublished": "2025-03-15",
              "description": "An exploration of AI trends."
            }
            </script>
          </head>
          <body>
            <h1>The Future of AI</h1>
            <p>Artificial intelligence continues to evolve rapidly.</p>
          </body>
        </html>
        """

        let draft = try service.extract(from: html)

        XCTAssertEqual(draft.title, "The Future of AI")
        XCTAssertEqual(draft.author, "Jane Smith")
        XCTAssertEqual(draft.publicationYear, 2025)
        XCTAssertTrue(draft.excerpt.contains("Artificial intelligence continues to evolve rapidly."))
    }

    func testExtractsJSONLDAuthorWithNestedPersonObject() throws {
        let html = """
        <html>
          <head>
            <script type="application/ld+json">
            {
              "@type": "Article",
              "headline": "Research Paper",
              "author": {
                "@type": "Person",
                "name": "Dr. Alice Chen"
              },
              "datePublished": "2024-06-01"
            }
            </script>
          </head>
          <body>
            <p>Research content here.</p>
          </body>
        </html>
        """

        let draft = try service.extract(from: html)

        XCTAssertEqual(draft.author, "Dr. Alice Chen")
        XCTAssertEqual(draft.publicationYear, 2024)
    }

    func testPrefersJSONLDTitleOverHTMLTitle() throws {
        let html = """
        <html>
          <head>
            <title>Page Title</title>
            <script type="application/ld+json">
            {
              "@type": "Article",
              "headline": "Article Headline"
            }
            </script>
          </head>
          <body>
            <p>Content.</p>
          </body>
        </html>
        """

        let draft = try service.extract(from: html)
        XCTAssertEqual(draft.title, "Article Headline")
    }

    func testExtractsFromArticlePublishedTimeMeta() throws {
        let html = """
        <html>
          <head>
            <meta property="article:published_time" content="2023-11-20T10:30:00Z">
          </head>
          <body>
            <h1>News Article</h1>
            <p>Breaking news content here.</p>
          </body>
        </html>
        """

        let draft = try service.extract(from: html)

        XCTAssertEqual(draft.publicationYear, 2023)
    }

    func testExtractsTwitterCardTitle() throws {
        let html = """
        <html>
          <head>
            <meta name="twitter:title" content="Twitter Card Title">
          </head>
          <body>
            <p>Content.</p>
          </body>
        </html>
        """

        let draft = try service.extract(from: html)
        XCTAssertEqual(draft.title, "Twitter Card Title")
    }

    func testJSONLDNameFallbackForHeadline() throws {
        let html = """
        <html>
          <head>
            <script type="application/ld+json">
            {
              "@type": "WebPage",
              "name": "WebPage Name"
            }
            </script>
          </head>
          <body>
            <p>Content.</p>
          </body>
        </html>
        """

        let draft = try service.extract(from: html)
        XCTAssertEqual(draft.title, "WebPage Name")
    }
}
