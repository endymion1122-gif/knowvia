import AppKit
import SwiftData
import UniformTypeIdentifiers

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var importedDocumentCount = 0

    private let importService: FileImportService
    private var droppedFileModelContext: ModelContext?

    init(importService: FileImportService = .shared) {
        self.importService = importService
    }

    func chooseAndImportDocuments(into modelContext: ModelContext) {
        let panel = NSOpenPanel()
        panel.title = "导入到知径 Knowvia 资料库"
        panel.message = "选择 PDF、TXT 或 Markdown 文件。知径 Knowvia 会在本机保存一份资料副本。"
        panel.prompt = "导入资料"
        panel.allowedContentTypes = importService.allowedContentTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else {
            return
        }

        importDocuments(from: panel.urls, into: modelContext)
    }

    func importDocuments(from urls: [URL], into modelContext: ModelContext) {
        var successfulImports = 0
        var failures: [String] = []

        for url in urls {
            do {
                let document = try importService.importDocument(from: url)
                modelContext.insert(document)
                successfulImports += 1
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        do {
            try modelContext.save()
        } catch {
            failures.append("无法保存资料库记录：\(error.localizedDescription)")
        }

        importedDocumentCount += successfulImports
        errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

    func importDroppedProviders(_ providers: [NSItemProvider], into modelContext: ModelContext) -> Bool {
        droppedFileModelContext = modelContext
        let supportedProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }

        guard !supportedProviders.isEmpty else {
            return false
        }

        for provider in supportedProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }

                guard let url else {
                    return
                }

                Task { @MainActor [weak self] in
                    self?.importDroppedFile(from: url)
                }
            }
        }

        return true
    }

    private func importDroppedFile(from url: URL) {
        guard let droppedFileModelContext else {
            return
        }

        importDocuments(from: [url], into: droppedFileModelContext)
    }
}
