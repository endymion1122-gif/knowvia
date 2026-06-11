import XCTest
@testable import Knowvia

final class KeychainServiceTests: XCTestCase {
    private var keychainService: KeychainService!

    override func setUpWithError() throws {
        keychainService = KeychainService(
            service: "KeychainServiceTests.\(UUID().uuidString)",
            account: "test-api-key"
        )
        try keychainService.deleteAPIKey()
    }

    override func tearDownWithError() throws {
        try keychainService.deleteAPIKey()
    }

    func testSavesUpdatesAndDeletesAPIKey() throws {
        XCTAssertNil(try keychainService.loadAPIKey())

        try keychainService.saveAPIKey("first-secret")
        XCTAssertEqual(try keychainService.loadAPIKey(), "first-secret")

        try keychainService.saveAPIKey("updated-secret")
        XCTAssertEqual(try keychainService.loadAPIKey(), "updated-secret")

        try keychainService.deleteAPIKey()
        XCTAssertNil(try keychainService.loadAPIKey())
    }
}
