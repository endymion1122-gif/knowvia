import AppKit
import SwiftData
import SwiftUI

struct TextPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \DocumentAnnotation.updatedAt, order: .reverse) private var annotations: [DocumentAnnotation]
    let document: DocumentItem

    @State private var text = ""
    @State private var selectedText = ""
    @State private var searchText = ""
    @State private var searchMatches: [NSRange] = []
    @State private var selectedSearchMatchIndex = 0
    @State private var searchNavigationID = 0
    @State private var showsExcerptEditor = false
    @State private var showsAnnotationEditor = false
    @State private var editingAISmartDraft: KnowledgeCardDraft?
    @State private var annotationNavigationSelection: TextSearchSelection?
    @State private var annotationNavigationID = 0
    private let previewService = TextFilePreviewService()
    private let searchService = TextDocumentSearchService()
    private let readingProgressService = DocumentReadingProgressService()
    private let annotationHighlightService = AnnotationHighlightService()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            searchBar

            VStack(alignment: .leading, spacing: 15) {
                Text(document.title)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)

                SelectableDocumentTextView(
                    text: text,
                    selectedText: $selectedText,
                    annotationRanges: annotationRanges,
                    searchMatches: searchMatches,
                    navigationSelection: annotationNavigationSelection ?? activeSearchSelection
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.coolGray, lineWidth: 1)
                    }
            }
            .frame(maxWidth: 860, maxHeight: .infinity, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.pageBackground)
        .sheet(isPresented: $showsExcerptEditor) {
            KnowledgeCardEditorView(
                sourceDocument: document,
                initialContent: selectedText
            )
        }
        .sheet(isPresented: $showsAnnotationEditor) {
            AnnotationEditorView(
                document: document,
                selectedText: selectedText
            )
        }
        .sheet(item: $editingAISmartDraft) { draft in
            KnowledgeCardEditorView(
                sourceDocument: document,
                initialTitle: draft.title,
                initialContent: draft.content,
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
            text = previewService.loadText(from: document.fileURL)
            if document.extractedText?.isEmpty ?? true {
                document.extractedText = text
                try? modelContext.save()
            }
            navigateToRequestedTextAnchor()
        }
        .onChange(of: selectedText) {
            appState.updateSelectedText(selectedText, pageNumber: nil)
        }
        .onChange(of: searchText) {
            annotationNavigationSelection = nil
            updateSearchMatches()
        }
        .onChange(of: appState.requestedTextAnchorID) {
            navigateToRequestedTextAnchor()
        }
        .onDisappear {
            appState.updateSelectedText("", pageNumber: nil)
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

            TextField("在正文中搜索", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit {
                    showNextSearchMatch()
                }

            if !searchText.isEmpty {
                Text(searchResultLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(searchMatches.isEmpty ? AppTheme.softPlum : AppTheme.secondaryText)

                Button {
                    showPreviousSearchMatch()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(searchMatches.isEmpty)
                .help("上一个搜索结果")

                Button {
                    showNextSearchMatch()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(searchMatches.isEmpty)
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

    private var activeSearchSelection: TextSearchSelection? {
        guard searchMatches.indices.contains(selectedSearchMatchIndex) else {
            return nil
        }
        return TextSearchSelection(
            navigationID: searchNavigationID,
            range: searchMatches[selectedSearchMatchIndex]
        )
    }

    private var annotationRanges: [NSRange] {
        annotationHighlightService.textRanges(
            for: annotations.filter { $0.documentId == document.id },
            in: text
        )
    }

    private var searchResultLabel: String {
        guard !searchMatches.isEmpty else {
            return "无匹配"
        }
        return "\(selectedSearchMatchIndex + 1) / \(searchMatches.count)"
    }

    private func updateSearchMatches() {
        searchMatches = searchService.matches(for: searchText, in: text)
        selectedSearchMatchIndex = 0
        searchNavigationID += 1
    }

    private func showPreviousSearchMatch() {
        guard !searchMatches.isEmpty else {
            return
        }
        selectedSearchMatchIndex = (selectedSearchMatchIndex - 1 + searchMatches.count) % searchMatches.count
        searchNavigationID += 1
    }

    private func showNextSearchMatch() {
        guard !searchMatches.isEmpty else {
            return
        }
        selectedSearchMatchIndex = (selectedSearchMatchIndex + 1) % searchMatches.count
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
                    Text(document.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Text("文本阅读器")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                Spacer()

                Text(document.displayFileType)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.pathTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.paleMint, in: Capsule())

                Button {
                    readingProgressService.toggleCompleted(document)
                    try? modelContext.save()
                } label: {
                    Label(
                        document.readingState == .completed ? "已完成" : "标记为已读",
                        systemImage: document.readingState == .completed ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(document.readingState == .completed ? AppTheme.pathTeal : AppTheme.slateBlue)
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await appState.summarizeActiveDocument()
                        try? modelContext.save()
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
                .disabled(selectedText.isEmpty || appState.isGeneratingSelectionCard)
                .opacity(selectedText.isEmpty ? 0.48 : 1)
                .help(selectedText.isEmpty ? "请先在正文中选择文本" : "根据选区生成可编辑知识卡片")

                secondaryActionsMenu
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 20)
            .frame(height: 54)
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
            .disabled(selectedText.isEmpty)

            Button("添加批注", systemImage: "text.bubble") {
                showsAnnotationEditor = true
            }
            .disabled(selectedText.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.slateBlue)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("更多制卡操作")
    }

    private func generateSelectionCardDraft() {
        Task {
            editingAISmartDraft = await appState.generateSelectedTextCardDraft()
        }
    }

    private func navigateToRequestedTextAnchor() {
        guard
            !text.isEmpty,
            let excerpt = appState.requestedTextAnchorExcerpt,
            let range = searchService.matches(for: excerpt, in: text).first
        else {
            return
        }

        annotationNavigationID += 1
        annotationNavigationSelection = TextSearchSelection(
            navigationID: 1_000_000 + annotationNavigationID,
            range: range
        )
    }
}

private struct SelectableDocumentTextView: NSViewRepresentable {
    let text: String
    @Binding var selectedText: String
    let annotationRanges: [NSRange]
    let searchMatches: [NSRange]
    let navigationSelection: TextSearchSelection?

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedText: $selectedText)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = NSColor(AppTheme.primaryText)
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.selectedText = $selectedText
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }

        context.coordinator.updateHighlights(
            annotationRanges: annotationRanges,
            searchRanges: searchMatches,
            in: textView
        )

        guard
            let navigationSelection,
            context.coordinator.appliedSearchNavigationID != navigationSelection.navigationID
        else {
            return
        }

        context.coordinator.appliedSearchNavigationID = navigationSelection.navigationID
        textView.setSelectedRange(navigationSelection.range)
        textView.scrollRangeToVisible(navigationSelection.range)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var selectedText: Binding<String>
        var appliedSearchNavigationID: Int?
        private var annotationRanges: [NSRange] = []
        private var searchRanges: [NSRange] = []

        init(selectedText: Binding<String>) {
            self.selectedText = selectedText
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            let selection = textView.selectedRange()
            let value = selection.length > 0
                ? (textView.string as NSString).substring(with: selection)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            if selectedText.wrappedValue != value {
                selectedText.wrappedValue = value
            }
        }

        func updateHighlights(
            annotationRanges: [NSRange],
            searchRanges: [NSRange],
            in textView: NSTextView
        ) {
            guard self.annotationRanges != annotationRanges || self.searchRanges != searchRanges else {
                return
            }

            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.textStorage?.removeAttribute(.backgroundColor, range: fullRange)
            for range in annotationRanges {
                textView.textStorage?.addAttribute(
                    .backgroundColor,
                    value: NSColor.systemPurple.withAlphaComponent(0.18),
                    range: range
                )
            }
            for range in searchRanges {
                textView.textStorage?.addAttribute(
                    .backgroundColor,
                    value: NSColor.systemYellow.withAlphaComponent(0.32),
                    range: range
                )
            }
            self.annotationRanges = annotationRanges
            self.searchRanges = searchRanges
        }
    }
}

private struct TextSearchSelection {
    let navigationID: Int
    let range: NSRange
}
