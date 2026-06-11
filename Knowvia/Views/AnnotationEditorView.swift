import SwiftData
import SwiftUI

struct AnnotationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let annotation: DocumentAnnotation?
    private let document: DocumentItem
    private let selectedText: String
    private let pageNumber: Int?

    @State private var note: String
    @State private var errorMessage: String?

    init(
        annotation: DocumentAnnotation? = nil,
        document: DocumentItem,
        selectedText: String,
        pageNumber: Int? = nil
    ) {
        self.annotation = annotation
        self.document = document
        self.selectedText = annotation?.selectedText ?? selectedText
        self.pageNumber = annotation?.pageNumber ?? pageNumber
        _note = State(initialValue: annotation?.note ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(annotation == nil ? "添加批注" : "编辑批注")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(sourceDescription)
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

            VStack(alignment: .leading, spacing: 16) {
                field("原文选区") {
                    ScrollView {
                        Text(selectedText)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondaryText)
                            .textSelection(.enabled)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 120)
                    .padding(10)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(AppTheme.coolGray, lineWidth: 1)
                    }
                }

                field("批注内容") {
                    TextEditor(text: $note)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 190)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(AppTheme.coolGray, lineWidth: 1)
                        }
                }

                Text("批注会保存在本机。之后可以从 Reader 右侧列表回到对应原文位置。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
            }
            .padding(20)
        }
        .frame(width: 600, height: 570)
        .background(AppTheme.pageBackground)
        .alert("无法保存批注", isPresented: errorBinding) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canSave: Bool {
        !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sourceDescription: String {
        guard let pageNumber else {
            return document.title
        }
        return "\(document.title)，p.\(pageNumber)"
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
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let annotation {
            annotation.note = trimmedNote
            annotation.updatedAt = Date()
        } else {
            modelContext.insert(
                DocumentAnnotation(
                    documentId: document.id,
                    documentTitle: document.title,
                    selectedText: selectedText,
                    note: trimmedNote,
                    pageNumber: pageNumber
                )
            )
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
