import Foundation

enum AnnotationMarkdownExportError: LocalizedError, Equatable {
    case noAnnotations
    case cannotWriteFile

    var errorDescription: String? {
        switch self {
        case .noAnnotations:
            "当前没有可导出的批注。"
        case .cannotWriteFile:
            "无法写入 Markdown 文件，请检查保存位置后重试。"
        }
    }
}

struct AnnotationMarkdownExportService {
    func markdown(
        for annotations: [DocumentAnnotation],
        exportedAt: Date = Date()
    ) throws -> String {
        guard !annotations.isEmpty else {
            throw AnnotationMarkdownExportError.noAnnotations
        }

        let sortedAnnotations = annotations.sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.note.localizedCompare($1.note) == .orderedAscending
            }
            return $0.updatedAt > $1.updatedAt
        }

        var sections = [
            "# 知径 Knowvia 阅读批注",
            "",
            "> 导出自知径 Knowvia · 让知识成为路径。",
            "",
            "- 导出时间：\(timestamp(for: exportedAt))",
            "- 批注数量：\(sortedAnnotations.count)",
        ]

        for annotation in sortedAnnotations {
            sections.append(contentsOf: [
                "",
                "---",
                "",
                "## \(singleLine(annotation.note))",
                "",
                "- 来源：\(singleLine(annotation.sourceDescription))",
                "- 更新时间：\(dateString(for: annotation.updatedAt))",
                "",
                "> \(quoted(annotation.selectedText))",
            ])
        }

        return sections.joined(separator: "\n") + "\n"
    }

    func export(
        annotations: [DocumentAnnotation],
        to url: URL,
        exportedAt: Date = Date()
    ) throws {
        let content = try markdown(for: annotations, exportedAt: exportedAt)

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw AnnotationMarkdownExportError.cannotWriteFile
        }
    }

    private func singleLine(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func quoted(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .joined(separator: "\n> ")
    }

    private func timestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func dateString(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
