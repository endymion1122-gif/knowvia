import Foundation
import PDFKit
import UniformTypeIdentifiers

enum FileImportError: LocalizedError {
    case missingSource
    case unsupportedFileType(String)
    case cannotCreateLibrary
    case cannotDeleteImportedCopy

    var errorDescription: String? {
        switch self {
        case .missingSource:
            "找不到所选文件，请确认文件仍然存在。"
        case .unsupportedFileType(let fileType):
            "暂不支持 \(fileType.uppercased()) 文件。当前 Demo 支持 PDF、TXT 和 Markdown。"
        case .cannotCreateLibrary:
            "无法创建本地资料库目录。"
        case .cannotDeleteImportedCopy:
            "无法删除本地资料副本。请确认文件仍位于知径资料库中。"
        }
    }
}

final class FileImportService {
    static let shared = FileImportService()

    private let fileManager: FileManager
    private let customLibraryRootURL: URL?

    init(fileManager: FileManager = .default, libraryRootURL: URL? = nil) {
        self.fileManager = fileManager
        self.customLibraryRootURL = libraryRootURL
    }

    var allowedContentTypes: [UTType] {
        var types: [UTType] = [.pdf, .plainText]
        if let markdown = UTType(filenameExtension: "md") {
            types.append(markdown)
        }
        if let markdownLong = UTType(filenameExtension: "markdown") {
            types.append(markdownLong)
        }
        return types
    }

    func importDocument(from sourceURL: URL) throws -> DocumentItem {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw FileImportError.missingSource
        }

        let fileType = sourceURL.pathExtension.lowercased()
        guard ["pdf", "txt", "md", "markdown"].contains(fileType) else {
            throw FileImportError.unsupportedFileType(fileType.isEmpty ? "未知" : fileType)
        }

        let hasSecurityAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let identifier = UUID()
        let destinationFolder = try createLibraryDirectory()
            .appendingPathComponent(identifier.uuidString, isDirectory: true)
        try fileManager.createDirectory(
            at: destinationFolder,
            withIntermediateDirectories: true
        )

        let destinationURL = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let normalizedType = fileType == "markdown" ? "md" : fileType
        let title = sourceURL.deletingPathExtension().lastPathComponent
        let pageCount = normalizedType == "pdf" ? PDFDocument(url: destinationURL)?.pageCount : nil
        let extractedText = normalizedType == "pdf"
            ? nil
            : try? String(contentsOf: destinationURL, encoding: .utf8)

        return DocumentItem(
            id: identifier,
            title: title,
            filePath: destinationURL.path,
            fileType: normalizedType,
            pageCount: pageCount,
            extractedText: extractedText
        )
    }

    func libraryDirectory() throws -> URL {
        try createLibraryDirectory()
    }

    func deleteImportedCopy(for document: DocumentItem) throws {
        let libraryURL = try createLibraryDirectory().standardizedFileURL
        let documentFolderURL = document.fileURL
            .deletingLastPathComponent()
            .standardizedFileURL

        guard documentFolderURL.deletingLastPathComponent() == libraryURL else {
            throw FileImportError.cannotDeleteImportedCopy
        }

        do {
            if fileManager.fileExists(atPath: documentFolderURL.path) {
                try fileManager.removeItem(at: documentFolderURL)
            }
        } catch {
            throw FileImportError.cannotDeleteImportedCopy
        }
    }

    private func createLibraryDirectory() throws -> URL {
        let rootURL: URL
        if let customLibraryRootURL {
            rootURL = customLibraryRootURL
        } else {
            guard let applicationSupportURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw FileImportError.cannotCreateLibrary
            }
            rootURL = applicationSupportURL.appendingPathComponent("KnowviaLibrary", isDirectory: true)
        }

        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            return rootURL
        } catch {
            throw FileImportError.cannotCreateLibrary
        }
    }
}
