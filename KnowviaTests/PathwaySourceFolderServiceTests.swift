import XCTest
@testable import Knowvia

final class PathwaySourceFolderServiceTests: XCTestCase {
    private let service = PathwaySourceFolderService()

    func testFiltersByQueryKindAndCredibility() {
        let authoritative = DocumentItem(
            title: "Attention Paper",
            filePath: "/tmp/attention.pdf",
            fileType: "pdf",
            author: "Vaswani",
            publicationYear: 2017,
            credibilityLevel: SourceCredibilityLevel.authoritative.rawValue
        )
        let web = DocumentItem(
            title: "Learning Notes",
            filePath: "/tmp/notes.md",
            fileType: "md",
            tags: ["feedback"],
            sourceKind: DocumentSourceKind.webPage.rawValue,
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue,
            contributionNote: "反馈机制案例"
        )

        XCTAssertEqual(
            service.filter([authoritative, web], query: "反馈").map(\.id),
            [web.id]
        )
        XCTAssertEqual(
            service.filter([authoritative, web], sourceKind: .webPage).map(\.id),
            [web.id]
        )
        XCTAssertEqual(
            service.filter([authoritative, web], credibility: .authoritative).map(\.id),
            [authoritative.id]
        )
    }

    func testFindsRelatedCardsForDocument() {
        let document = DocumentItem(
            title: "Learning Notes",
            filePath: "/tmp/notes.md",
            fileType: "md"
        )
        let related = KnowledgeCard(
            title: "反馈循环",
            content: "测试内容",
            cardType: KnowledgeCardKind.concept.rawValue,
            sourceDocumentId: document.id
        )
        let unrelated = KnowledgeCard(
            title: "认知负荷",
            content: "测试内容",
            cardType: KnowledgeCardKind.concept.rawValue
        )

        XCTAssertEqual(
            service.relatedCards(for: document, in: [unrelated, related]).map(\.id),
            [related.id]
        )
    }

    func testBuildsSourceQualityOverview() {
        let complete = DocumentItem(
            title: "Core Paper",
            filePath: "/tmp/core.pdf",
            fileType: "pdf",
            author: "Research Lab",
            publicationYear: 2024,
            credibilityLevel: SourceCredibilityLevel.authoritative.rawValue
        )
        let unverified = DocumentItem(
            title: "Web Notes",
            filePath: "/tmp/web.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.webPage.rawValue,
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )
        let candidate = DocumentItem(
            title: "Candidate",
            filePath: "/tmp/candidate.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.externalEnrichment.rawValue
        )

        let overview = service.qualityOverview(
            sources: [complete, unverified],
            candidates: [candidate]
        )

        XCTAssertEqual(overview.totalSources, 2)
        XCTAssertEqual(overview.authoritativeSources, 1)
        XCTAssertEqual(overview.unverifiedSources, 1)
        XCTAssertEqual(overview.completeMetadataSources, 1)
        XCTAssertEqual(overview.candidateSources, 1)
        XCTAssertEqual(overview.metadataCompletionRatio, 0.5)
        XCTAssertEqual(overview.verificationRatio, 0.5)
    }

    func testFiltersBySourceQualityIssues() {
        let authoritative = DocumentItem(
            title: "Core Paper",
            filePath: "/tmp/core.pdf",
            fileType: "pdf",
            author: "Research Lab",
            publicationYear: 2024,
            credibilityLevel: SourceCredibilityLevel.authoritative.rawValue
        )
        let missingMetadata = DocumentItem(
            title: "Untitled Notes",
            filePath: "/tmp/notes.md",
            fileType: "md",
            credibilityLevel: SourceCredibilityLevel.userProvided.rawValue
        )
        let unverified = DocumentItem(
            title: "Web Candidate",
            filePath: "/tmp/web.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.webPage.rawValue,
            author: "Author",
            publicationYear: 2025,
            sourceURLString: "https://example.com",
            credibilityLevel: SourceCredibilityLevel.needsVerification.rawValue
        )

        let documents = [authoritative, missingMetadata, unverified]

        XCTAssertEqual(
            service.filter(documents, quality: .authoritative).map(\.id),
            [authoritative.id]
        )
        XCTAssertEqual(
            service.filter(documents, quality: .missingMetadata).map(\.id),
            [missingMetadata.id]
        )
        XCTAssertEqual(
            service.filter(documents, quality: .needsVerification).map(\.id),
            [unverified.id]
        )
    }

    func testBuildsExternalCandidateAdvice() {
        let missingLink = DocumentItem(
            title: "Candidate",
            filePath: "/tmp/candidate.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.externalEnrichment.rawValue
        )
        XCTAssertEqual(
            service.candidateAdvice(for: missingLink).title,
            "先补链接或来源线索"
        )

        let missingMetadata = DocumentItem(
            title: "Candidate",
            filePath: "/tmp/candidate.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.externalEnrichment.rawValue,
            sourceURLString: "https://example.com"
        )
        XCTAssertEqual(
            service.candidateAdvice(for: missingMetadata).title,
            "补全作者与年份"
        )

        let missingReason = DocumentItem(
            title: "Candidate",
            filePath: "/tmp/candidate.md",
            fileType: "md",
            sourceKind: DocumentSourceKind.externalEnrichment.rawValue,
            author: "Research Lab",
            publicationYear: 2026,
            sourceURLString: "https://example.com"
        )
        XCTAssertEqual(
            service.candidateAdvice(for: missingReason).title,
            "记录纳入理由"
        )
    }
}
