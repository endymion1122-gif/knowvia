import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct InspectorView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \KnowledgeCard.createdAt, order: .reverse) private var cards: [KnowledgeCard]
    @Query(sort: \DocumentItem.importedAt, order: .reverse) private var documents: [DocumentItem]
    @Query(sort: \DocumentAnnotation.updatedAt, order: .reverse) private var annotations: [DocumentAnnotation]
    @State private var showsAISummaryEditor = false
    @State private var showsAISelectionEditor = false
    @State private var editingSuggestedCardDraft: KnowledgeCardDraft?
    @State private var editingSelectionCardDraft: KnowledgeCardDraft?
    @State private var editingAnnotationCardDraft: AnnotationCardDraftContext?
    @State private var reviewingAnnotationBatch: AnnotationBatchReviewContext?
    @State private var inspectingRelatedCard: KnowledgeCard?
    @State private var showsSelectionAnnotationEditor = false
    @State private var editingAnnotation: DocumentAnnotation?
    @State private var pendingDeleteAnnotation: DocumentAnnotation?
    @State private var annotationErrorMessage: String?
    @State private var annotationSearchText = ""
    @State private var annotationScope = AnnotationScope.all
    @State private var annotationExportFeedback: String?
    @State private var annotationExportErrorMessage: String?
    @State private var generatingAnnotationCardID: UUID?
    @State private var selectedAnnotationIDs: Set<UUID> = []
    private let connectionService = SelectionKnowledgeConnectionService()
    private let readingProgressService = DocumentReadingProgressService()
    private let annotationMarkdownExportService = AnnotationMarkdownExportService()
    private let annotationBatchCardService = AnnotationBatchKnowledgeCardService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let document = appState.activeDocument {
                    documentInspector(document)
                } else {
                    defaultInspector
                }
            }
            .padding(17)
        }
        .background(AppTheme.warmWhite)
        .sheet(isPresented: $showsAISummaryEditor) {
            if let document = appState.activeDocument {
                KnowledgeCardEditorView(
                    sourceDocument: document,
                    initialContent: appState.aiSummary,
                    initialKind: .summary,
                    createdBy: "ai"
                )
            }
        }
        .sheet(isPresented: $showsAISelectionEditor) {
            if let document = appState.activeDocument {
                KnowledgeCardEditorView(
                    sourceDocument: document,
                    initialContent: appState.aiSelectionExplanation,
                    pageNumber: appState.selectedPDFPageNumber,
                    initialKind: .concept,
                    createdBy: "ai"
                )
            }
        }
        .sheet(item: $editingSuggestedCardDraft) { draft in
            if let document = appState.activeDocument {
                KnowledgeCardEditorView(
                    sourceDocument: document,
                    initialTitle: draft.title,
                    initialContent: draft.content,
                    initialKind: draft.kind,
                    initialTags: draft.tags,
                    createdBy: "ai-demo"
                )
            }
        }
        .sheet(item: $editingSelectionCardDraft) { draft in
            if let document = appState.activeDocument {
                KnowledgeCardEditorView(
                    sourceDocument: document,
                    initialTitle: draft.title,
                    initialContent: draft.content,
                    pageNumber: appState.selectedPDFPageNumber,
                    initialKind: draft.kind,
                    initialTags: draft.tags,
                    createdBy: appState.generatedSelectionCardCreatedBy
                )
            }
        }
        .sheet(item: $editingAnnotationCardDraft) { context in
            if let document = documents.first(where: { $0.id == context.annotation.documentId }) {
                KnowledgeCardEditorView(
                    sourceDocument: document,
                    initialTitle: context.draft.title,
                    initialContent: context.draft.content,
                    pageNumber: context.annotation.pageNumber,
                    initialKind: context.draft.kind,
                    initialTags: context.draft.tags,
                    createdBy: appState.generatedSelectionCardCreatedBy
                )
            }
        }
        .sheet(item: $reviewingAnnotationBatch) { context in
            AnnotationBatchCardReviewView(
                document: context.document,
                bundle: context.bundle,
                createdBy: "ai-demo"
            ) {
                selectedAnnotationIDs.removeAll()
            }
        }
        .sheet(item: $inspectingRelatedCard) { card in
            KnowledgeCardDetailView(card: card)
        }
        .sheet(isPresented: $showsSelectionAnnotationEditor) {
            if let document = appState.activeDocument {
                AnnotationEditorView(
                    document: document,
                    selectedText: appState.selectedPDFText,
                    pageNumber: appState.selectedPDFPageNumber
                )
            }
        }
        .sheet(item: $editingAnnotation) { annotation in
            if let document = documents.first(where: { $0.id == annotation.documentId }) {
                AnnotationEditorView(
                    annotation: annotation,
                    document: document,
                    selectedText: annotation.selectedText,
                    pageNumber: annotation.pageNumber
                )
            }
        }
        .alert("删除这条批注？", isPresented: deleteAnnotationBinding) {
            Button("取消", role: .cancel) {
                pendingDeleteAnnotation = nil
            }
            Button("删除", role: .destructive) {
                deletePendingAnnotation()
            }
        } message: {
            Text("删除后无法恢复。")
        }
        .alert("批注操作失败", isPresented: annotationErrorBinding) {
            Button("知道了") {
                annotationErrorMessage = nil
            }
        } message: {
            Text(annotationErrorMessage ?? "")
        }
        .alert("批注导出完成", isPresented: annotationExportFeedbackBinding) {
            Button("知道了") {
                annotationExportFeedback = nil
            }
        } message: {
            Text(annotationExportFeedback ?? "")
        }
        .alert("无法导出批注", isPresented: annotationExportErrorBinding) {
            Button("知道了") {
                annotationExportErrorMessage = nil
            }
        } message: {
            Text(annotationExportErrorMessage ?? "")
        }
        .alert("无法根据批注生成卡片", isPresented: annotationCardErrorBinding) {
            Button("知道了") {
                appState.annotationCardErrorMessage = nil
            }
        } message: {
            Text(appState.annotationCardErrorMessage ?? "")
        }
    }

    private func documentInspector(_ document: DocumentItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("当前文档", symbol: "doc.text")

            VStack(alignment: .leading, spacing: 7) {
                Text(document.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)

                HStack(spacing: 6) {
                    Text(document.displayFileType)
                    if let pageNumber = appState.inspectorPageNumber {
                        Text("· 第 \(pageNumber) 页")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.coolGray, lineWidth: 1)
            }

            if !appState.selectedPDFText.isEmpty {
                sectionTitle("当前选区", symbol: "selection.pin.in.out")

                VStack(alignment: .leading, spacing: 7) {
                    if let selectedPDFPageNumber = appState.selectedPDFPageNumber {
                        Text("第 \(selectedPDFPageNumber) 页")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.pathTeal)
                    }

                    Text(appState.selectedPDFText)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .textSelection(.enabled)
                        .lineSpacing(3)

                    Button {
                        generateSelectionCardDraft()
                    } label: {
                        HStack {
                            if appState.isGeneratingSelectionCard {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(appState.isGeneratingSelectionCard ? "正在生成草稿..." : "AI 智能制卡")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isGeneratingSelectionCard)

                    Button {
                        Task {
                            await appState.explainSelectedText()
                        }
                    } label: {
                        HStack {
                            if appState.isExplainingSelection {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(appState.isExplainingSelection ? "正在解释..." : "AI 解释选区")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isExplainingSelection)

                    Button {
                        showsSelectionAnnotationEditor = true
                    } label: {
                        Label("添加批注", systemImage: "text.bubble")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AppTheme.paleMint.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))

                if let aiSelectionErrorMessage = appState.aiSelectionErrorMessage {
                    Text(aiSelectionErrorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .lineSpacing(3)
                }

                if let aiSelectionCardNotice = appState.aiSelectionCardNotice {
                    Text(aiSelectionCardNotice)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.pathTeal)
                        .lineSpacing(3)
                }

                if let aiSelectionCardErrorMessage = appState.aiSelectionCardErrorMessage {
                    Text(aiSelectionCardErrorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .lineSpacing(3)
                }

                if !appState.aiSelectionExplanation.isEmpty {
                    selectionExplanation
                }

                selectionConnections(for: document)
            }

            if document.isPDF {
                sectionTitle("当前页文本", symbol: "text.viewfinder")

                Text(
                    appState.extractedPageText.isEmpty
                        ? appState.extractionMessage
                            ?? "点击阅读器工具栏中的“提取当前页文本”，这里会显示可用于后续摘录和 AI 速读的原文。"
                        : appState.extractedPageText
                )
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
                .textSelection(.enabled)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.coolGray, lineWidth: 1)
                }
            }

            annotationsSection(for: document)
            relatedCards(for: document)
            aiAssistant(for: document)
        }
    }

    private func generateSelectionCardDraft() {
        Task {
            editingSelectionCardDraft = await appState.generateSelectedTextCardDraft()
        }
    }

    @ViewBuilder
    private func selectionConnections(for document: DocumentItem) -> some View {
        let connections = connectionService.connections(
            for: appState.selectedPDFText,
            activeDocumentID: document.id,
            documents: documents,
            cards: cards
        )

        if !connections.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                sectionTitle("跨资料线索", symbol: "point.3.connected.trianglepath.dotted")

                Text("在已有资料和卡片中找到了相同词句。可以继续打开核验，逐步形成知识连接。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)

                ForEach(Array(connections.documents.prefix(3))) { relatedDocument in
                    Button {
                        openRelatedDocument(relatedDocument)
                    } label: {
                        connectionRow(
                            title: relatedDocument.title,
                            detail: "相关资料 · \(relatedDocument.displayFileType)",
                            symbol: "doc.text"
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(Array(connections.cards.prefix(3))) { card in
                    Button {
                        inspectingRelatedCard = card
                    } label: {
                        connectionRow(
                            title: card.title,
                            detail: "相关卡片 · \(card.kind.title)",
                            symbol: "rectangle.stack"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(AppTheme.paleLavender.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func connectionRow(
        title: String,
        detail: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.softViolet)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(8)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
    }

    private func openRelatedDocument(_ document: DocumentItem) {
        readingProgressService.markOpened(document)
        try? modelContext.save()
        appState.open(document)
    }

    @ViewBuilder
    private func annotationsSection(for document: DocumentItem) -> some View {
        let documentAnnotations = annotations.filter { $0.documentId == document.id }
        let filteredAnnotations = filteredAnnotations(
            documentAnnotations,
            for: document
        )
        let selectedCount = documentAnnotations.filter {
            selectedAnnotationIDs.contains($0.id)
        }.count

        if !documentAnnotations.isEmpty {
            HStack {
                sectionTitle("文档批注", symbol: "text.bubble")
                Spacer()
                Text("\(filteredAnnotations.count) / \(documentAnnotations.count)")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.tertiaryText)
                    TextField("搜索批注或原文", text: $annotationSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                .padding(8)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(AppTheme.coolGray, lineWidth: 1)
                }

                HStack(spacing: 8) {
                    if document.isPDF {
                        Picker("筛选范围", selection: $annotationScope) {
                            ForEach(AnnotationScope.allCases) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.softViolet.opacity(0.58))
                            .frame(width: 7, height: 7)
                        Text("原文已标记")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()

                    Button {
                        exportAnnotations(filteredAnnotations, for: document)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.softViolet)
                    }
                    .buttonStyle(.plain)
                    .disabled(filteredAnnotations.isEmpty)
                    .help("导出当前筛选结果")
                }

                HStack(spacing: 8) {
                    Button {
                        toggleCurrentAnnotationSelection(filteredAnnotations)
                    } label: {
                        Text(
                            filteredAnnotations.allSatisfy { selectedAnnotationIDs.contains($0.id) }
                                ? "取消选择当前结果"
                                : "选择当前结果"
                        )
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.slateBlue)
                    .disabled(filteredAnnotations.isEmpty)

                    Spacer()

                    Button {
                        prepareAnnotationBatch(for: document)
                    } label: {
                        Label("批量整理 \(selectedCount)", systemImage: "rectangle.stack.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 6))
                    .disabled(selectedCount < 2)
                    .opacity(selectedCount < 2 ? 0.45 : 1)
                    .help(selectedCount < 2 ? "请至少选择两条批注" : "生成概念、观点和证据草稿")
                }

                if filteredAnnotations.isEmpty {
                    Text("当前筛选条件下没有批注。")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.vertical, 5)
                }

                if let annotationCardNotice = appState.annotationCardNotice {
                    Text(annotationCardNotice)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.pathTeal)
                        .lineSpacing(2)
                }

                ForEach(filteredAnnotations) { annotation in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Button {
                                toggleAnnotationSelection(annotation)
                            } label: {
                                Image(
                                    systemName: selectedAnnotationIDs.contains(annotation.id)
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                )
                                .font(.system(size: 13))
                                .foregroundStyle(
                                    selectedAnnotationIDs.contains(annotation.id)
                                        ? AppTheme.softViolet
                                        : AppTheme.tertiaryText
                                )
                            }
                            .buttonStyle(.plain)
                            .help(
                                selectedAnnotationIDs.contains(annotation.id)
                                    ? "取消选择"
                                    : "选择用于批量整理"
                            )

                            Text(annotation.pageNumber.map { "第 \($0) 页" } ?? "文本选区")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.pathTeal)
                            Spacer()

                            Menu {
                                Button("回到原文", systemImage: "arrow.turn.down.right") {
                                    openAnnotation(annotation, in: document)
                                }
                                Button("编辑", systemImage: "pencil") {
                                    editingAnnotation = annotation
                                }
                                Button("删除", systemImage: "trash", role: .destructive) {
                                    pendingDeleteAnnotation = annotation
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                        }

                        Text(annotation.note)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                            .lineLimit(3)

                        Text(annotation.selectedText)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(2)

                        HStack {
                            Button {
                                generateAnnotationCardDraft(for: annotation)
                            } label: {
                                HStack(spacing: 4) {
                                    if generatingAnnotationCardID == annotation.id {
                                        ProgressView()
                                            .controlSize(.mini)
                                    }
                                    Text(
                                        generatingAnnotationCardID == annotation.id
                                            ? "正在制卡..."
                                            : "AI 批注制卡"
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                            .disabled(appState.isGeneratingAnnotationCard)

                            Spacer()

                            Button("回到原文") {
                                openAnnotation(annotation, in: document)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.softViolet)
                        }
                    }
                    .padding(10)
                    .background(
                        selectedAnnotationIDs.contains(annotation.id)
                            ? AppTheme.paleLavender.opacity(0.7)
                            : AppTheme.warmIvory.opacity(0.62),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.coolGray, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func filteredAnnotations(
        _ annotations: [DocumentAnnotation],
        for document: DocumentItem
    ) -> [DocumentAnnotation] {
        annotations.filter { annotation in
            let matchesScope = annotationScope == .all
                || !document.isPDF
                || annotation.pageNumber == appState.inspectorPageNumber
            let matchesSearch = annotationSearchText.isEmpty
                || annotation.note.localizedCaseInsensitiveContains(annotationSearchText)
                || annotation.selectedText.localizedCaseInsensitiveContains(annotationSearchText)
            return matchesScope && matchesSearch
        }
    }

    private var deleteAnnotationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteAnnotation != nil },
            set: { if !$0 { pendingDeleteAnnotation = nil } }
        )
    }

    private var annotationErrorBinding: Binding<Bool> {
        Binding(
            get: { annotationErrorMessage != nil },
            set: { if !$0 { annotationErrorMessage = nil } }
        )
    }

    private var annotationExportFeedbackBinding: Binding<Bool> {
        Binding(
            get: { annotationExportFeedback != nil },
            set: { if !$0 { annotationExportFeedback = nil } }
        )
    }

    private var annotationExportErrorBinding: Binding<Bool> {
        Binding(
            get: { annotationExportErrorMessage != nil },
            set: { if !$0 { annotationExportErrorMessage = nil } }
        )
    }

    private var annotationCardErrorBinding: Binding<Bool> {
        Binding(
            get: { appState.annotationCardErrorMessage != nil },
            set: { if !$0 { appState.annotationCardErrorMessage = nil } }
        )
    }

    private func openAnnotation(_ annotation: DocumentAnnotation, in document: DocumentItem) {
        readingProgressService.markOpened(document)
        try? modelContext.save()
        appState.open(
            document,
            pageNumber: annotation.pageNumber,
            textAnchorExcerpt: annotation.selectedText
        )
    }

    private func deletePendingAnnotation() {
        guard let pendingDeleteAnnotation else {
            return
        }

        modelContext.delete(pendingDeleteAnnotation)
        do {
            try modelContext.save()
            selectedAnnotationIDs.remove(pendingDeleteAnnotation.id)
            self.pendingDeleteAnnotation = nil
        } catch {
            annotationErrorMessage = error.localizedDescription
        }
    }

    private func exportAnnotations(
        _ annotations: [DocumentAnnotation],
        for document: DocumentItem
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(document.title) 批注.md"
        panel.title = "导出阅读批注"
        panel.message = "导出当前筛选结果中的 \(annotations.count) 条批注。"

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            try annotationMarkdownExportService.export(
                annotations: annotations,
                to: destinationURL
            )
            annotationExportFeedback = "已导出 \(annotations.count) 条阅读批注。"
        } catch {
            annotationExportErrorMessage = error.localizedDescription
        }
    }

    private func generateAnnotationCardDraft(for annotation: DocumentAnnotation) {
        generatingAnnotationCardID = annotation.id
        Task {
            defer { generatingAnnotationCardID = nil }
            guard let draft = await appState.generateAnnotationCardDraft(annotation) else {
                return
            }
            editingAnnotationCardDraft = AnnotationCardDraftContext(
                annotation: annotation,
                draft: draft
            )
        }
    }

    private func toggleAnnotationSelection(_ annotation: DocumentAnnotation) {
        if selectedAnnotationIDs.contains(annotation.id) {
            selectedAnnotationIDs.remove(annotation.id)
        } else {
            selectedAnnotationIDs.insert(annotation.id)
        }
    }

    private func toggleCurrentAnnotationSelection(_ annotations: [DocumentAnnotation]) {
        let annotationIDs = Set(annotations.map(\.id))
        if annotationIDs.isSubset(of: selectedAnnotationIDs) {
            selectedAnnotationIDs.subtract(annotationIDs)
        } else {
            selectedAnnotationIDs.formUnion(annotationIDs)
        }
    }

    private func prepareAnnotationBatch(for document: DocumentItem) {
        let selectedAnnotations = annotations.filter {
            $0.documentId == document.id && selectedAnnotationIDs.contains($0.id)
        }

        do {
            let bundle = try annotationBatchCardService.bundle(
                documentTitle: document.title,
                annotations: selectedAnnotations
            )
            reviewingAnnotationBatch = AnnotationBatchReviewContext(
                document: document,
                bundle: bundle
            )
        } catch {
            annotationErrorMessage = error.localizedDescription
        }
    }

    private var selectionExplanation: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.softViolet)
                Text("AI 概念解释")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
            }

            if let aiSelectionNotice = appState.aiSelectionNotice {
                Text(aiSelectionNotice)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.pathTeal)
                    .lineSpacing(3)
            }

            Text(appState.aiSelectionExplanation)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
                .textSelection(.enabled)
                .lineSpacing(3)

            Text("AI 输出仅作为理解支架。保存前请结合原文核验。")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.softViolet)
                .lineSpacing(3)

            Button("保存为概念卡") {
                showsAISelectionEditor = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.deepIndigo)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.paleLavender.opacity(0.52), in: RoundedRectangle(cornerRadius: 10))
    }

    private var defaultInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("知径 Knowvia", symbol: "sparkles")

            Text("你的资料默认保存在本机。打开一份 PDF 后，可以在这里查看当前页文本与后续 AI 阅读入口。")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(4)

            aiSetupHint
        }
    }

    private var aiSetupHint: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.softViolet)
                Text("AI 阅读助手")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Spacer()
            }

            Text("测试版已默认开启本地 Demo AI。打开文档即可体验结构化速读，无需配置 API Key。")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
        }
        .padding(12)
        .background(AppTheme.paleLavender.opacity(0.52), in: RoundedRectangle(cornerRadius: 10))
    }

    private func aiAssistant(for document: DocumentItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.softViolet)
                Text("AI 阅读助手")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Spacer()
            }

            Button {
                Task {
                    await appState.summarizeActiveDocument()
                    try? modelContext.save()
                }
            } label: {
                HStack {
                    if appState.isSummarizing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(appState.isSummarizing ? "正在速读..." : "AI 速读当前文档")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(appState.isSummarizing)

            if let aiErrorMessage = appState.aiErrorMessage {
                Text(aiErrorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .lineSpacing(3)
            }

            if !appState.aiSummary.isEmpty {
                if let aiSummaryNotice = appState.aiSummaryNotice {
                    Text(aiSummaryNotice)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.pathTeal)
                        .lineSpacing(3)
                }

                Text(appState.aiSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .textSelection(.enabled)
                    .lineSpacing(3)

                Text("AI 输出仅作为阅读和写作支架。请结合原文核验，不要直接作为最终论文内容使用。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.softViolet)
                    .lineSpacing(3)

                Button("保存为知识卡片") {
                    showsAISummaryEditor = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

                if !appState.suggestedCardDrafts.isEmpty {
                    Divider()
                    suggestedCardDraftList
                }
            }
        }
        .padding(12)
        .background(AppTheme.paleLavender.opacity(0.52), in: RoundedRectangle(cornerRadius: 10))
    }

    private var suggestedCardDraftList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("建议知识卡片")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            Text(suggestedCardDraftDescription)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)

            ForEach(appState.suggestedCardDrafts) { draft in
                Button {
                    editingSuggestedCardDraft = draft
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(draft.kind.title)卡")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(suggestedCardAccent(for: draft.kind))
                            Spacer()
                            Text("编辑并保存")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.softViolet)
                        }

                        Text(draft.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                            .lineLimit(1)

                        Text(draft.content)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(3)
                            .lineSpacing(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(suggestedCardAccent(for: draft.kind).opacity(0.24), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestedCardDraftDescription: String {
        let hasRealAIDrafts = appState.suggestedCardDrafts.contains {
            $0.tags.contains("真实 AI")
        }
        if hasRealAIDrafts {
            return "以下草稿由真实 API 摘要整理。请逐张核验，再决定是否保存。"
        }
        return "以下草稿由本地兜底生成器整理。请逐张核验，再决定是否保存。"
    }

    private func suggestedCardAccent(for kind: KnowledgeCardKind) -> Color {
        switch kind {
        case .concept:
            AppTheme.deepIndigo
        case .argument:
            AppTheme.softPlum
        case .evidence:
            AppTheme.pathTeal
        default:
            AppTheme.slateBlue
        }
    }

    @ViewBuilder
    private func relatedCards(for document: DocumentItem) -> some View {
        let relatedCards = cards.filter { $0.sourceDocumentId == document.id }

        if !relatedCards.isEmpty {
            sectionTitle("相关知识卡片", symbol: "rectangle.stack")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(relatedCards.prefix(4))) { card in
                    Button {
                        inspectingRelatedCard = card
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(card.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.deepIndigo)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.softViolet)
                            }
                            Text(card.content)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.coolGray, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.slateBlue)
    }
}

private enum AnnotationScope: String, CaseIterable, Identifiable {
    case all
    case currentPage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "全部批注"
        case .currentPage:
            "当前页"
        }
    }
}

private struct AnnotationCardDraftContext: Identifiable {
    let annotation: DocumentAnnotation
    let draft: KnowledgeCardDraft

    var id: UUID { draft.id }
}

private struct AnnotationBatchReviewContext: Identifiable {
    let document: DocumentItem
    let bundle: AnnotationBatchKnowledgeCardBundle

    var id: UUID { bundle.id }
}
