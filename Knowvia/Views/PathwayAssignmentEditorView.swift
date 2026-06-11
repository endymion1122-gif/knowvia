import SwiftUI

struct PathwayAssignmentEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let document: DocumentItem
    let pathways: [KnowledgePathway]
    let onSave: (Set<UUID>) -> Void

    @State private var selectedPathwayIDs: Set<UUID>

    init(
        document: DocumentItem,
        pathways: [KnowledgePathway],
        onSave: @escaping (Set<UUID>) -> Void
    ) {
        self.document = document
        self.pathways = pathways
        self.onSave = onSave
        _selectedPathwayIDs = State(initialValue: Set(document.pathwayIDs))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("加入专题路径")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(document.title)
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
                    onSave(selectedPathwayIDs)
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

            if pathways.isEmpty {
                ContentUnavailableView(
                    "还没有专题路径",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    description: Text("先从 Sidebar 进入“专题路径库”，创建第一条路径。")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(pathways) { pathway in
                            Button {
                                toggle(pathway.id)
                            } label: {
                                HStack(spacing: 10) {
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
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(pathway.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(AppTheme.primaryText)
                                        Text(pathway.overview.isEmpty ? "尚未填写专题总览" : pathway.overview)
                                            .font(.system(size: 11))
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .lineLimit(2)
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
        .frame(width: 620, height: 580)
        .background(AppTheme.pageBackground)
    }

    private func toggle(_ pathwayID: UUID) {
        if selectedPathwayIDs.contains(pathwayID) {
            selectedPathwayIDs.remove(pathwayID)
        } else {
            selectedPathwayIDs.insert(pathwayID)
        }
    }
}
