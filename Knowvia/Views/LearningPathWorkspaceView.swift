import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LearningPathWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgeCard.createdAt, order: .reverse) private var cards: [KnowledgeCard]
    @Query(sort: \DocumentItem.importedAt, order: .reverse) private var documents: [DocumentItem]

    @State private var selectedTopic = ""
    @State private var exportFeedback: String?
    @State private var exportErrorMessage: String?
    @State private var sourceErrorMessage: String?

    private let learningPathService = LearningPathService()
    private let sourceService = KnowledgeCardSourceService()
    private let readingProgressService = DocumentReadingProgressService()

    private var topics: [String] {
        learningPathService.availableTopics(in: cards)
    }

    private var snapshot: LearningPathSnapshot {
        learningPathService.snapshot(
            for: cards,
            topic: selectedTopic.isEmpty ? nil : selectedTopic
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if cards.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        positioningCard
                        topicPicker
                        pathOverview
                        taskPreview
                        linkedCards
                    }
                    .padding(22)
                }
            }
        }
        .background(AppTheme.pageBackground)
        .alert("任务清单导出完成", isPresented: exportFeedbackBinding) {
            Button("知道了") {
                exportFeedback = nil
            }
        } message: {
            Text(exportFeedback ?? "")
        }
        .alert("无法导出任务清单", isPresented: exportErrorBinding) {
            Button("知道了") {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .alert("无法打开来源", isPresented: sourceErrorBinding) {
            Button("知道了") {
                sourceErrorMessage = nil
            }
        } message: {
            Text(sourceErrorMessage ?? "")
        }
        .onChange(of: topics) {
            if !selectedTopic.isEmpty, !topics.contains(selectedTopic) {
                selectedTopic = ""
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("学习路径")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Text("按主题连接知识卡片，并把下一步导出为可执行任务。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Button {
                exportDayCabinTasks()
            } label: {
                Label("导出一日舱任务清单", systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(snapshot.cards.isEmpty)
            .opacity(snapshot.cards.isEmpty ? 0.45 : 1)
        }
        .padding(22)
        .background(AppTheme.warmWhite)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.coolGray)
                .frame(height: 1)
        }
    }

    private var positioningCard: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.pathTeal)
                .frame(width: 42, height: 42)
                .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                Text("知径把知识理清，一日舱把事情推进。")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Text("当前为轻量概念联动：知径根据已保存卡片生成路径，并导出本地 Markdown 任务清单。暂未连接一日舱 API。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
            }
        }
        .padding(15)
        .background(AppTheme.warmIvory, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private var topicPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("主题归类")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Spacer()
                Button("整理卡片标签") {
                    appState.select(.cards)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.softViolet)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    topicButton("全部卡片", topic: "")
                    ForEach(topics, id: \.self) { topic in
                        topicButton(topic, topic: topic)
                    }
                }
            }

            if topics.isEmpty {
                Text("当前卡片还没有主题标签。路径会先基于全部卡片生成；可以回到知识卡片页补充标签。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
            }
        }
        .padding(15)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private var pathOverview: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("\(snapshot.displayTopic) · 轻量路径")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Spacer()
                Text("\(snapshot.cards.count) 张卡片")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.pathTeal)
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(snapshot.steps.enumerated()), id: \.element.id) { index, step in
                    VStack(spacing: 8) {
                        ZStack {
                            if index < snapshot.steps.count - 1 {
                                Rectangle()
                                    .fill(step.cards.isEmpty ? AppTheme.coolGray : AppTheme.pathTeal)
                                    .frame(height: 2)
                                    .frame(maxWidth: .infinity)
                                    .offset(x: 48)
                            }

                            Image(systemName: step.stage.symbolName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(step.cards.isEmpty ? AppTheme.tertiaryText : .white)
                                .frame(width: 24, height: 24)
                                .background(
                                    step.cards.isEmpty ? AppTheme.cardBackground : AppTheme.deepIndigo,
                                    in: Circle()
                                )
                                .overlay {
                                    Circle()
                                        .stroke(step.cards.isEmpty ? AppTheme.coolGray : AppTheme.deepIndigo, lineWidth: 1)
                                }
                        }
                        .frame(height: 24)

                        Text(step.stage.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                        Text(step.stage.detail)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 94)
                        Text("\(step.cards.count) 张")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(step.cards.isEmpty ? AppTheme.tertiaryText : AppTheme.pathTeal)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(17)
        .background(AppTheme.warmIvory, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private var taskPreview: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("一日舱任务草稿")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Spacer()
                Text("本地 Markdown 概念导出")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.pathTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.paleMint, in: Capsule())
            }

            ForEach(snapshot.tasks) { task in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "square")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.pathTeal)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                        Text(task.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(15)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private var linkedCards: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("路径卡片")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            if snapshot.cards.isEmpty {
                Text("当前主题下还没有卡片。可以回到知识卡片页调整标签。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(snapshot.cards) { card in
                        LinkedPathCard(card: card) {
                            openSource(for: card)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 25))
                .foregroundStyle(AppTheme.pathTeal)
                .frame(width: 62, height: 62)
                .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 18))

            Text("还没有可连接的知识卡片。")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            Text("先从阅读摘要、摘录或自己的笔记中保存卡片，再回来生成第一条轻量学习路径。")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            Button("前往知识卡片") {
                appState.select(.cards)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.deepIndigo)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var sourceErrorBinding: Binding<Bool> {
        Binding(
            get: { sourceErrorMessage != nil },
            set: { if !$0 { sourceErrorMessage = nil } }
        )
    }

    private func topicButton(_ label: String, topic: String) -> some View {
        let isSelected = selectedTopic == topic

        return Button(label) {
            selectedTopic = topic
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? AppTheme.deepIndigo : AppTheme.secondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(isSelected ? AppTheme.paleMint : AppTheme.coolGray.opacity(0.55), in: Capsule())
    }

    private func exportDayCabinTasks() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "知径 Knowvia - 一日舱任务草稿.md"
        panel.title = "导出一日舱任务清单"
        panel.message = "导出本地 Markdown 概念清单。当前尚未连接一日舱 API。"

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            try learningPathService.exportTasks(for: snapshot, to: destinationURL)
            exportFeedback = "已导出 \(snapshot.displayTopic) 的任务草稿。"
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func openSource(for card: LearningPathCardReference) {
        do {
            let document = try sourceService.sourceDocument(for: card, in: documents)
            readingProgressService.markOpened(document)
            try modelContext.save()
            appState.open(
                document,
                pageNumber: sourceService.targetPageNumber(for: card, in: document)
            )
        } catch {
            sourceErrorMessage = error.localizedDescription
        }
    }
}

private struct LinkedPathCard: View {
    let card: LearningPathCardReference
    let onOpenSource: () -> Void

    var body: some View {
        Button(action: onOpenSource) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(card.kind.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.pathTeal)
                    Spacer()
                    if card.sourceDocumentId != nil {
                        Label("查看原文", systemImage: "arrow.up.right.square")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppTheme.softViolet)
                    }
                }
                Text(card.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                    .lineLimit(2)
                if let sourceDescription = card.sourceDescription {
                    Text(sourceDescription)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(AppTheme.coolGray, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(card.sourceDocumentId == nil)
    }
}
