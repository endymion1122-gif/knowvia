import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \DocumentItem.importedAt, order: .reverse) private var documents: [DocumentItem]
    @Query(sort: \KnowledgePathway.updatedAt, order: .reverse) private var pathways: [KnowledgePathway]
    @StateObject private var viewModel = LibraryViewModel()
    @State private var searchText = ""
    @State private var isDropTarget = false
    @State private var showsWebSourceImporter = false
    @State private var editingDocument: DocumentItem?
    @State private var assigningPathwaysForDocument: DocumentItem?
    @State private var pendingDeleteDocument: DocumentItem?
    @State private var importFeedback: String?
    @State private var localErrorMessage: String?
    private let readingProgressService = DocumentReadingProgressService()
    private let demoExperienceService = DemoExperienceService()
    private let pathwayService = KnowledgePathwayService()

    let recentOnly: Bool

    init(recentOnly: Bool = false) {
        self.recentOnly = recentOnly
    }

    private var filteredDocuments: [DocumentItem] {
        let matchingDocuments = documents.filter { document in
            let matchesMode = !recentOnly || document.lastOpenedAt != nil
            let matchesSearch = searchText.isEmpty
                || document.title.localizedCaseInsensitiveContains(searchText)
                || document.author.localizedCaseInsensitiveContains(searchText)
                || document.sourceURLString.localizedCaseInsensitiveContains(searchText)
                || document.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesMode && matchesSearch
        }
        return recentOnly
            ? readingProgressService.recentDocuments(in: matchingDocuments)
            : matchingDocuments
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if filteredDocuments.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(filteredDocuments) { document in
                            DocumentRow(
                                document: document,
                                action: { open(document) },
                                onEdit: { editingDocument = document },
                                onManagePathways: { assigningPathwaysForDocument = document },
                                onToggleCompleted: { toggleCompleted(document) },
                                onDelete: { pendingDeleteDocument = document }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(AppTheme.pageBackground)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.pathTeal, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .padding(12)
                    .overlay {
                        Text("松开即可导入到知径 Knowvia")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget) { providers in
            viewModel.importDroppedProviders(providers, into: modelContext)
        }
        .onChange(of: viewModel.importedDocumentCount) { oldValue, newValue in
            guard newValue > oldValue else {
                return
            }
            importFeedback = "已导入 \(newValue - oldValue) 份资料"
        }
        .task(id: importFeedback) {
            guard importFeedback != nil else {
                return
            }
            try? await Task.sleep(for: .seconds(3))
            importFeedback = nil
        }
        .sheet(item: $editingDocument) { document in
            DocumentMetadataEditorView(document: document) { draft in
                update(document, draft: draft)
            }
        }
        .sheet(isPresented: $showsWebSourceImporter) {
            WebSourceImportView { document in
                insertWebSource(document)
            }
        }
        .sheet(item: $assigningPathwaysForDocument) { document in
            PathwayAssignmentEditorView(
                document: document,
                pathways: pathways
            ) { selectedPathwayIDs in
                updatePathwayAssignments(
                    for: document,
                    selectedPathwayIDs: selectedPathwayIDs
                )
            }
        }
        .alert("删除这份资料？", isPresented: deleteBinding) {
            Button("取消", role: .cancel) {
                pendingDeleteDocument = nil
            }
            Button("删除", role: .destructive) {
                deletePendingDocument()
            }
        } message: {
            Text("资料库中的本地副本会被删除。已保存的知识卡片会继续保留。")
        }
        .alert("无法完成操作", isPresented: errorBinding) {
            Button("知道了") {
                viewModel.errorMessage = nil
                localErrorMessage = nil
            }
        } message: {
            Text(localErrorMessage ?? viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recentOnly ? "最近阅读" : "资料库")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(recentOnly ? "回到你的近期阅读现场。" : "管理本地文档，构建可以长期沉淀的个人资料空间。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                if let importFeedback {
                    Label(importFeedback, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.pathTeal)
                }

                Button {
                    showsWebSourceImporter = true
                } label: {
                    Label("网页资料", systemImage: "link.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.chooseAndImportDocuments(into: modelContext)
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

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.tertiaryText)
                TextField("搜索标题、作者、链接或标签", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.coolGray, lineWidth: 1)
            }
        }
        .padding(22)
        .background(AppTheme.warmWhite)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.coolGray)
                .frame(height: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            LogoMark()
                .frame(width: 62, height: 62)
                .padding(13)
                .background(AppTheme.paleLavender.opacity(0.52), in: RoundedRectangle(cornerRadius: 18))

            Text(recentOnly ? "还没有最近阅读" : "还没有资料。")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            Text(
                recentOnly
                    ? "从资料库中打开文档后，它们会出现在这里。"
                    : "拖入 PDF、课程文档或笔记，开始构建你的第一条知识路径。"
            )
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)

            if !recentOnly {
                HStack(spacing: 12) {
                    Button {
                        viewModel.chooseAndImportDocuments(into: modelContext)
                    } label: {
                        Label("选择本地文件", systemImage: "arrow.down.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button("添加网页资料") {
                        showsWebSourceImporter = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.pathTeal)

                    Button("载入示例体验") {
                        installAndOpenDemoExperience()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil || localErrorMessage != nil },
            set: {
                if !$0 {
                    viewModel.errorMessage = nil
                    localErrorMessage = nil
                }
            }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteDocument != nil },
            set: { if !$0 { pendingDeleteDocument = nil } }
        )
    }

    private func open(_ document: DocumentItem) {
        readingProgressService.markOpened(document)
        try? modelContext.save()
        appState.open(document)
    }

    private func toggleCompleted(_ document: DocumentItem) {
        readingProgressService.toggleCompleted(document)
        do {
            try modelContext.save()
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }

    private func installAndOpenDemoExperience() {
        do {
            let result = try demoExperienceService.installOrRestore(into: modelContext)
            open(result.document)
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }

    private func update(_ document: DocumentItem, draft: DocumentMetadataDraft) {
        document.title = draft.title
        document.tags = draft.tags
        document.sourceKind = draft.sourceKind
        document.author = draft.author
        document.publicationYear = draft.publicationYear
        document.sourceURLString = draft.sourceURLString
        document.sourceNote = draft.sourceNote
        document.credibilityLevel = draft.credibilityLevel
        document.contributionNote = draft.contributionNote
        document.updatedAt = Date()

        do {
            try modelContext.save()
            editingDocument = nil
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }

    private func insertWebSource(_ document: DocumentItem) {
        modelContext.insert(document)
        do {
            try modelContext.save()
            importFeedback = "已添加 1 份网页资料"
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }

    private func updatePathwayAssignments(
        for document: DocumentItem,
        selectedPathwayIDs: Set<UUID>
    ) {
        pathwayService.updateAssignments(
            for: document,
            selectedPathwayIDs: selectedPathwayIDs,
            pathways: pathways
        )

        do {
            try modelContext.save()
            assigningPathwaysForDocument = nil
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }

    private func deletePendingDocument() {
        guard let pendingDeleteDocument else {
            return
        }

        do {
            try FileImportService.shared.deleteImportedCopy(for: pendingDeleteDocument)
            pathwayService.updateAssignments(
                for: pendingDeleteDocument,
                selectedPathwayIDs: [],
                pathways: pathways
            )
            modelContext.delete(pendingDeleteDocument)
            try modelContext.save()
            self.pendingDeleteDocument = nil
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }
}
