import Foundation

enum WebSourceImportError: LocalizedError, Equatable {
    case missingTitle
    case invalidURL
    case missingExcerpt
    case cannotCreateLocalCopy

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            "请填写网页资料标题。"
        case .invalidURL:
            "请输入有效的 HTTP 或 HTTPS 网页链接。"
        case .missingExcerpt:
            "请粘贴需要保留的网页正文或摘要。"
        case .cannotCreateLocalCopy:
            "无法保存网页资料的本地 Markdown 副本。"
        }
    }
}

final class WebSourceImportService {
    private let fileManager: FileManager
    private let fileImportService: FileImportService

    init(
        fileManager: FileManager = .default,
        fileImportService: FileImportService = .shared
    ) {
        self.fileManager = fileManager
        self.fileImportService = fileImportService
    }

    func importWebSource(
        title: String,
        urlString: String,
        excerpt: String,
        author: String = "",
        publicationYear: Int? = nil,
        note: String = "",
        sourceKind: DocumentSourceKind = .webPage
    ) throws -> DocumentItem {
        let normalizedTitle = trimmed(title)
        guard !normalizedTitle.isEmpty else {
            throw WebSourceImportError.missingTitle
        }

        let normalizedURLString = trimmed(urlString)
        guard
            let url = URL(string: normalizedURLString),
            ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil
        else {
            throw WebSourceImportError.invalidURL
        }

        let normalizedExcerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedExcerpt.isEmpty else {
            throw WebSourceImportError.missingExcerpt
        }

        let identifier = UUID()
        let folder = try fileImportService.libraryDirectory()
            .appendingPathComponent(identifier.uuidString, isDirectory: true)
        let destinationURL = folder.appendingPathComponent("web-source.md")
        let markdown = """
        # \(normalizedTitle)

        - 来源链接：\(normalizedURLString)
        \(metadataLine(label: "作者", value: author))
        \(publicationYear.map { "- 年份：\($0)" } ?? "")

        ## 网页正文摘录

        \(normalizedExcerpt)
        """

        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try markdown.write(to: destinationURL, atomically: true, encoding: .utf8)
        } catch {
            throw WebSourceImportError.cannotCreateLocalCopy
        }

        return DocumentItem(
            id: identifier,
            title: normalizedTitle,
            filePath: destinationURL.path,
            fileType: "md",
            extractedText: markdown,
            sourceKind: sourceKind.rawValue,
            author: trimmed(author),
            publicationYear: publicationYear,
            sourceURLString: normalizedURLString,
            sourceNote: trimmed(note),
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func metadataLine(label: String, value: String) -> String {
        let value = trimmed(value)
        return value.isEmpty ? "" : "- \(label)：\(value)"
    }
}
