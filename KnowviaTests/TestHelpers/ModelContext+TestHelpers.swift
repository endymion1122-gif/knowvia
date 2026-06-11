import Foundation
import SwiftData
import XCTest
@testable import Knowvia

/// Shared helpers for creating in-memory SwiftData containers in tests.

enum TestModelContext {

    /// Creates an in-memory ModelContainer with all Knowvia models registered.
    /// Use this for persistence tests that need the full schema.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            DocumentItem.self,
            KnowledgeCard.self,
            DocumentAnnotation.self,
            KnowledgePathway.self,
            KnowledgeRelation.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Creates an in-memory ModelContainer for a single model type.
    /// Use this when testing a single model in isolation.
    static func makeInMemoryContainer(for model: any PersistentModel.Type) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: model, configurations: configuration)
    }
}
