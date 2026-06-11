import XCTest
@testable import Knowvia

final class AIErrorRecoveryServiceTests: XCTestCase {
    private let service = AIErrorRecoveryService()

    func testBuildsActionableMissingKeyMessage() {
        let message = service.message(
            for: AIServiceError.missingAPIKey,
            action: .documentSummary
        )

        XCTAssertTrue(message.contains("AI 速读未完成"))
        XCTAssertTrue(message.contains("DeepSeek 预设"))
        XCTAssertTrue(message.contains("API Key"))
    }

    func testBuildsDeepSeekEndpointSuggestion() {
        let message = service.message(
            for: AIServiceError.invalidEndpoint,
            action: .selectionCard
        )

        XCTAssertTrue(message.contains("AI 智能制卡未完成"))
        XCTAssertTrue(message.contains("https://api.deepseek.com/chat/completions"))
    }

    func testBuildsQuotaSuggestionForRateLimit() {
        let message = service.message(
            for: AIServiceError.rateLimited,
            action: .annotationCard
        )

        XCTAssertTrue(message.contains("额度"))
        XCTAssertTrue(message.contains("配额"))
    }
}
