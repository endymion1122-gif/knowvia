import PDFKit
import SwiftData
import SwiftUI

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \DocumentAnnotation.updatedAt, order: .reverse) private var annotations: [DocumentAnnotation]
    @StateObject private var viewModel: ReaderViewModel
    @State private var selectedText = ""
    @State private var selectedPageNumber: Int?
    @State private var pageNumberInput = ""
    @State private var searchText = ""
    @State private var searchSelections: [PDFSelection] = []
    @State private var selectedSearchMatchIndex = 0
    @State private var searchNavigationID = 0
    @State private var showsExcerptEditor = false
    @State private var showsAnnotationEditor = false
    @State private var editingAISmartDraft: KnowledgeCardDraft?
    private let readingProgressService = DocumentReadingProgressService()
    private let searchService = PDFDocumentSearchService()
    private let annotationHighlightService = AnnotationHighlightService()

    init(document: DocumentItem, initialPageNumber: Int? = nil) {
        _viewModel = StateObject(
            wrappedValue: ReaderViewModel(
                document: document,
                initialPageNumber: initialPageNumber
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            searchBar

            if let pdfDocument = viewModel.pdfDocument {
                PDFKitView(
                    document: pdfDocument,
                    currentPageIndex: $viewModel.currentPageIndex,
                    zoomScale: $viewModel.zoomScale,
                    selectedText: $selectedText,
                    selectionPageNumber: $selectedPageNumber,
                    annotationSelections: annotationSelections,
                    highlightedSelections: searchSelections,
                    searchSelection: activeSearchSelection
                )
                .background(AppTheme.pageBackground)
            } else {
                ContentUnavailableView(
                    "无法打开 PDF",
                    systemImage: "exclamationmark.triangle",
                    description: Text("请确认本地资料副本仍然存在且文件格式有效。")
                )
            }
        }
        .background(AppTheme.pageBackground)
        .sheet(isPresented: $showsExcerptEditor) {
            KnowledgeCardEditorView(
                sourceDocument: viewModel.documentItem,
                initialContent: selectedText,
                pageNumber: selectedPageNumber ?? viewModel.currentPageIndex + 1
            )
        }
        .sheet(isPresented: $showsAnnotationEditor) {
            AnnotationEditorView(
                document: viewModel.documentItem,
                selectedText: selectedText,
                pageNumber: selectedPageNumber ?? viewModel.currentPageIndex + 1
            )
        }
        .sheet(item: $editingAISmartDraft) { draft in
            KnowledgeCardEditorView(
                sourceDocument: viewModel.documentItem,
                initialTitle: draft.title,
                initialContent: draft.content,
                pageNumber: selectedPageNumber ?? viewModel.currentPageIndex + 1,
                initialKind: draft.kind,
                initialTags: draft.tags,
                createdBy: appState.generatedSelectionCardCreatedBy
            )
        }
        .alert("无法生成卡片", isPresented: selectionCardErrorBinding) {
            Button("知道了") {
                appState.aiSelectionCardErrorMessage = nil
            }
        } message: {
            Text(appState.aiSelectionCardErrorMessage ?? "")
        }
        .onAppear {
            syncInspectorPage()
            syncPageNumberInput()
        }
        .onChange(of: viewModel.currentPageIndex) {
            syncInspectorPage()
            syncPageNumberInput()
        }
        .onChange(of: viewModel.extractedPageText) {
            appState.extractedPageText = viewModel.extractedPageText
        }
        .onChange(of: selectedText) {
            syncInspectorSelection()
        }
        .onChange(of: selectedPageNumber) {
            syncInspectorSelection()
        }
        .onChange(of: searchText) {
            updateSearchSelections()
        }
        .onChange(of: appState.requestedPDFPageNumber) {
            navigateToRequestedPDFPage()
        }
    }

    private var selectionCardErrorBinding: Binding<Bool> {
        Binding(
            get: { appState.aiSelectionCardErrorMessage != nil },
            set: { if !$0 { appState.aiSelectionCardErrorMessage = nil } }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.tertiaryText)

            TextField("在 PDF 中搜索", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit {
                    showNextSearchMatch()
                }

            if !searchText.isEmpty {
                Text(searchResultLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(searchSelections.isEmpty ? AppTheme.softPlum : AppTheme.secondaryText)

                Button {
                    showPreviousSearchMatch()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(searchSelections.isEmpty)
                .help("上一个搜索结果")

                Button {
                    showNextSearchMatch()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(searchSelections.isEmpty)
                .help("下一个搜索结果")

                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .help("清除搜索")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppTheme.deepIndigo)
        .padding(.horizontal, 20)
        .frame(height: 38)
        .background(AppTheme.warmWhite)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.coolGray).frame(height: 1)
        }
    }

    private var activeSearchSelection: PDFSearchSelection? {
        guard searchSelections.indices.contains(selectedSearchMatchIndex) else {
            return nil
        }

        return PDFSearchSelection(
            navigationID: searchNavigationID,
            selection: searchSelections[selectedSearchMatchIndex]
        )
    }

    private var annotationSelections: [PDFSelection] {
        guard let document = viewModel.pdfDocument else {
            return []
        }

        return annotationHighlightService.pdfSelections(
            for: annotations.filter { $0.documentId == viewModel.documentItem.id },
            in: document
        )
    }

    private var searchResultLabel: String {
        guard !searchSelections.isEmpty else {
            return "无匹配"
        }
        return "\(selectedSearchMatchIndex + 1) / \(searchSelections.count)"
    }

    private func updateSearchSelections() {
        searchSelections = viewModel.pdfDocument.map {
            searchService.selections(for: searchText, in: $0)
        } ?? []
        selectedSearchMatchIndex = 0
        searchNavigationID += 1
    }

    private func showPreviousSearchMatch() {
        guard !searchSelections.isEmpty else {
            return
        }
        selectedSearchMatchIndex = (selectedSearchMatchIndex - 1 + searchSelections.count) % searchSelections.count
        searchNavigationID += 1
    }

    private func showNextSearchMatch() {
        guard !searchSelections.isEmpty else {
            return
        }
        selectedSearchMatchIndex = (selectedSearchMatchIndex + 1) % searchSelections.count
        searchNavigationID += 1
    }

    private var toolbar: some View {
        HStack(spacing: 13) {
            Button {
                appState.activeDocument = nil
            } label: {
                Label("返回资料库", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.deepIndigo)

            Rectangle()
                .fill(AppTheme.coolGray)
                .frame(width: 1, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.documentItem.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text("PDF 阅读器")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            Spacer()

            toolbarButton("chevron.left", help: "上一页") {
                viewModel.showPreviousPage()
            }

            HStack(spacing: 4) {
                TextField("页码", text: $pageNumberInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(width: 38)
                    .onSubmit {
                        goToPageNumber()
                    }

                Text("/ \(viewModel.pageCount)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .help("输入页码后按回车跳转")

            toolbarButton("chevron.right", help: "下一页") {
                viewModel.showNextPage()
            }

            Rectangle()
                .fill(AppTheme.coolGray)
                .frame(width: 1, height: 22)

            toolbarButton("minus.magnifyingglass", help: "缩小") {
                viewModel.zoomOut()
            }
            toolbarButton("plus.magnifyingglass", help: "放大") {
                viewModel.zoomIn()
            }

            Button {
                Task {
                    await appState.summarizeActiveDocument()
                }
            } label: {
                Label("生成摘要", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(appState.isSummarizing)

            Button {
                generateSelectionCardDraft()
            } label: {
                HStack {
                    if appState.isGeneratingSelectionCard {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Label("AI 智能制卡", systemImage: "sparkles.rectangle.stack")
                }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isGeneratingSelectionCard)
            .opacity(selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.48 : 1)
            .help(selectedText.isEmpty ? "请先在 PDF 中选择文本" : "根据选区生成可编辑知识卡片")

            secondaryActionsMenu
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 17)
        .frame(height: 56)
        .background(AppTheme.warmWhite)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.coolGray).frame(height: 1)
        }
    }

    private var secondaryActionsMenu: some View {
        Menu {
            Button("按原文保存摘录", systemImage: "quote.opening") {
                showsExcerptEditor = true
            }
            .disabled(selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("添加批注", systemImage: "text.bubble") {
                showsAnnotationEditor = true
            }
            .disabled(selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Divider()

            Button("提取当前页文本", systemImage: "text.viewfinder") {
                viewModel.extractCurrentPage()
                appState.extractedPageText = viewModel.extractedPageText
                appState.inspectorPageNumber = viewModel.currentPageIndex + 1
                appState.extractionMessage = viewModel.extractionMessage
            }
            Button("重置缩放", systemImage: "arrow.counterclockwise") {
                viewModel.resetZoom()
            }
            Button(
                viewModel.documentItem.readingState == .completed ? "标记为阅读中" : "标记为已读",
                systemImage: viewModel.documentItem.readingState == .completed ? "book" : "checkmark.circle"
            ) {
                readingProgressService.toggleCompleted(viewModel.documentItem)
                try? modelContext.save()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.slateBlue)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("更多阅读操作")
    }

    private func toolbarButton(
        _ symbolName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.slateBlue)
                .frame(width: 28, height: 28)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(AppTheme.coolGray, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func syncInspectorPage() {
        let pageNumber = viewModel.currentPageIndex + 1
        appState.inspectorPageNumber = pageNumber
        appState.extractedPageText = ""
        appState.extractionMessage = nil
        readingProgressService.updatePDFProgress(
            viewModel.documentItem,
            pageNumber: pageNumber
        )
        try? modelContext.save()
    }

    private func syncPageNumberInput() {
        pageNumberInput = viewModel.pageCount == 0
            ? "0"
            : "\(viewModel.currentPageIndex + 1)"
    }

    private func goToPageNumber() {
        if !viewModel.goToPageNumber(pageNumberInput) {
            syncPageNumberInput()
        }
    }

    private func syncInspectorSelection() {
        appState.updateSelectedText(selectedText, pageNumber: selectedPageNumber)
    }

    private func generateSelectionCardDraft() {
        Task {
            editingAISmartDraft = await appState.generateSelectedTextCardDraft()
        }
    }

    private func navigateToRequestedPDFPage() {
        guard let pageNumber = appState.requestedPDFPageNumber else {
            return
        }
        viewModel.currentPageIndex = ReaderViewModel.pageIndex(
            forRequestedPageNumber: pageNumber,
            pageCount: viewModel.pageCount
        )
    }
}

private struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    @Binding var zoomScale: CGFloat
    @Binding var selectedText: String
    @Binding var selectionPageNumber: Int?
    let annotationSelections: [PDFSelection]
    let highlightedSelections: [PDFSelection]
    let searchSelection: PDFSearchSelection?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.minScaleFactor = 0.5
        pdfView.maxScaleFactor = 3

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: pdfView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: Notification.Name.PDFViewSelectionChanged,
            object: pdfView
        )
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self

        if pdfView.document !== document {
            pdfView.document = document
        }

        if let page = document.page(at: currentPageIndex), pdfView.currentPage !== page {
            pdfView.go(to: page)
        }

        if abs(pdfView.scaleFactor - zoomScale) > 0.01 {
            pdfView.scaleFactor = zoomScale
        }

        for selection in annotationSelections {
            selection.color = NSColor.systemPurple.withAlphaComponent(0.24)
        }
        for selection in highlightedSelections {
            selection.color = NSColor.systemYellow.withAlphaComponent(0.32)
        }
        searchSelection?.selection.color = NSColor.systemOrange.withAlphaComponent(0.52)
        pdfView.highlightedSelections = annotationSelections + highlightedSelections

        guard
            let searchSelection,
            context.coordinator.appliedSearchNavigationID != searchSelection.navigationID
        else {
            return
        }

        context.coordinator.appliedSearchNavigationID = searchSelection.navigationID
        pdfView.go(to: searchSelection.selection)
    }

    static func dismantleNSView(_ pdfView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(
            coordinator,
            name: Notification.Name.PDFViewPageChanged,
            object: pdfView
        )
        NotificationCenter.default.removeObserver(
            coordinator,
            name: Notification.Name.PDFViewSelectionChanged,
            object: pdfView
        )
    }

    final class Coordinator: NSObject {
        var parent: PDFKitView
        var appliedSearchNavigationID: Int?

        init(parent: PDFKitView) {
            self.parent = parent
        }

        @objc
        func pageChanged(_ notification: Notification) {
            guard
                let pdfView = notification.object as? PDFView,
                let currentPage = pdfView.currentPage,
                let document = pdfView.document
            else {
                return
            }

            let pageIndex = document.index(for: currentPage)
            if parent.currentPageIndex != pageIndex {
                parent.currentPageIndex = pageIndex
            }
        }

        @objc
        func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else {
                return
            }

            let selection = pdfView.currentSelection
            let text = selection?.string?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let pageNumber = selection?.pages.first.flatMap { page in
                pdfView.document.map { $0.index(for: page) + 1 }
            }

            if parent.selectedText != text {
                parent.selectedText = text
            }
            if parent.selectionPageNumber != pageNumber {
                parent.selectionPageNumber = pageNumber
            }
        }
    }
}

private struct PDFSearchSelection {
    let navigationID: Int
    let selection: PDFSelection
}
