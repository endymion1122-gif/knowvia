import AppKit
import Foundation

enum WebSourceExtractionError: LocalizedError, Equatable {
    case missingContent
    case missingReadableText

    var errorDescription: String? {
        switch self {
        case .missingContent:
            "请先粘贴网页正文或 HTML 内容。"
        case .missingReadableText:
            "没有识别到可用正文，请改为粘贴网页正文片段。"
        }
    }
}

struct WebSourceExtractionDraft: Equatable {
    let title: String
    let author: String
    let publicationYear: Int?
    let excerpt: String
}

struct WebSourceExtractionService {
    func extract(from rawContent: String) throws -> WebSourceExtractionDraft {
        let normalizedContent = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedContent.isEmpty else {
            throw WebSourceExtractionError.missingContent
        }

        let title = firstMatch(
            in: normalizedContent,
            patterns: [
                #"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#,
                #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']"#,
                #"<title[^>]*>(.*?)</title>"#,
                #"<h1[^>]*>(.*?)</h1>"#,
            ]
        )
        let author = firstMatch(
            in: normalizedContent,
            patterns: [
                #"<meta[^>]+name=["']author["'][^>]+content=["']([^"']+)["']"#,
                #"<meta[^>]+property=["']article:author["'][^>]+content=["']([^"']+)["']"#,
                #"<meta[^>]+content=["']([^"']+)["'][^>]+name=["']author["']"#,
                #"作者[:：]\s*([^\n\r<]+)"#,
                #"Author[:：]\s*([^\n\r<]+)"#,
            ]
        )
        let year = extractYear(from: normalizedContent)
        let readableText = htmlToReadableText(normalizedContent)
        guard !readableText.isEmpty else {
            throw WebSourceExtractionError.missingReadableText
        }

        return WebSourceExtractionDraft(
            title: clean(title),
            author: clean(author),
            publicationYear: year,
            excerpt: readableText
        )
    }

    private func firstMatch(in content: String, patterns: [String]) -> String {
        for pattern in patterns {
            if let match = regexMatch(in: content, pattern: pattern) {
                return match
            }
        }
        return ""
    }

    private func regexMatch(in content: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        guard
            let match = regex.firstMatch(in: content, range: range),
            match.numberOfRanges > 1,
            let resultRange = Range(match.range(at: 1), in: content)
        else {
            return nil
        }
        return String(content[resultRange])
    }

    private func extractYear(from content: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(19|20)\d{2}\b"#) else {
            return nil
        }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        guard
            let match = regex.firstMatch(in: content, range: range),
            let matchRange = Range(match.range, in: content)
        else {
            return nil
        }
        return Int(content[matchRange])
    }

    private func htmlToReadableText(_ content: String) -> String {
        var text = content
        text = replacing(text, pattern: #"<script[\s\S]*?</script>"#, with: " ")
        text = replacing(text, pattern: #"<style[\s\S]*?</style>"#, with: " ")
        text = replacing(text, pattern: #"<(br|p|div|section|article|li|h[1-6])[^>]*>"#, with: "\n")
        text = replacing(text, pattern: #"</(p|div|section|article|li|h[1-6])>"#, with: "\n")
        text = replacing(text, pattern: #"<[^>]+>"#, with: " ")
        text = decodeHTMLEntities(text)
        return normalizeLines(text)
    }

    private func replacing(_ value: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }

    private func decodeHTMLEntities(_ value: String) -> String {
        guard let data = value.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
              )
        else {
            return value
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
        }
        return attributed.string
    }

    private func normalizeLines(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func clean(_ value: String) -> String {
        normalizeLines(decodeHTMLEntities(value)).replacingOccurrences(of: "\n\n", with: " ")
    }
}
