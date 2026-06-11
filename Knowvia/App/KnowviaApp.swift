import SwiftData
import SwiftUI

@main
struct KnowviaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DocumentItem.self,
            KnowledgeCard.self,
            DocumentAnnotation.self,
            KnowledgePathway.self,
            KnowledgeRelation.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1180, minHeight: 760)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1380, height: 880)
    }
}
