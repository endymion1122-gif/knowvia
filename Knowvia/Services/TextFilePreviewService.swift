import Foundation

struct TextFilePreviewService {
    func loadText(from url: URL) -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            return "无法读取该文本文件。请确认文件使用 UTF-8 编码。"
        }
    }
}
