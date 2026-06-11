import Foundation

enum WebPageFetchError: LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case notHTML
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "请输入有效的 HTTP 或 HTTPS 网页链接。"
        case .networkError(let detail):
            "无法获取网页内容：\(detail)"
        case .notHTML:
            "该链接返回的不是 HTML 网页，请改为粘贴正文。"
        case .timeout:
            "请求超时，请检查网络连接或改为粘贴正文。"
        }
    }
}

struct WebPageFetchResult {
    let html: String
    let finalURL: URL
}

struct WebPageFetchService {
    private let session: URLSession
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 15) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.httpMaximumConnectionsPerHost = 2
        self.session = URLSession(configuration: config)
        self.timeout = timeout
    }

    /// Fetches HTML content from a URL string, following redirects.
    /// Returns the HTML string and the final URL (after any redirects).
    func fetch(urlString: String) async throws -> WebPageFetchResult {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let url = URL(string: trimmed),
            ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil
        else {
            throw WebPageFetchError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebPageFetchError.networkError("意外的响应类型。")
        }

        guard (200...399).contains(httpResponse.statusCode) else {
            throw WebPageFetchError.networkError("HTTP \(httpResponse.statusCode)")
        }

        // Check content type is HTML
        let contentType = httpResponse.allHeaderFields["Content-Type"] as? String ?? ""
        let mimeType = httpResponse.mimeType ?? ""
        let isHTML = contentType.contains("text/html")
            || mimeType.contains("text/html")
            || contentType.contains("application/xhtml")

        if !isHTML && !contentType.isEmpty {
            throw WebPageFetchError.notHTML
        }

        guard let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(data: data, encoding: .windowsCP1252)
        else {
            throw WebPageFetchError.networkError("无法解码网页内容。")
        }

        return WebPageFetchResult(
            html: html,
            finalURL: httpResponse.url ?? url
        )
    }
}
