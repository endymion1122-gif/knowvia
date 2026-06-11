import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct KnowledgeCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \KnowledgeCard.createdAt, order: .reverse) private var cards: [KnowledgeCard]
    @Query(sort: \DocumentItem.importedAt, order: .reverse) private var documents: [DocumentItem]
    @Query(sort: \KnowledgePathway.updatedAt, order: .reverse) private var pathways: [KnowledgePathway]
    @Query(sort: \KnowledgeRelation.updatedAt, order: .reverse) private var relations: [KnowledgeRelation]

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var layoutMode = CardLayoutMode.grid
    @State private var showsCreateCard = false
    @State private var inspectingCard: KnowledgeCard?
    @State private var editingCard: KnowledgeCard?
    @State private var calibratingCard: KnowledgeCard?
    @State private var categorizingCard: KnowledgeCard?
    @State private var pendingDeleteCard: KnowledgeCard?
    @State private var showsReviewSession = false
    @State private var errorMessage: String?
    @State private var exportFeedback: String?
    @State private var exportErrorMessage: String?

    private let markdownExportService = MarkdownExportService()
    private let topicService = KnowledgeCardTopicService()
    private let sourceService = KnowledgeCardSourceService()
    private let readingProgressService = DocumentReadingProgressService()
    private let demoExperienceService = DemoExperienceService()
    private let pathwayService = KnowledgePathwayService()
    private let relationService = KnowledgeRelationService()
    private let calibrationService = KnowledgeCardCalibrationService()

    private var allTags: [String] {
        Array(Set(cards.flatMap(\.tags))).sorted()
    }

    private var filteredCards: [KnowledgeCard] {
        cards.filter { card in
            let matchesSearch = searchText.isEmpty
                || card.title.localizedCaseInsensitiveContains(searchText)
                || card.content.localizedCaseInsensitiveContains(searchText)
            let matchesTag = selectedTag == nil || card.tags.contains(selectedTag ?? "")
            return matchesSearch && matchesTag
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if filteredCards.isEmpty {
                emptyState
            } else {
                cardsContent
            }
        }
        .background(AppTheme.pageBackground)
        .sheet(isPresented: $showsCreateCard) {
            KnowledgeCardEditorView()
        }
        .sheet(item: $inspectingCard) { card in
            KnowledgeCardDetailView(
                card: card,
                onEdit: { editingCard = card },
                onOpenSource: card.sourceDocumentId == nil ? nil : { openSource(for: card) }
            )
        }
        .sheet(item: $editingCard) { card in
            KnowledgeCardEditorView(card: card)
        }
        .sheet(item: $calibratingCard) { card in
            KnowledgeCardCalibrationEditorView(card: card) { status, isHighlighted, isUnderstood, note in
                updateCalibration(
                    for: card,
                    status: status,
                    isHighlighted: isHighlighted,
                    isUnderstood: isUnderstood,
                    note: note
                )
            }
        }
        .sheet(item: $categorizingCard) { card in
            QuickTopicEditorView(
                card: card,
                availableTopics: topicService.availableTopics(in: cards),
                selectedTopics: topicService.topics(for: card)
            ) { topics in
                saveTopics(topics, for: card)
            }
        }
        .sheet(isPresented: $showsReviewSession) {
            let due = CardReviewService().dueCards(in: Array(cards))
            CardReviewSessionView(cards: due) {
                try? modelContext.save()
            }
        }
        .alert("删除这张知识卡片？", isPresented: deleteBinding) {
            Button("取消", role: .cancel) {
                pendingDeleteCard = nil
            }
            Button("删除", role: .destructive) {
                deletePendingCard()
            }
        } message: {
            Text("删除后无法恢复。")
        }
        .alert("无法保存知识卡片", isPresented: errorBinding) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Markdown 导出完成", isPresented: exportFeedbackBinding) {
            Button("知道了") {
                exportFeedback = nil
            }
        } message: {
            Text(exportFeedback ?? "")
        }
        .alert("无法导出 Markdown", isPresented: exportErrorBinding) {
            Button("知道了") {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("知识卡片")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("把摘录、概念和反思沉淀为可复用的知识资产。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Button {
                    exportMarkdown()
                } label: {
                    Label("导出 Markdown", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(filteredCards.isEmpty)
                .opacity(filteredCards.isEmpty ? 0.45 : 1)
                .help("导出当前列表中的知识卡片")

                Button {
                    showsReviewSession = true
                } label: {
                    Label("复习模式", systemImage: "brain.head.profile")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.softViolet)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(cards.isEmpty)
                .opacity(cards.isEmpty ? 0.45 : 1)
                .help("进入间隔复习模式，主动回忆卡片内容")

                Button {
                    showsCreateCard = true
                } label: {
                    Label("新建卡片", systemImage: "plus")
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
                TextField("搜索卡片标题或内容", text: $searchText)
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

            HStack {
                Picker("卡片视图", selection: $layoutMode) {
                    ForEach(CardLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 210)

                Spacer()

                Text(layoutMode == .topics ? "同一张卡片可以归入多个主题。" : "使用标签筛选当前卡片列表。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        tagButton("全部", tag: nil)
                        ForEach(allTags, id: \.self) { tag in
                            tagButton(tag, tag: tag)
                        }
                    }
                }
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

    private var cardsContent: some View {
        ScrollView {
            if layoutMode == .grid {
                cardGrid(filteredCards)
                    .padding(20)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(topicService.groups(in: filteredCards)) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(group.topic)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.deepIndigo)
                                Text("\(group.cards.count) 张")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.pathTeal)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.paleMint, in: Capsule())
                            }

                            cardGrid(group.cards)
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private func cardGrid(_ cards: [KnowledgeCard]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 12)],
            spacing: 12
        ) {
            ForEach(cards) { card in
                KnowledgeCardView(
                    card: card,
                    onOpenSource: card.sourceDocumentId == nil ? nil : { openSource(for: card) },
                    onOpenDetail: { inspectingCard = card },
                    onEdit: { editingCard = card },
                    onCategorize: { categorizingCard = card },
                    onToggleHighlighted: { toggleHighlighted(card) },
                    onToggleUnderstood: { toggleUnderstood(card) },
                    onConfirm: { confirm(card) },
                    onCalibrate: { calibratingCard = card },
                    onDelete: { pendingDeleteCard = card }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 25))
                .foregroundStyle(AppTheme.softViolet)
                .frame(width: 62, height: 62)
                .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 18))

            Text(cards.isEmpty ? "还没有知识卡片。" : "没有匹配的知识卡片。")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            Text(
                cards.isEmpty
                    ? "你可以从 PDF 摘录、AI 摘要或自己的笔记中创建第一张卡片。"
                    : "试试调整搜索内容或标签筛选。"
            )
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.secondaryText)
            .multilineTextAlignment(.center)

            if cards.isEmpty {
                HStack(spacing: 12) {
                    Button("新建第一张卡片") {
                        showsCreateCard = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 8))

                    Button("载入示例卡片") {
                        installDemoExperience()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteCard != nil },
            set: { if !$0 { pendingDeleteCard = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var exportFeedbackBinding: Binding<Bool> {
        Binding(
            get: { exportFeedback != nil },
            set: { if !$0 { exportFeedback = nil } }
        )
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }

    private func tagButton(_ label: String, tag: String?) -> some View {
        let isSelected = selectedTag == tag

        return Button(label) {
            selectedTag = tag
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? AppTheme.deepIndigo : AppTheme.secondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(isSelected ? AppTheme.paleMint : AppTheme.coolGray.opacity(0.55), in: Capsule())
    }

    private func deletePendingCard() {
        guard let pendingDeleteCard else {
            return
        }

        pathwayService.detach(pendingDeleteCard, from: pathways)
        for relation in relationService.relations(involving: pendingDeleteCard, in: relations) {
            modelContext.delete(relation)
        }
        modelContext.delete(pendingDeleteCard)
        do {
            try modelContext.save()
            self.pendingDeleteCard = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveTopics(_ topics: [String], for card: KnowledgeCard) {
        topicService.assignTopics(topics, to: card)

        do {
            try modelContext.save()
            categorizingCard = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleHighlighted(_ card: KnowledgeCard) {
        calibrationService.toggleHighlighted(card)
        saveCalibrationChanges()
    }

    private func toggleUnderstood(_ card: KnowledgeCard) {
        calibrationService.toggleUnderstood(card)
        saveCalibrationChanges()
    }

    private func confirm(_ card: KnowledgeCard) {
        calibrationService.confirm(card)
        saveCalibrationChanges()
    }

    private func updateCalibration(
        for card: KnowledgeCard,
        status: KnowledgeCardCalibrationStatus,
        isHighlighted: Bool,
        isUnderstood: Bool,
        note: String
    ) {
        calibrationService.update(
            card,
            status: status,
            isHighlighted: isHighlighted,
            isUnderstood: isUnderstood,
            note: note
        )
        saveCalibrationChanges {
            calibratingCard = nil
        }
    }

    private func saveCalibrationChanges(onSuccess: () -> Void = {}) {
        do {
            try modelContext.save()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
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
            errorMessage = error.localizedDescription
        }
    }

    private func installDemoExperience() {
        do {
            _ = try demoExperienceService.installOrRestore(into: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "知径 Knowvia 知识卡片.md"
        panel.title = "导出 Markdown"
        panel.message = "导出当前列表中的 \(filteredCards.count) 张知识卡片。"

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            try markdownExportService.export(cards: filteredCards, to: destinationURL)
            exportFeedback = "已导出 \(filteredCards.count) 张知识卡片。"
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

private enum CardLayoutMode: String, CaseIterable, Identifiable {
    case grid
    case topics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: "卡片网格"
        case .topics: "主题分组"
        }
    }
}

private struct QuickTopicEditorView: View {
    let card: KnowledgeCard
    let availableTopics: [String]
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopics: Set<String>
    @State private var newTopic = ""

    init(
        card: KnowledgeCard,
        availableTopics: [String],
        selectedTopics: [String],
        onSave: @escaping ([String]) -> Void
    ) {
        self.card = card
        self.availableTopics = availableTopics
        self.onSave = onSave
        _selectedTopics = State(initialValue: Set(selectedTopics))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 4) {
                Text("快捷归类")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Text(card.title)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Divider()

            Text("选择已有主题")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.slateBlue)

            if availableTopics.isEmpty {
                Text("还没有主题。可以在下方创建第一个主题。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                FlowTopicButtons(
                    topics: availableTopics,
                    selectedTopics: $selectedTopics
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("新建主题")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.slateBlue)
                TextField("例如：研究方法、论文写作、核心概念", text: $newTopic)
                    .textFieldStyle(.roundedBorder)
            }

            Text("保存后，学习路径页会自动按主题整理卡片。“AI 草稿”和“待核验”等内部标签会保留。")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)

            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)

                Spacer()

                Button("保存归类") {
                    let trimmedTopic = newTopic.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedTopic.isEmpty {
                        selectedTopics.insert(trimmedTopic)
                    }
                    onSave(Array(selectedTopics))
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(20)
        .frame(width: 500)
        .background(AppTheme.pageBackground)
    }
}

private struct FlowTopicButtons: View {
    let topics: [String]
    @Binding var selectedTopics: Set<String>

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 180), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(topics, id: \.self) { topic in
                let isSelected = selectedTopics.contains(topic)

                Button {
                    if isSelected {
                        selectedTopics.remove(topic)
                    } else {
                        selectedTopics.insert(topic)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        Text(topic)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.deepIndigo : AppTheme.secondaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isSelected ? AppTheme.paleMint : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isSelected ? AppTheme.pathTeal.opacity(0.42) : AppTheme.coolGray, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
