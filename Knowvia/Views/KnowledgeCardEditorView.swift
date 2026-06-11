import SwiftData
import SwiftUI

struct KnowledgeCardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgePathway.updatedAt, order: .reverse) private var pathways: [KnowledgePathway]

    private let card: KnowledgeCard?
    private let sourceDocumentId: UUID?
    private let createdBy: String

    @State private var title: String
    @State private var content: String
    @State private var cardType: KnowledgeCardKind
    @State private var tagsText: String
    @State private var sourceDocumentTitle: String
    @State private var pageNumberText: String
    @State private var selectedPathwayIDs: Set<UUID>
    @State private var errorMessage: String?
    private let pathwayService = KnowledgePathwayService()

    init(
        card: KnowledgeCard? = nil,
        sourceDocument: DocumentItem? = nil,
        initialTitle: String? = nil,
        initialContent: String = "",
        pageNumber: Int? = nil,
        initialKind: KnowledgeCardKind? = nil,
        initialTags: [String] = [],
        createdBy: String = "user"
    ) {
        self.card = card
        sourceDocumentId = card?.sourceDocumentId ?? sourceDocument?.id
        self.createdBy = card?.createdBy ?? createdBy

        let initialSourceTitle = card?.sourceDocumentTitle ?? sourceDocument?.title ?? ""
        let initialPageNumber = card?.pageNumber ?? pageNumber
        let initialKind = card?.kind ?? initialKind ?? (sourceDocument == nil ? .note : .quote)

        _title = State(
            initialValue: card?.title
                ?? initialTitle
                ?? Self.defaultTitle(for: initialKind, sourceTitle: initialSourceTitle)
        )
        _content = State(initialValue: card?.content ?? initialContent)
        _cardType = State(initialValue: initialKind)
        _tagsText = State(initialValue: card?.tags.joined(separator: "，") ?? initialTags.joined(separator: "，"))
        _sourceDocumentTitle = State(initialValue: initialSourceTitle)
        _pageNumberText = State(initialValue: initialPageNumber.map(String.init) ?? "")
        _selectedPathwayIDs = State(initialValue: Set(card?.pathwayIDs ?? []))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(card == nil ? "新建知识卡片" : "编辑知识卡片")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("保留内容、来源和页码，让知识可以再次被找到。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)

                Button("保存") {
                    save()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
            }
            .padding(18)
            .background(AppTheme.warmWhite)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("标题") {
                        TextField("例如：刻意练习的反馈循环", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    field("卡片类型") {
                        Picker("卡片类型", selection: $cardType) {
                            ForEach(KnowledgeCardKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    field("内容") {
                        TextEditor(text: $content)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 180)
                            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(AppTheme.coolGray, lineWidth: 1)
                            }
                    }

                    field("标签") {
                        TextField("使用逗号分隔，例如：学习方法，反馈", text: $tagsText)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        field("来源文档") {
                            TextField("可选", text: $sourceDocumentTitle)
                                .textFieldStyle(.roundedBorder)
                        }

                        field("页码") {
                            TextField("可选", text: $pageNumberText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }
                    }

                    field("专题路径") {
                        if pathways.isEmpty {
                            Text("还没有专题路径。可以先保存卡片，之后再从专题路径库归类。")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.secondaryText)
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 210), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(pathways) { pathway in
                                    Button {
                                        togglePathway(pathway.id)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(
                                                systemName: selectedPathwayIDs.contains(pathway.id)
                                                    ? "checkmark.circle.fill"
                                                    : "circle"
                                            )
                                            .foregroundStyle(
                                                selectedPathwayIDs.contains(pathway.id)
                                                    ? AppTheme.softViolet
                                                    : AppTheme.tertiaryText
                                            )
                                            Text(pathway.title)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(AppTheme.primaryText)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(8)
                                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 7)
                                                .stroke(AppTheme.coolGray, lineWidth: 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 680, height: 700)
        .background(AppTheme.pageBackground)
        .alert("无法保存知识卡片", isPresented: errorBinding) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = sourceDocumentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = tagsText
            .components(separatedBy: CharacterSet(charactersIn: ",，"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let pageNumber = Int(pageNumberText.trimmingCharacters(in: .whitespacesAndNewlines))

        if let card {
            card.title = trimmedTitle
            card.content = trimmedContent
            card.cardType = cardType.rawValue
            card.tags = tags
            card.sourceDocumentTitle = trimmedSource.isEmpty ? nil : trimmedSource
            card.pageNumber = pageNumber
            card.updatedAt = Date()
            pathwayService.updateAssignments(
                for: card,
                selectedPathwayIDs: selectedPathwayIDs,
                pathways: pathways
            )
        } else {
            let card = KnowledgeCard(
                title: trimmedTitle,
                content: trimmedContent,
                cardType: cardType.rawValue,
                tags: tags,
                sourceDocumentId: sourceDocumentId,
                sourceDocumentTitle: trimmedSource.isEmpty ? nil : trimmedSource,
                pageNumber: pageNumber,
                createdBy: createdBy
            )
            modelContext.insert(card)
            pathwayService.updateAssignments(
                for: card,
                selectedPathwayIDs: selectedPathwayIDs,
                pathways: pathways
            )
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func togglePathway(_ pathwayID: UUID) {
        if selectedPathwayIDs.contains(pathwayID) {
            selectedPathwayIDs.remove(pathwayID)
        } else {
            selectedPathwayIDs.insert(pathwayID)
        }
    }

    private static func defaultTitle(for kind: KnowledgeCardKind, sourceTitle: String) -> String {
        guard !sourceTitle.isEmpty else {
            return ""
        }
        return "\(sourceTitle) \(kind.title)"
    }
}
