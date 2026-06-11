import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \DocumentItem.importedAt, order: .reverse) private var documents: [DocumentItem]
    @Query(sort: \KnowledgeCard.createdAt, order: .reverse) private var cards: [KnowledgeCard]
    @Query(sort: \KnowledgePathway.updatedAt, order: .reverse) private var pathways: [KnowledgePathway]
    @StateObject private var libraryViewModel = LibraryViewModel()
    @State private var sampleExperienceErrorMessage: String?
    @State private var inspectingCard: KnowledgeCard?
    @State private var cardSourceErrorMessage: String?
    private let readingProgressService = DocumentReadingProgressService()
    private let demoExperienceService = DemoExperienceService()
    private let sourceService = KnowledgeCardSourceService()

    private var importedThisWeek: Int {
        documents.filter {
            Calendar.current.isDate($0.importedAt, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

    private var recentlyOpenedDocuments: [DocumentItem] {
        readingProgressService.recentDocuments(in: documents)
    }

    private var dashboardDocuments: [DocumentItem] {
        documents.sorted {
            ($0.lastOpenedAt ?? $0.importedAt) > ($1.lastOpenedAt ?? $1.importedAt)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                stats
                positioningCard
                continueReading
                LearningPathView()
                recentDocuments
                recentCards
            }
            .padding(28)
        }
        .background(AppTheme.pageBackground)
        .sheet(item: $inspectingCard) { card in
            KnowledgeCardDetailView(
                card: card,
                onOpenSource: card.sourceDocumentId == nil ? nil : { openSource(for: card) }
            )
        }
        .alert("部分资料未能导入", isPresented: errorBinding) {
            Button("知道了") {
                libraryViewModel.errorMessage = nil
            }
        } message: {
            Text(libraryViewModel.errorMessage ?? "")
        }
        .alert("无法载入示例体验", isPresented: sampleExperienceErrorBinding) {
            Button("知道了") {
                sampleExperienceErrorMessage = nil
            }
        } message: {
            Text(sampleExperienceErrorMessage ?? "")
        }
        .alert("无法打开来源", isPresented: cardSourceErrorBinding) {
            Button("知道了") {
                cardSourceErrorMessage = nil
            }
        } message: {
            Text(cardSourceErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var continueReading: some View {
        if let document = recentlyOpenedDocuments.first {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("继续阅读", systemImage: "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Spacer()
                    Button("查看最近阅读") {
                        appState.select(.recent)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.softViolet)
                }

                DocumentRow(document: document, action: {
                    open(document)
                })
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 7) {
                Text("欢迎来到知径 Knowvia。")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Text("让知识成为路径。")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.secondaryText)
                Text("知行星舱 StarCabin AI 旗下 AI 增强型多源知识路径生成系统")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.pathTeal)
            }

            Spacer()

            Button {
                libraryViewModel.chooseAndImportDocuments(into: modelContext)
                appState.select(.library)
            } label: {
                Label("导入资料", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private var stats: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            StatCard(title: "本地资料", value: "\(documents.count)", symbolName: "books.vertical")
            StatCard(title: "知识卡片", value: "\(cards.count)", symbolName: "rectangle.stack", accent: AppTheme.softViolet)
            StatCard(title: "专题路径", value: "\(pathways.count)", symbolName: "point.topleft.down.curvedto.point.bottomright.up", accent: AppTheme.orbitBlue)
            StatCard(title: "本周资料", value: "\(importedThisWeek)", symbolName: "clock.arrow.circlepath", accent: AppTheme.pathTeal)
        }
    }

    private var positioningCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("多源资料 · 知识节点 · Knowledge Pathway", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Spacer()
                Text("专题路径 MVP")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.pathTeal)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.paleMint, in: Capsule())
            }

            Text("围绕理论、课程或研究问题组织多源资料，让概念、观点、证据和个人理解逐步形成可追溯的知识脉络。")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var recentCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近卡片")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Spacer()
                Button("查看知识卡片") {
                    appState.select(.cards)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.softViolet)
            }

            if cards.isEmpty {
                Text("还没有知识卡片。从阅读摘录或自己的笔记中创建第一张卡片。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(Array(cards.prefix(5))) { card in
                        KnowledgeCardView(
                            card: card,
                            onOpenDetail: { inspectingCard = card }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentDocuments: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近资料")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Spacer()
                Button("查看资料库") {
                    appState.select(.library)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.softViolet)
            }

            if documents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有资料。导入一份 PDF、TXT 或 Markdown，开始构建你的第一条知识路径。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)

                    Button("载入示例体验") {
                        installAndOpenDemoExperience()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(Array(dashboardDocuments.prefix(5))) { document in
                    DocumentRow(document: document, action: {
                        open(document)
                    })
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { libraryViewModel.errorMessage != nil },
            set: { if !$0 { libraryViewModel.errorMessage = nil } }
        )
    }

    private var sampleExperienceErrorBinding: Binding<Bool> {
        Binding(
            get: { sampleExperienceErrorMessage != nil },
            set: { if !$0 { sampleExperienceErrorMessage = nil } }
        )
    }

    private var cardSourceErrorBinding: Binding<Bool> {
        Binding(
            get: { cardSourceErrorMessage != nil },
            set: { if !$0 { cardSourceErrorMessage = nil } }
        )
    }

    private func open(_ document: DocumentItem) {
        readingProgressService.markOpened(document)
        try? modelContext.save()
        appState.open(document)
    }

    private func openSource(for card: KnowledgeCard) {
        do {
            let document = try sourceService.sourceDocument(for: card, in: documents)
            readingProgressService.markOpened(document)
            try modelContext.save()
            appState.open(
                document,
                pageNumber: sourceService.targetPageNumber(for: card, in: document)
            )
        } catch {
            cardSourceErrorMessage = error.localizedDescription
        }
    }

    private func installAndOpenDemoExperience() {
        do {
            let result = try demoExperienceService.installOrRestore(into: modelContext)
            open(result.document)
        } catch {
            sampleExperienceErrorMessage = error.localizedDescription
        }
    }
}
