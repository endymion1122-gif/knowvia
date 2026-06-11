import Foundation

enum PromptTemplates {
    static let maximumDocumentCharacters = 12_000
    static let maximumSelectionCharacters = 4_000

    struct PreparedPrompt {
        let content: String
        let wasTruncated: Bool
    }

    static func documentSpeedRead(_ documentText: String) -> PreparedPrompt {
        let trimmedText = documentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasTruncated = trimmedText.count > maximumDocumentCharacters
        let includedText = String(trimmedText.prefix(maximumDocumentCharacters))

        return PreparedPrompt(
            content: """
            你是一个学术阅读助手。请对以下文档内容进行结构化速读，但不要编造文档中没有的信息。

            请按以下格式输出：

            1. 核心主题
            2. 关键概念
            3. 主要观点
            4. 重要证据
            5. 可转化为知识卡片的内容
            6. 可能用于写作的引用点
            7. 用户需要继续追问的问题

            要求：
            - 使用中文输出；
            - 保持简洁；
            - 如果原文信息不足，请明确说明“原文未提供”；
            - 不要替用户直接写完整论文；
            - 尽量保留原文术语。

            文档内容如下：
            \(includedText)
            """,
            wasTruncated: wasTruncated
        )
    }

    static func conceptExplanation(_ selectedText: String) -> PreparedPrompt {
        let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasTruncated = trimmedText.count > maximumSelectionCharacters
        let includedText = String(trimmedText.prefix(maximumSelectionCharacters))

        return PreparedPrompt(
            content: """
            请解释以下文本中的核心概念，并帮助学习者理解它在当前材料中的作用。

            请按以下格式输出：

            1. 概念定义
            2. 在当前材料中的含义
            3. 与其他概念的关系
            4. 可以如何整理为知识卡片
            5. 需要继续核验或追问的地方

            要求：
            - 使用中文输出；
            - 保持简洁；
            - 不要编造选区中没有的信息；
            - 如果上下文不足，请明确说明“需要结合原文继续核验”；
            - 尽量保留原文术语。

            选中文本如下：
            \(includedText)
            """,
            wasTruncated: wasTruncated
        )
    }

    static func selectionKnowledgeCard(_ selectedText: String) -> PreparedPrompt {
        let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasTruncated = trimmedText.count > maximumSelectionCharacters
        let includedText = String(trimmedText.prefix(maximumSelectionCharacters))

        return PreparedPrompt(
            content: """
            请将以下选中的术语、句子或段落整理成一张简洁的知识卡片正文。

            要求：
            - 使用中文输出；
            - 先用 1 到 3 句话归纳选区的核心含义；
            - 如果是术语，解释它的定义与作用；
            - 如果是观点，说明判断内容与适用范围；
            - 如果是问题，指出可以继续寻找什么答案；
            - 不要编造选区中没有的信息；
            - 上下文不足时明确写出“需要结合原文继续核验”；
            - 不要重复粘贴整段原文。

            选中文本如下：
            \(includedText)
            """,
            wasTruncated: wasTruncated
        )
    }

    static func annotationKnowledgeCard(
        selectedText: String,
        note: String
    ) -> PreparedPrompt {
        let combinedText = """
        用户批注：
        \(note.trimmingCharacters(in: .whitespacesAndNewlines))

        原文选区：
        \(selectedText.trimmingCharacters(in: .whitespacesAndNewlines))
        """
        let wasTruncated = combinedText.count > maximumSelectionCharacters
        let includedText = String(combinedText.prefix(maximumSelectionCharacters))

        return PreparedPrompt(
            content: """
            请根据用户的阅读批注和对应原文，整理一张简洁的知识卡片正文。

            要求：
            - 使用中文输出；
            - 用 1 到 3 句话归纳批注中值得沉淀的知识；
            - 保留用户已经形成的判断，但不要擅自扩大结论；
            - 如果原文和批注不足以支持结论，明确写出“需要结合原文继续核验”；
            - 不要重复粘贴整段原文；
            - 不要输出标题、标签或 Markdown 元数据。

            阅读上下文如下：
            \(includedText)
            """,
            wasTruncated: wasTruncated
        )
    }

    static func connectionTest() -> String {
        "请只回复：连接成功"
    }
}
