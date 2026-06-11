import SwiftUI

struct KnowledgeCardCalibrationEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let card: KnowledgeCard
    let onSave: (KnowledgeCardCalibrationStatus, Bool, Bool, String) -> Void

    @State private var status: KnowledgeCardCalibrationStatus
    @State private var isHighlighted: Bool
    @State private var isUnderstood: Bool
    @State private var note: String

    init(
        card: KnowledgeCard,
        onSave: @escaping (KnowledgeCardCalibrationStatus, Bool, Bool, String) -> Void
    ) {
        self.card = card
        self.onSave = onSave
        _status = State(initialValue: card.calibrationState)
        _isHighlighted = State(initialValue: card.isHighlighted)
        _isUnderstood = State(initialValue: card.isUnderstood)
        _note = State(initialValue: card.calibrationNote)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("校准知识节点")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(card.title)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.pathTeal)
                        .lineLimit(1)
                }

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)

                Button("保存") {
                    onSave(status, isHighlighted, isUnderstood, note)
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

            VStack(alignment: .leading, spacing: 16) {
                field("校准状态") {
                    Picker("校准状态", selection: $status) {
                        ForEach(KnowledgeCardCalibrationStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                Toggle("标为重点节点", isOn: $isHighlighted)
                    .toggleStyle(.switch)

                Toggle("我已经理解这个节点", isOn: $isUnderstood)
                    .toggleStyle(.switch)

                field("校准备注") {
                    TextEditor(text: $note)
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

                Text("校准用于保留你的判断过程：AI 草稿是起点，确认、重点和个人理解由你决定。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(18)
        }
        .frame(width: 580, height: 470)
        .background(AppTheme.pageBackground)
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
