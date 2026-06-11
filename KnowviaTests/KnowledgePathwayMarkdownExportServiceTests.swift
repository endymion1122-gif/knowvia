import XCTest
@testable import Knowvia

final class KnowledgePathwayMarkdownExportServiceTests: XCTestCase {
    private let service = KnowledgePathwayMarkdownExportService()

    func testExportsPathwayReportWithSourcesMatrixRelationsAndQuestions() throws {
        let document = DocumentItem(
            title: "Learning Notes",
            filePath: "/tmp/learning-notes.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.webPage.rawValue,
            author: "Learning Lab",
            publicationYear: 2026,
            sourceURLString: "https://example.com/learning",
            credibilityLevel: SourceCredibilityLevel.authoritative.rawValue,
            contributionNote: "说明反馈机制如何支持学习闭环。"
        )
        let claim = KnowledgeCard(
            title: "反馈帮助形成学习闭环",
            content: "及时反馈能够支持学习者校准理解。",
            cardType: KnowledgeCardKind.argument.rawValue,
            sourceDocumentId: document.id,
            sourceDocumentTitle: document.title
        )
        let evidence = KnowledgeCard(
            title: "原文中的反馈机制",
            content: "学习者根据反馈调整下一步行动。",
            cardType: KnowledgeCardKind.evidence.rawValue,
            sourceDocumentId: document.id,
            sourceDocumentTitle: document.title,
            pageNumber: 3
        )
        let question = KnowledgeCard(
            title: "反馈频率如何设置？",
            content: "需要继续核验不同任务中的反馈节奏。",
            cardType: KnowledgeCardKind.question.rawValue
        )
        let pathway = KnowledgePathway(
            title: "学习反馈闭环",
            overview: "整理反馈如何支持理解、校准与行动。",
            tags: ["学习科学"],
            sourceDocumentIDs: [document.id],
            knowledgeCardIDs: [claim.id, evidence.id, question.id]
        )
        let relation = KnowledgeRelation(
            pathwayID: pathway.id,
            sourceCardID: evidence.id,
            targetCardID: claim.id,
            relationType: KnowledgeRelationKind.supports.rawValue,
            note: "原文证据支持该观点"
        )
        let candidate = DocumentItem(
            title: "Further Reading",
            filePath: "/tmp/further-reading.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.externalEnrichment.rawValue,
            sourceURLString: "https://example.com/further-reading",
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )
        pathway.candidateDocumentIDs = [candidate.id]

        let markdown = try service.markdown(
            for: pathway,
            documents: [document, candidate],
            cards: [claim, evidence, question],
            relations: [relation],
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertTrue(markdown.contains("# 学习反馈闭环"))
        XCTAssertTrue(markdown.contains("## 来源列表"))
        XCTAssertTrue(markdown.contains("- Learning Notes（网页资料 / MD｜权威来源｜Learning Lab · 2026｜https://example.com/learning）"))
        XCTAssertTrue(markdown.contains("## 来源质量概览"))
        XCTAssertTrue(markdown.contains("- 元数据完整：1 / 1（100%）"))
        XCTAssertTrue(markdown.contains("- 已核验来源：1 / 1（100%）"))
        XCTAssertTrue(markdown.contains("- 权威来源：1"))
        XCTAssertTrue(markdown.contains("## 文献 / 资料贡献矩阵"))
        XCTAssertTrue(markdown.contains("## 外部补全候选"))
        XCTAssertTrue(markdown.contains("- [ ] Further Reading（待核验｜https://example.com/further-reading）"))
        XCTAssertTrue(markdown.contains("处理建议：补全作者与年份"))
        XCTAssertTrue(markdown.contains("| 来源资料 | 类型 | 作者 / 年份 | 可信度 | 关联节点 | 主要贡献 |"))
        XCTAssertTrue(markdown.contains("| Learning Notes | 网页资料 | Learning Lab · 2026 | 权威来源 | 2 | 说明反馈机制如何支持学习闭环。 |"))
        XCTAssertTrue(markdown.contains("## 节点关系"))
        XCTAssertTrue(markdown.contains("原文中的反馈机制 → **支持** → 反馈帮助形成学习闭环"))
        XCTAssertTrue(markdown.contains("## 观点—证据链"))
        XCTAssertTrue(markdown.contains("**观点：** 反馈帮助形成学习闭环"))
        XCTAssertTrue(markdown.contains("## 写作准备度"))
        XCTAssertTrue(markdown.contains("[已准备] 观点有证据支撑"))
        XCTAssertTrue(markdown.contains("## 写作准备大纲"))
        XCTAssertTrue(markdown.contains("### 核心论点安排"))
        XCTAssertTrue(markdown.contains("- 反馈帮助形成学习闭环：支持证据：原文中的反馈机制"))
        XCTAssertTrue(markdown.contains("## 写作行动清单"))
        XCTAssertTrue(markdown.contains("[继续补强] 确认待核验或需跟进节点"))
        XCTAssertTrue(markdown.contains("[写前确认] 处理仍待补全的问题"))
        XCTAssertTrue(markdown.contains("相关对象：Further Reading"))
        XCTAssertTrue(markdown.contains("- [ ] 校准 3 个知识节点，确认 AI 草稿、重点节点和需要继续跟进的内容。"))
        XCTAssertTrue(markdown.contains("## 待补全问题"))
        XCTAssertTrue(markdown.contains("- [ ] 反馈频率如何设置？"))
    }

    func testExportsConcreteSourceQualityFollowUps() throws {
        let unverified = DocumentItem(
            title: "Unverified Web",
            filePath: "/tmp/unverified.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.webPage.rawValue,
            author: "Web Author",
            publicationYear: 2025,
            sourceURLString: "https://example.com/unverified",
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )
        let missingMetadata = DocumentItem(
            title: "Missing Metadata",
            filePath: "/tmp/missing.md",
            fileType: "md",
            credibilityLevel: SourceCredibilityLevel.userProvided.rawValue
        )
        let pathway = KnowledgePathway(
            title: "来源质量跟进",
            sourceDocumentIDs: [unverified.id, missingMetadata.id]
        )

        let markdown = try service.markdown(
            for: pathway,
            documents: [unverified, missingMetadata],
            cards: [],
            relations: []
        )

        XCTAssertTrue(markdown.contains("- 待核验来源：Unverified Web"))
        XCTAssertTrue(markdown.contains("- 元数据待补：Missing Metadata"))
    }

    func testRejectsEmptyPathway() {
        let pathway = KnowledgePathway(title: "空路径")

        XCTAssertThrowsError(
            try service.markdown(
                for: pathway,
                documents: [],
                cards: [],
                relations: []
            )
        ) { error in
            XCTAssertEqual(error as? KnowledgePathwayMarkdownExportError, .emptyPathway)
        }
    }

    func testWritesMarkdownFile() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destinationURL = temporaryDirectory.appendingPathComponent("pathway.md")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let card = KnowledgeCard(
            title: "知识路径",
            content: "让知识成为可追溯的路径。",
            cardType: KnowledgeCardKind.concept.rawValue
        )
        let pathway = KnowledgePathway(
            title: "知径",
            knowledgeCardIDs: [card.id]
        )

        try service.export(
            pathway: pathway,
            documents: [],
            cards: [card],
            relations: [],
            to: destinationURL
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertTrue(
            try String(contentsOf: destinationURL, encoding: .utf8)
                .contains("# 知径")
        )
    }
}
