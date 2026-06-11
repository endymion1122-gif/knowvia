import SwiftData
import SwiftUI

struct AnnotationBatchCardReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let document: DocumentItem
    private let createdBy: String
    private let annotationCount: Int
    private let onSaved: () -> Void

    @State private var topic: String
    @State private var drafts: [EditableAnnotationBatchCardDraft]
    @State private var errorMessage: String?

    init(
        document: DocumentItem,
        bundle: AnnotationBatchKnowledgeCardBundle,
        createdBy: String,
        onSaved: @escaping () -> Void
    ) {
        self.document = document
        self.createdBy = createdBy
        annotationCount = bundle.annotationCount
        self.onSaved = onSaved
        _topic = State(initialValue: bundle.topic)
        _drafts = State(
            initialValue: bundle.drafts.map(EditableAnnotationBatchCardDraft.init)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI 批量整理批注")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("已根据 \(annotationCount) 条批注生成 3 张草稿。保存前可以逐张调整。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)

                Button("保存全部") {
                    saveAll()
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
                    VStack(alignment: .leading, spacing: 7) {
                        Text("自动主题")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.slateBlue)
                        TextField("例如：反馈循环", text: $topic)
                            .textFieldStyle(.roundedBorder)
                        Text("主题会作为三张卡片的共同标签。当前为本地轻量推断，可直接修改。")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(draft.kind.title + "卡", systemImage: symbol(for: draft.kind))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(accent(for: draft.kind))
                                Spacer()
                                Text("可编辑草稿")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.softViolet)
                            }

                            TextField("卡片标题", text: $draft.title)
                                .textFieldStyle(.roundedBorder)

                            TextEditor(text: $draft.content)
                                .font(.system(size: 12))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(minHeight: 170)
                                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(AppTheme.coolGray, lineWidth: 1)
                                }
                        }
                        .padding(12)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(accent(for: draft.kind).opacity(0.22), lineWidth: 1)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 760, height: 760)
        .background(AppTheme.pageBackground)
        .alert("无法保存批量卡片", isPresented: errorBinding) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canSave: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && drafts.allSatisfy {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func saveAll() {
        let normalizedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)

        for draft in drafts {
            let tags = Array(
                Set(
                    draft.tags
                        .filter { $0 != draft.originalTopic }
                        + [normalizedTopic]
                )
            )
            .sorted()

            modelContext.insert(
                KnowledgeCard(
                    title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: draft.content.trimmingCharacters(in: .whitespacesAndNewlines),
                    cardType: draft.kind.rawValue,
                    tags: tags,
                    sourceDocumentId: document.id,
                    sourceDocumentTitle: document.title,
                    createdBy: createdBy
                )
            )
        }

        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func symbol(for kind: KnowledgeCardKind) -> String {
        switch kind {
        case .concept:
            "sparkle"
        case .argument:
            "quote.bubble"
        case .evidence:
            "link"
        default:
            "rectangle.stack"
        }
    }

    private func accent(for kind: KnowledgeCardKind) -> Color {
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
}

private struct EditableAnnotationBatchCardDraft: Identifiable {
    let id: UUID
    let kind: KnowledgeCardKind
    let tags: [String]
    let originalTopic: String
    var title: String
    var content: String

    init(_ draft: KnowledgeCardDraft) {
        id = draft.id
        kind = draft.kind
        tags = draft.tags
        originalTopic = draft.tags.first {
            !["AI 草稿", "批注批量整理", "待核验", draft.kind.title].contains($0)
        } ?? ""
        title = draft.title
        content = draft.content
    }
}
