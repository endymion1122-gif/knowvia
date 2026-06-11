import SwiftData
import SwiftUI

struct KnowledgePathwaysView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgePathway.updatedAt, order: .reverse) private var pathways: [KnowledgePathway]
    @Query(sort: \DocumentItem.importedAt, order: .reverse) private var documents: [DocumentItem]
    @Query(sort: \KnowledgeCard.updatedAt, order: .reverse) private var cards: [KnowledgeCard]
    @Query(sort: \KnowledgeRelation.updatedAt, order: .reverse) private var relations: [KnowledgeRelation]

    @State private var searchText = ""
    @State private var showsCreatePathway = false
    @State private var editingPathway: KnowledgePathway?
    @State private var managingSourcesForPathway: KnowledgePathway?
    @State private var inspectingPathway: KnowledgePathway?
    @State private var pendingDeletePathway: KnowledgePathway?
    @State private var errorMessage: String?

    private let pathwayService = KnowledgePathwayService()
    private let relationService = KnowledgeRelationService()

    private var filteredPathways: [KnowledgePathway] {
        pathways.filter { pathway in
            searchText.isEmpty
                || pathway.title.localizedCaseInsensitiveContains(searchText)
                || pathway.overview.localizedCaseInsensitiveContains(searchText)
                || pathway.tags.contains {
                    $0.localizedCaseInsensitiveContains(searchText)
                }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if pathways.isEmpty {
                emptyState
            } else if filteredPathways.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPathways) { pathway in
                            pathwayCard(pathway)
                        }
                    }
                    .padding(22)
                }
            }
        }
        .background(AppTheme.pageBackground)
        .sheet(isPresented: $showsCreatePathway) {
            KnowledgePathwayEditorView { title, overview, tags in
                createPathway(title: title, overview: overview, tags: tags)
            }
        }
        .sheet(item: $editingPathway) { pathway in
            KnowledgePathwayEditorView(pathway: pathway) { title, overview, tags in
                update(pathway, title: title, overview: overview, tags: tags)
            }
        }
        .sheet(item: $managingSourcesForPathway) { pathway in
            PathwaySourcesEditorView(
                pathway: pathway,
                documents: documents
            ) { selectedDocumentIDs in
                updateSources(for: pathway, selectedDocumentIDs: selectedDocumentIDs)
            }
        }
        .sheet(item: $inspectingPathway) { pathway in
            KnowledgePathwayDetailView(pathway: pathway)
        }
        .alert("删除这条专题路径？", isPresented: deleteBinding) {
            Button("取消", role: .cancel) {
                pendingDeletePathway = nil
            }
            Button("删除", role: .destructive) {
                deletePendingPathway()
            }
        } message: {
            Text("路径会被删除，资料本身仍保留在资料库中。")
        }
        .alert("无法保存专题路径", isPresented: errorBinding) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("专题路径库")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("围绕理论、课程或研究问题，持续组织多源资料与知识脉络。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Button {
                    showsCreatePathway = true
                } label: {
                    Label("新建专题路径", systemImage: "plus")
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
                TextField("搜索路径名称、总览或标签", text: $searchText)
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
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 27))
                .foregroundStyle(AppTheme.softViolet)
                .frame(width: 68, height: 68)
                .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 19))

            Text("创建你的第一条专题路径")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            Text("例如认知负荷理论、自我调节学习或生成式 AI 支架。之后可以把已有资料加入路径。")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button {
                showsCreatePathway = true
            } label: {
                Label("新建专题路径", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pathwayCard(_ pathway: KnowledgePathway) -> some View {
        let sourceDocuments = pathwayService.documents(for: pathway, in: documents)
        let nodeCards = pathwayService.cards(for: pathway, in: cards)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.softViolet)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 5) {
                    Text(pathway.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(
                        pathway.overview.isEmpty
                            ? "还没有专题总览。可以先加入资料，再逐步整理知识脉络。"
                            : pathway.overview
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(3)
                    .lineSpacing(2)
                }

                Spacer()

                Menu {
                    Button("管理来源资料", systemImage: "books.vertical") {
                        managingSourcesForPathway = pathway
                    }
                    Button("编辑路径信息", systemImage: "pencil") {
                        editingPathway = pathway
                    }
                    Button("删除路径", systemImage: "trash", role: .destructive) {
                        pendingDeletePathway = pathway
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            HStack(spacing: 8) {
                Label("\(sourceDocuments.count) 份资料", systemImage: "doc.on.doc")
                Text("·")
                Label("\(nodeCards.count) 个节点", systemImage: "rectangle.stack")
                Text("·")
                Text("更新于 \(pathway.updatedAt.formatted(date: .abbreviated, time: .omitted))")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.pathTeal)

            if !pathway.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(pathway.tags.prefix(4), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.slateBlue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(AppTheme.coolGray.opacity(0.72), in: Capsule())
                    }
                }
            }

            if sourceDocuments.isEmpty {
                Button("加入来源资料") {
                    managingSourcesForPathway = pathway
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.softViolet)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(sourceDocuments.prefix(3)) { document in
                        Label(document.title, systemImage: "doc.text")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }
                    if sourceDocuments.count > 3 {
                        Text("还有 \(sourceDocuments.count - 3) 份资料")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
            }

            Button {
                inspectingPathway = pathway
            } label: {
                HStack {
                    Text("打开路径详情")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.softViolet)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletePathway != nil },
            set: { if !$0 { pendingDeletePathway = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func createPathway(title: String, overview: String, tags: [String]) {
        modelContext.insert(
            KnowledgePathway(title: title, overview: overview, tags: tags)
        )
        saveChanges {
            showsCreatePathway = false
        }
    }

    private func update(
        _ pathway: KnowledgePathway,
        title: String,
        overview: String,
        tags: [String]
    ) {
        pathway.title = title
        pathway.overview = overview
        pathway.tags = tags
        pathway.updatedAt = Date()
        saveChanges {
            editingPathway = nil
        }
    }

    private func updateSources(
        for pathway: KnowledgePathway,
        selectedDocumentIDs: Set<UUID>
    ) {
        pathwayService.updateSources(
            for: pathway,
            selectedDocumentIDs: selectedDocumentIDs,
            documents: documents
        )
        saveChanges {
            managingSourcesForPathway = nil
        }
    }

    private func deletePendingPathway() {
        guard let pendingDeletePathway else {
            return
        }

        pathwayService.detach(pendingDeletePathway, from: documents, cards: cards)
        for relation in relationService.relations(for: pendingDeletePathway, in: relations) {
            modelContext.delete(relation)
        }
        modelContext.delete(pendingDeletePathway)
        saveChanges {
            self.pendingDeletePathway = nil
        }
    }

    private func saveChanges(onSuccess: () -> Void) {
        do {
            try modelContext.save()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct KnowledgePathwayEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let pathway: KnowledgePathway?
    private let onSave: (String, String, [String]) -> Void

    @State private var title: String
    @State private var overview: String
    @State private var tagsText: String

    init(
        pathway: KnowledgePathway? = nil,
        onSave: @escaping (String, String, [String]) -> Void
    ) {
        self.pathway = pathway
        self.onSave = onSave
        _title = State(initialValue: pathway?.title ?? "")
        _overview = State(initialValue: pathway?.overview ?? "")
        _tagsText = State(initialValue: pathway?.tags.joined(separator: "，") ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(pathway == nil ? "新建专题路径" : "编辑专题路径")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)
                Button("保存") {
                    onSave(trimmedTitle, overview.trimmingCharacters(in: .whitespacesAndNewlines), tags)
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
                .disabled(trimmedTitle.isEmpty)
                .opacity(trimmedTitle.isEmpty ? 0.45 : 1)
            }

            field("路径名称") {
                TextField("例如：认知负荷理论", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            field("专题总览") {
                TextEditor(text: $overview)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 150)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(AppTheme.coolGray, lineWidth: 1)
                    }
            }

            field("标签") {
                TextField("使用逗号分隔，例如：学习科学，理论", text: $tagsText)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(20)
        .frame(width: 600, height: 390)
        .background(AppTheme.pageBackground)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var tags: [String] {
        tagsText
            .components(separatedBy: CharacterSet(charactersIn: ",，"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.slateBlue)
            content()
        }
    }
}

private struct PathwaySourcesEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let pathway: KnowledgePathway
    let documents: [DocumentItem]
    let onSave: (Set<UUID>) -> Void

    @State private var selectedDocumentIDs: Set<UUID>

    init(
        pathway: KnowledgePathway,
        documents: [DocumentItem],
        onSave: @escaping (Set<UUID>) -> Void
    ) {
        self.pathway = pathway
        self.documents = documents
        self.onSave = onSave
        _selectedDocumentIDs = State(initialValue: Set(pathway.sourceDocumentIDs))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("管理来源资料")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(pathway.title)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.pathTeal)
                }
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)
                Button("保存") {
                    onSave(selectedDocumentIDs)
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(18)

            Divider()

            if documents.isEmpty {
                ContentUnavailableView(
                    "资料库还是空的",
                    systemImage: "books.vertical",
                    description: Text("先导入资料，再把它们加入专题路径。")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(documents) { document in
                            Button {
                                toggle(document.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(
                                        systemName: selectedDocumentIDs.contains(document.id)
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                    .foregroundStyle(
                                        selectedDocumentIDs.contains(document.id)
                                            ? AppTheme.softViolet
                                            : AppTheme.tertiaryText
                                    )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(document.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(AppTheme.primaryText)
                                        Text(document.displayFileType)
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.tertiaryText)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .frame(width: 620, height: 620)
        .background(AppTheme.pageBackground)
    }

    private func toggle(_ documentID: UUID) {
        if selectedDocumentIDs.contains(documentID) {
            selectedDocumentIDs.remove(documentID)
        } else {
            selectedDocumentIDs.insert(documentID)
        }
    }
}
