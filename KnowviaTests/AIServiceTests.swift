import Foundation
import XCTest
@testable import Knowvia

final class AIServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testSendsCompatibleChatCompletionRequest() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try Self.requestBody(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "test-model")

            let data = try XCTUnwrap(
                #"{"choices":[{"message":{"content":"结构化摘要"}}]}"#.data(using: .utf8)
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let result = try await makeService().sendChatCompletion(
            endpoint: "https://example.com/v1/chat/completions",
            apiKey: "test-key",
            model: "test-model",
            messages: [AIMessage(role: "user", content: "请总结")]
        )

        XCTAssertEqual(result, "结构化摘要")
    }

    func testMapsAuthenticationFailure() async {
        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        do {
            _ = try await makeService().sendChatCompletion(
                endpoint: "https://example.com/v1/chat/completions",
                apiKey: "invalid",
                model: "test-model",
                messages: [AIMessage(role: "user", content: "test")]
            )
            XCTFail("Expected authentication failure")
        } catch {
            guard case AIServiceError.authenticationFailed = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private func makeService() -> AIService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return AIService(session: URLSession(configuration: configuration))
    }

    private static func requestBody(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeRawData)
            }
            if count == 0 {
                break
            }
            body.append(buffer, count: count)
        }
        return body
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            XCTFail("MockURLProtocol handler was not configured")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
