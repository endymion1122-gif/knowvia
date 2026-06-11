import Foundation
import SwiftData

enum DemoExperienceError: LocalizedError {
    case cannotPrepareSample

    var errorDescription: String? {
        switch self {
        case .cannotPrepareSample:
            "无法准备示例体验，请检查本地资料库目录后重试。"
        }
    }
}

struct DemoExperienceInstallResult {
    let document: DocumentItem
    let addedCardCount: Int
    let restoredDocument: Bool
}

@MainActor
struct DemoExperienceService {
    static let installedKey = "knowvia.demoExperience.installed"
    static let sampleDocumentID = UUID(uuidString: "19B0F102-521D-4F8D-91B7-A68AC8B135C0")!

    private let fileManager: FileManager
    private let importService: FileImportService
    private let defaults: UserDefaults

    init(
        fileManager: FileManager = .default,
        importService: FileImportService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.importService = importService
        self.defaults = defaults
    }

    func installIfNeeded(into modelContext: ModelContext) throws -> DemoExperienceInstallResult? {
        guard !defaults.bool(forKey: Self.installedKey) else {
            return nil
        }

        let documents = try modelContext.fetch(FetchDescriptor<DocumentItem>())
        let cards = try modelContext.fetch(FetchDescriptor<KnowledgeCard>())
        guard documents.isEmpty, cards.isEmpty else {
            defaults.set(true, forKey: Self.installedKey)
            return nil
        }
        return try installOrRestore(into: modelContext)
    }

    func installOrRestore(into modelContext: ModelContext) throws -> DemoExperienceInstallResult {
        let documents = try modelContext.fetch(FetchDescriptor<DocumentItem>())
        let cards = try modelContext.fetch(FetchDescriptor<KnowledgeCard>())
        let sampleURL = try prepareSampleDocument()

        let document: DocumentItem
        let restoredDocument: Bool
        if let existingDocument = documents.first(where: { $0.id == Self.sampleDocumentID }) {
            existingDocument.filePath = sampleURL.path
            existingDocument.extractedText = Self.sampleMarkdown
            document = existingDocument
            restoredDocument = false
        } else {
            document = DocumentItem(
                id: Self.sampleDocumentID,
                title: "示例：如何把阅读转化为可执行的学习路径",
                filePath: sampleURL.path,
                fileType: "md",
                tags: ["示例体验", "学习方法"],
                readingStatus: DocumentReadingStatus.reading.rawValue,
                lastOpenedAt: Date(),
                extractedText: Self.sampleMarkdown,
                summary: Self.sampleSummary
            )
            modelContext.insert(document)
            restoredDocument = true
        }

        var addedCardCount = 0
        let existingCardIDs = Set(cards.map(\.id))
        for card in sampleCards(for: document) where !existingCardIDs.contains(card.id) {
            modelContext.insert(card)
            addedCardCount += 1
        }

        try modelContext.save()
        defaults.set(true, forKey: Self.installedKey)
        return DemoExperienceInstallResult(
            document: document,
            addedCardCount: addedCardCount,
            restoredDocument: restoredDocument
        )
    }

    private func prepareSampleDocument() throws -> URL {
        do {
            let folderURL = try importService.libraryDirectory()
                .appendingPathComponent(Self.sampleDocumentID.uuidString, isDirectory: true)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let fileURL = folderURL.appendingPathComponent("知径示例阅读.md")
            try Self.sampleMarkdown.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            throw DemoExperienceError.cannotPrepareSample
        }
    }

    private func sampleCards(for document: DocumentItem) -> [KnowledgeCard] {
        [
            KnowledgeCard(
                id: UUID(uuidString: "7776C915-744E-4A0D-BD8A-67976448A2AA")!,
                title: "知识卡片不是摘抄仓库",
                content: "知识卡片的价值不只是保存句子，而是把材料转化为之后仍可理解、核验和复用的知识单元。",
                cardType: KnowledgeCardKind.concept.rawValue,
                tags: ["示例体验", "学习方法"],
                sourceDocumentId: document.id,
                sourceDocumentTitle: document.title,
                createdBy: "demo-experience"
            ),
            KnowledgeCard(
                id: UUID(uuidString: "BBE2419E-4DCA-4BCD-AF1E-26C667056C33")!,
                title: "阅读闭环需要明确的下一步",
                content: "当阅读结果能够连接到复习、写作或行动任务时，知识才真正开始形成路径。",
                cardType: KnowledgeCardKind.argument.rawValue,
                tags: ["示例体验", "学习方法"],
                sourceDocumentId: document.id,
                sourceDocumentTitle: document.title,
                createdBy: "demo-experience"
            ),
            KnowledgeCard(
                id: UUID(uuidString: "A3F31037-635A-4E8D-8914-F0906987A71D")!,
                title: "三类卡片形成最小知识结构",
                content: "概念卡回答“它是什么”，观点卡回答“作者主张什么”，证据卡回答“依据在哪里”。",
                cardType: KnowledgeCardKind.evidence.rawValue,
                tags: ["示例体验", "学习方法"],
                sourceDocumentId: document.id,
                sourceDocumentTitle: document.title,
                createdBy: "demo-experience"
            ),
        ]
    }

    private static let sampleSummary = """
    [示例体验]
    这份材料演示如何把阅读从一次性输入变成可复用的知识路径：先阅读和理解，再整理概念、观点与证据，最后把下一步导出为复习或行动任务。
    """

    private static let sampleMarkdown = """
    # 如何把阅读转化为可执行的学习路径

    阅读的目标不只是完成一篇材料，而是留下之后仍然可以理解、核验和复用的知识资产。

    ## 1. 从摘要开始，但不要停在摘要

    摘要帮助我们快速建立方向感。真正需要沉淀的内容，可以继续拆成三类知识卡片：

    - 概念卡：回答“它是什么”。
    - 观点卡：回答“作者主张什么”。
    - 证据卡：回答“依据在哪里”。

    ## 2. 让卡片可以重新回到原文

    卡片不是孤立的摘抄仓库。保留材料来源，才能在复习和写作时重新核验上下文。

    ## 3. 把知识连接到行动

    当一组卡片能够变成复习计划、写作任务或下一次阅读目标时，知识才真正开始形成路径。

    你可以在这份示例材料中选择一段文本，体验摘录制卡、AI 解释和学习路径整理。
    """
}
