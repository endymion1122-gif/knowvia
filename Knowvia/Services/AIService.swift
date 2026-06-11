import Foundation

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case missingEndpoint
    case invalidEndpoint
    case missingModel
    case authenticationFailed
    case rateLimited
    case serverError
    case invalidResponse
    case emptyResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "请先在设置中添加 OpenAI-compatible API Key。"
        case .missingEndpoint:
            "请先配置 API Endpoint。"
        case .invalidEndpoint:
            "API Endpoint 格式无效。"
        case .missingModel:
            "请先配置 Model Name。"
        case .authenticationFailed:
            "认证失败，请检查 API Key、Endpoint 和模型服务商配置。"
        case .rateLimited:
            "请求过于频繁或额度不足，请稍后再试。"
        case .serverError:
            "模型服务暂时不可用，请稍后再试。"
        case .invalidResponse:
            "模型服务返回了无法解析的响应。"
        case .emptyResponse:
            "模型服务没有返回可显示的内容。"
        case .requestFailed(let message):
            "AI 请求失败：\(message)"
        }
    }
}

final class AIService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func sendChatCompletion(
        endpoint: String,
        apiKey: String,
        model: String,
        messages: [AIMessage]
    ) async throws -> String {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        guard !trimmedEndpoint.isEmpty else {
            throw AIServiceError.missingEndpoint
        }
        guard
            let url = URL(string: trimmedEndpoint),
            ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil
        else {
            throw AIServiceError.invalidEndpoint
        }
        guard !trimmedModel.isEmpty else {
            throw AIServiceError.missingModel
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequest(model: trimmedModel, messages: messages)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw AIServiceError.authenticationFailed
        case 429:
            throw AIServiceError.rateLimited
        case 500...599:
            throw AIServiceError.serverError
        default:
            let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw AIServiceError.requestFailed(
                apiError?.error.message ?? "HTTP \(httpResponse.statusCode)"
            )
        }

        guard
            let completion = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
            let content = completion.choices.first?.message.content?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            throw AIServiceError.invalidResponse
        }
        guard !content.isEmpty else {
            throw AIServiceError.emptyResponse
        }
        return content
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [AIMessage]
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct APIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
