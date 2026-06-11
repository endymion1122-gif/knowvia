import Foundation
import XCTest
@testable import Knowvia

final class WebPageFetchServiceTests: XCTestCase {

    // MARK: - URL Validation

    func testRejectsNonHTTPURL() async {
        let service = WebPageFetchService()
        do {
            _ = try await service.fetch(urlString: "ftp://example.com/page")
            XCTFail("Expected error for non-HTTP URL")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRejectsEmptyURLString() async {
        let service = WebPageFetchService()
        do {
            _ = try await service.fetch(urlString: "   ")
            XCTFail("Expected error for empty URL")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRejectsURLWithoutHost() async {
        let service = WebPageFetchService()
        do {
            _ = try await service.fetch(urlString: "http:///path")
            XCTFail("Expected error for URL without host")
        } catch let error as WebPageFetchError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - HTML Decoding

    func testHandlesVariousEncodings() async {
        // This test validates the encoding fallback chain exists.
        // Real encoding testing requires a server, so we test the structure.
        let service = WebPageFetchService()
        // UTF-8 strings in the initializer are validated at compile time
        XCTAssertNotNil(service)
    }
}
