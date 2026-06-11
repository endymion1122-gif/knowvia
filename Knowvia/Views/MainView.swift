import SwiftUI

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var appState = AppState()
    @AppStorage(ResearchParticipationPreferences.statusKey)
    private var participationStatusRaw = ResearchParticipationStatus.undecided.rawValue
    @AppStorage(ResearchParticipationPreferences.introSeenKey)
    private var hasSeenResearchIntro = false
    @State private var demoExperienceErrorMessage: String?
    private let demoExperienceService = DemoExperienceService()

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 260)
        } content: {
            WorkspaceView()
                .navigationSplitViewColumnWidth(min: 620, ideal: 820)
        } detail: {
            InspectorView()
                .navigationSplitViewColumnWidth(min: 270, ideal: 310, max: 360)
        }
        .environmentObject(appState)
        .navigationSplitViewStyle(.balanced)
        .background(AppTheme.pageBackground)
        .sheet(isPresented: researchIntroBinding) {
            ResearchConsentView(
                participationStatusRaw: $participationStatusRaw,
                requiresDecision: true,
                allowsDeferral: true,
                onAcknowledged: {
                    hasSeenResearchIntro = true
                }
            )
        }
        .task {
            installDemoExperienceIfNeeded()
        }
        .alert("无法载入示例体验", isPresented: demoExperienceErrorBinding) {
            Button("知道了") {
                demoExperienceErrorMessage = nil
            }
        } message: {
            Text(demoExperienceErrorMessage ?? "")
        }
    }

    private var researchIntroBinding: Binding<Bool> {
        Binding(
            get: {
                !hasSeenResearchIntro
                    && participationStatusRaw == ResearchParticipationStatus.undecided.rawValue
            },
            set: { isPresented in
                if !isPresented {
                    hasSeenResearchIntro = true
                }
            }
        )
    }

    private var demoExperienceErrorBinding: Binding<Bool> {
        Binding(
            get: { demoExperienceErrorMessage != nil },
            set: { if !$0 { demoExperienceErrorMessage = nil } }
        )
    }

    private func installDemoExperienceIfNeeded() {
        do {
            _ = try demoExperienceService.installIfNeeded(into: modelContext)
        } catch {
            demoExperienceErrorMessage = error.localizedDescription
        }
    }
}

private struct WorkspaceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let document = appState.activeDocument {
                if document.isPDF {
                    ReaderView(
                        document: document,
                        initialPageNumber: appState.requestedPDFPageNumber
                    )
                } else {
                    TextPreviewView(document: document)
                }
            } else {
                switch appState.selection {
                case .dashboard:
                    DashboardView()
                case .recent:
                    LibraryView(recentOnly: true)
                case .library:
                    LibraryView()
                case .pathways:
                    KnowledgePathwaysView()
                case .cards:
                    KnowledgeCardsView()
                case .learningPath:
                    LearningPathWorkspaceView()
                case .settings:
                    SettingsView()
                case .graph, .writing:
                    ComingSoonView(destination: appState.selection)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.pageBackground)
    }
}

#Preview {
    MainView()
        .modelContainer(for: [DocumentItem.self, KnowledgeCard.self, DocumentAnnotation.self, KnowledgePathway.self, KnowledgeRelation.self], inMemory: true)
}
