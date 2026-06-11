import XCTest
@testable import Knowvia

final class TextDocumentSearchServiceTests: XCTestCase {
    private let service = TextDocumentSearchService()

    func testFindsEveryCaseInsensitiveMatch() {
        let matches = service.matches(for: "knowvia", in: "Knowvia makes knowledge a path. KNOWVIA keeps it reusable.")

        XCTAssertEqual(matches, [
            NSRange(location: 0, length: 7),
            NSRange(location: 32, length: 7)
        ])
    }

    func testReturnsNonOverlappingMatches() {
        let matches = service.matches(for: "ana", in: "banana")

        XCTAssertEqual(matches, [NSRange(location: 1, length: 3)])
    }

    func testIgnoresBlankQuery() {
        XCTAssertTrue(service.matches(for: "  \n", in: "Some text").isEmpty)
    }
}
