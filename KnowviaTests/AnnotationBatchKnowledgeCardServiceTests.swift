import XCTest
@testable import Knowvia

final class AnnotationBatchKnowledgeCardServiceTests: XCTestCase {
    private let service = AnnotationBatchKnowledgeCardService()

    func testBuildsThreeEditableDraftsWithSharedTopic() throws {
        let bundle = try service.bundle(
            documentTitle: "学习材料",
            annotations: [
                TestFactories.makeDocumentAnnotation(
                    documentTitle: "学习材料",
                    selectedText: "反馈循环",
                    note: "反馈循环需要连接行动结果。",
                    pageNumber: 3
                ),
                TestFactories.makeDocumentAnnotation(
                    documentTitle: "学习材料",
                    selectedText: "反馈循环",
                    note: "反馈循环支持下一轮调整。",
                    pageNumber: 5
                ),
            ]
        )

        XCTAssertEqual(bundle.topic, "反馈循环")
        XCTAssertEqual(bundle.annotationCount, 2)
        XCTAssertEqual(bundle.drafts.map(\.kind), [.concept, .argument, .evidence])
        XCTAssertTrue(bundle.drafts.allSatisfy { $0.tags.contains("反馈循环") })
        XCTAssertTrue(bundle.drafts.allSatisfy { $0.tags.contains("批注批量整理") })
        XCTAssertTrue(bundle.drafts.last?.content.contains("学习材料，p.5") == true)
    }

    func testFallsBackToFirstShortSelectionAsTopic() throws {
        let bundle = try service.bundle(
            documentTitle: "阅读材料",
            annotations: [
                TestFactories.makeDocumentAnnotation(
                    documentTitle: "阅读材料",
                    selectedText: "迁移学习",
                    note: "值得继续追踪。"
                ),
                TestFactories.makeDocumentAnnotation(
                    documentTitle: "阅读材料",
                    selectedText: "证据链",
                    note: "可以补充来源。"
                ),
            ]
        )

        XCTAssertEqual(bundle.topic, "迁移学习")
    }

    func testRejectsSingleAnnotation() {
        XCTAssertThrowsError(
            try service.bundle(
                documentTitle: "学习材料",
                annotations: [
                    TestFactories.makeDocumentAnnotation(
                        documentTitle: "学习材料",
                        selectedText: "反馈循环",
                        note: "继续追踪。"
                    ),
                ]
            )
        ) { error in
            XCTAssertEqual(error as? AnnotationBatchKnowledgeCardError, .notEnoughAnnotations)
        }
    }
}
