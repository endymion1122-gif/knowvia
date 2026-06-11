import SwiftUI

struct DocumentRow: View {
    let document: DocumentItem
    let action: () -> Void
    var onEdit: (() -> Void)?
    var onManagePathways: (() -> Void)?
    var onToggleCompleted: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 12) {
                    documentSummary

                    Spacer()

                    if !document.tags.isEmpty {
                        Text(document.tags[0])
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.slateBlue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(AppTheme.coolGray.opacity(0.72), in: Capsule())
                    }

                    Text(document.readingProgressDescription)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(statusAccent.opacity(0.10), in: Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .buttonStyle(.plain)

            if onEdit != nil || onManagePathways != nil || onToggleCompleted != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button("编辑资料信息", systemImage: "pencil", action: onEdit)
                    }
                    if let onManagePathways {
                        Button("加入专题路径", systemImage: "point.topleft.down.curvedto.point.bottomright.up", action: onManagePathways)
                    }
                    if let onToggleCompleted {
                        Button(
                            document.readingState == .completed ? "标记为阅读中" : "标记为已读",
                            systemImage: document.readingState == .completed ? "book" : "checkmark.circle",
                            action: onToggleCompleted
                        )
                    }
                    if let onDelete {
                        Button("删除资料", systemImage: "trash", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(11)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private var documentSummary: some View {
        HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.system(size: 16))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 42)
                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    Text(document.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    HStack(spacing: 7) {
                        Text(document.sourceType.title)
                        Text("·")
                        Text(document.displayFileType)
                        if let attribution = document.attributionDescription {
                            Text("·")
                            Text(attribution)
                                .lineLimit(1)
                        } else {
                            Text("·")
                            Text(document.importedAt.formatted(date: .abbreviated, time: .omitted))
                        }
                        if let pageCount = document.pageCount {
                            Text("·")
                            Text("\(pageCount) 页")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiaryText)
                }

        }
    }

    private var symbolName: String {
        if document.sourceType == .webPage {
            return "link"
        }
        return switch document.fileType.lowercased() {
        case "pdf": "doc.richtext"
        case "md": "text.document"
        default: "doc.text"
        }
    }

    private var accent: Color {
        if document.sourceType == .webPage {
            return AppTheme.pathTeal
        }
        return switch document.fileType.lowercased() {
        case "pdf": AppTheme.softViolet
        case "md": AppTheme.pathTeal
        default: AppTheme.knowledgeBlue
        }
    }

    private var statusAccent: Color {
        switch document.readingState {
        case .unread: AppTheme.tertiaryText
        case .reading: AppTheme.orbitBlue
        case .completed: AppTheme.pathTeal
        }
    }
}
