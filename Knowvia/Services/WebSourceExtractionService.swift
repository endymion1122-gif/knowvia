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

        let title = extractTitle(from: normalizedContent)
        let author = extractAuthor(from: normalizedContent)
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

    // MARK: - Metadata Extraction

    private func extractTitle(from content: String) -> String {
        // Try JSON-LD first (most reliable)
        if let jsonLDTitle = extractJSONLDField(content, field: "headline")
            ?? extractJSONLDField(content, field: "name") {
            return jsonLDTitle
        }

        // Try meta tags
        return firstMatch(
            in: content,
            patterns: [
                #"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#,
                #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']"#,
                #"<meta[^>]+name=["']twitter:title["'][^>]+content=["']([^"']+)["']"#,
                #"<title[^>]*>(.*?)</title>"#,
                #"<h1[^>]*>(.*?)</h1>"#,
            ]
        )
    }

    private func extractAuthor(from content: String) -> String {
        // Try JSON-LD first
        if let jsonLDAuthor = extractJSONLDAuthor(content) {
            return jsonLDAuthor
        }

        return firstMatch(
            in: content,
            patterns: [
                #"<meta[^>]+name=["']author["'][^>]+content=["']([^"']+)["']"#,
                #"<meta[^>]+property=["']article:author["'][^>]+content=["']([^"']+)["']"#,
                #"<meta[^>]+content=["']([^"']+)["'][^>]+name=["']author["']"#,
                #"<meta[^>]+name=["']dc.creator["'][^>]+content=["']([^"']+)["']"#,
                #"<a[^>]+rel=["']author["'][^>]*>([^<]+)</a>"#,
                #"作者[:：]\s*([^\n\r<]+)"#,
                #"Author[:：]\s*([^\n\r<]+)"#,
            ]
        )
    }

    /// Extract publication year, preferring structured metadata over plain text matching.
    private func extractYear(from content: String) -> Int? {
        // Try article:published_time
        let datePatterns = [
            #"<meta[^>]+property=["']article:published_time["'][^>]+content=["'](\d{4})-\d{2}-\d{2}"#,
            #"<meta[^>]+name=["']date["'][^>]+content=["'](\d{4})-\d{2}-\d{2}"#,
            #"<meta[^>]+name=["']dc.date["'][^>]+content=["'](\d{4})-\d{2}-\d{2}"#,
        ]
        for pattern in datePatterns {
            if let yearStr = regexMatch(in: content, pattern: pattern),
               let year = Int(yearStr) {
                return year
            }
        }

        // Try JSON-LD datePublished
        if let dateStr = extractJSONLDField(content, field: "datePublished")
            ?? extractJSONLDField(content, field: "dateCreated"),
           let year = extractYearFromDateString(dateStr) {
            return year
        }

        // Fallback: find any 4-digit year in 1900-2099 range
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

    private func extractYearFromDateString(_ date: String) -> Int? {
        // Supports formats: "2024-03-15", "2024-03-15T10:30:00Z", "2024"
        let cleaned = date.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count >= 4, let year = Int(cleaned.prefix(4)) {
            return year
        }
        return nil
    }

    // MARK: - JSON-LD Extraction

    /// Extract a simple field from inline JSON-LD blocks.
    private func extractJSONLDField(_ content: String, field: String) -> String? {
        // Match JSON-LD script blocks
        guard let regex = try? NSRegularExpression(
            pattern: #"<script[^>]+type=["']application/ld\+json["'][^>]*>(.*?)</script>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, range: range)

        for match in matches {
            guard match.numberOfRanges > 1,
                  let jsonRange = Range(match.range(at: 1), in: content) else {
                continue
            }
            let json = String(content[jsonRange])

            // Simple key-value extraction for common patterns
            let fieldPattern = #""\#(field)"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)""#
            if let fieldRegex = try? NSRegularExpression(pattern: fieldPattern),
               let fieldMatch = fieldRegex.firstMatch(in: json, range: NSRange(json.startIndex..<json.endIndex, in: json)),
               fieldMatch.numberOfRanges > 1,
               let valueRange = Range(fieldMatch.range(at: 1), in: json) {
                return String(json[valueRange])
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\n", with: "\n")
            }
        }
        return nil
    }

    /// Extract author from JSON-LD, handling both string and array/object formats.
    private func extractJSONLDAuthor(_ content: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"<script[^>]+type=["']application/ld\+json["'][^>]*>(.*?)</script>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, range: range)

        for match in matches {
            guard match.numberOfRanges > 1,
                  let jsonRange = Range(match.range(at: 1), in: content) else {
                continue
            }
            let json = String(content[jsonRange])

            // Try "author": "Name"
            let simplePattern = #""author"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)""#
            if let authorRegex = try? NSRegularExpression(pattern: simplePattern),
               let authorMatch = authorRegex.firstMatch(in: json, range: NSRange(json.startIndex..<json.endIndex, in: json)),
               authorMatch.numberOfRanges > 1,
               let valueRange = Range(authorMatch.range(at: 1), in: json) {
                return String(json[valueRange])
            }

            // Try "author": { "@type": "Person", "name": "Name" }
            let nestedPattern = #""author"\s*:\s*\{[^}]*"name"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)""#
            if let nestedRegex = try? NSRegularExpression(pattern: nestedPattern),
               let nestedMatch = nestedRegex.firstMatch(in: json, range: NSRange(json.startIndex..<json.endIndex, in: json)),
               nestedMatch.numberOfRanges > 1,
               let valueRange = Range(nestedMatch.range(at: 1), in: json) {
                return String(json[valueRange])
            }
        }
        return nil
    }

    // MARK: - Helpers

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
