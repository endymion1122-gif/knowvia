import SwiftData
import XCTest
@testable import Knowvia

@MainActor
final class DocumentAnnotationPersistenceTests: XCTestCase {
    func testPersistsAnnotationAnchorAndNote() throws {
        let container = try TestModelContext.makeInMemoryContainer(for: DocumentAnnotation.self)
        let context = container.mainContext
        let documentId = UUID()
        let annotation = TestFactories.makeDocumentAnnotation(
            documentId: documentId,
            documentTitle: "Learning Notes",
            selectedText: "Feedback loops support adjustment.",
            note: "Connect this idea to deliberate practice.",
            page: 12
        )

        context.insert(annotation)
        try context.save()

        let annotations = try context.fetch(FetchDescriptor<DocumentAnnotation>())
        XCTAssertEqual(annotations.count, 1)
        XCTAssertEqual(annotations.first?.documentId, documentId)
        XCTAssertEqual(annotations.first?.selectedText, "Feedback loops support adjustment.")
        XCTAssertEqual(annotations.first?.note, "Connect this idea to deliberate practice.")
        XCTAssertEqual(annotations.first?.sourceDescription, "Learning Notes，p.12")
    }
}
