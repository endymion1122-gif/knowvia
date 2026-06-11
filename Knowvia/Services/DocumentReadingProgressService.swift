import Foundation

enum DocumentReadingStatus: String {
    case unread
    case reading
    case completed

    var title: String {
        switch self {
        case .unread: "未开始"
        case .reading: "阅读中"
        case .completed: "已完成"
        }
    }
}

struct DocumentReadingProgressService {
    func markOpened(_ document: DocumentItem, at date: Date = Date()) {
        document.lastOpenedAt = date
        if document.readingState == .unread {
            document.readingStatus = DocumentReadingStatus.reading.rawValue
        }
        document.updatedAt = date
    }

    func updatePDFProgress(
        _ document: DocumentItem,
        pageNumber: Int,
        at date: Date = Date()
    ) {
        guard document.isPDF, pageNumber > 0 else {
            return
        }
        document.lastReadPageNumber = pageNumber
        if document.readingState == .unread {
            document.readingStatus = DocumentReadingStatus.reading.rawValue
        }
        document.updatedAt = date
    }

    func toggleCompleted(_ document: DocumentItem, at date: Date = Date()) {
        document.readingStatus = document.readingState == .completed
            ? DocumentReadingStatus.reading.rawValue
            : DocumentReadingStatus.completed.rawValue
        document.updatedAt = date
    }

    func resumePageNumber(for document: DocumentItem) -> Int? {
        guard document.isPDF, let pageNumber = document.lastReadPageNumber, pageNumber > 0 else {
            return nil
        }
        return pageNumber
    }

    func recentDocuments(in documents: [DocumentItem]) -> [DocumentItem] {
        documents
            .filter { $0.lastOpenedAt != nil }
            .sorted {
                ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast)
            }
    }
}
