import Foundation
import SwiftData

enum DocumentSourceKind: String, CaseIterable, Identifiable {
    case uploadedFile
    case userNote
    case webPage
    case externalEnrichment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uploadedFile: "用户上传"
        case .userNote: "用户笔记"
        case .webPage: "网页资料"
        case .externalEnrichment: "外部补全"
        }
    }
}

enum SourceCredibilityLevel: String, CaseIterable, Identifiable {
    case unreviewed
    case userProvided
    case authoritative
    case needsVerification

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unreviewed: "未分级"
        case .userProvided: "用户提供"
        case .authoritative: "权威来源"
        case .needsVerification: "需核验"
        }
    }
}

@Model
final class DocumentItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var filePath: String
    var fileType: String
    var importedAt: Date
    var updatedAt: Date
    var tags: [String]
    var pathwayIDs: [UUID] = []
    var readingStatus: String
    var lastOpenedAt: Date?
    var lastReadPageNumber: Int?
    var pageCount: Int?
    var extractedText: String?
    var summary: String?
    var sourceKind: String = DocumentSourceKind.uploadedFile.rawValue
    var author: String = ""
    var publicationYear: Int?
    var sourceURLString: String = ""
    var sourceNote: String = ""
    var credibilityLevel: String = SourceCredibilityLevel.userProvided.rawValue
    var contributionNote: String = ""

    init(
        id: UUID = UUID(),
        title: String,
        filePath: String,
        fileType: String,
        importedAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        pathwayIDs: [UUID] = [],
        readingStatus: String = "unread",
        lastOpenedAt: Date? = nil,
        lastReadPageNumber: Int? = nil,
        pageCount: Int? = nil,
        extractedText: String? = nil,
        summary: String? = nil,
        sourceKind: String = DocumentSourceKind.uploadedFile.rawValue,
        author: String = "",
        publicationYear: Int? = nil,
        sourceURLString: String = "",
        sourceNote: String = "",
        credibilityLevel: String = SourceCredibilityLevel.userProvided.rawValue,
        contributionNote: String = ""
    ) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.fileType = fileType
        self.importedAt = importedAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.pathwayIDs = pathwayIDs
        self.readingStatus = readingStatus
        self.lastOpenedAt = lastOpenedAt
        self.lastReadPageNumber = lastReadPageNumber
        self.pageCount = pageCount
        self.extractedText = extractedText
        self.summary = summary
        self.sourceKind = sourceKind
        self.author = author
        self.publicationYear = publicationYear
        self.sourceURLString = sourceURLString
        self.sourceNote = sourceNote
        self.credibilityLevel = credibilityLevel
        self.contributionNote = contributionNote
    }

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var displayFileType: String {
        fileType.uppercased()
    }

    var isPDF: Bool {
        fileType.lowercased() == "pdf"
    }

    var readingState: DocumentReadingStatus {
        DocumentReadingStatus(rawValue: readingStatus) ?? .unread
    }

    var sourceType: DocumentSourceKind {
        DocumentSourceKind(rawValue: sourceKind) ?? .uploadedFile
    }

    var credibility: SourceCredibilityLevel {
        SourceCredibilityLevel(rawValue: credibilityLevel) ?? .unreviewed
    }

    var sourceURL: URL? {
        URL(string: sourceURLString)
    }

    var attributionDescription: String? {
        let parts = [
            author.trimmingCharacters(in: .whitespacesAndNewlines),
            publicationYear.map(String.init) ?? "",
        ]
        .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var readingProgressDescription: String {
        if let lastReadPageNumber, isPDF {
            return "\(readingState.title) · 上次第 \(lastReadPageNumber) 页"
        }
        return readingState.title
    }
}
