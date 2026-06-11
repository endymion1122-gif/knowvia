import SwiftUI

struct KnowledgeCardView: View {
    let card: KnowledgeCard
    var onOpenSource: (() -> Void)?
    var onOpenDetail: (() -> Void)?
    var onEdit: (() -> Void)?
    var onCategorize: (() -> Void)?
    var onToggleHighlighted: (() -> Void)?
    var onToggleUnderstood: (() -> Void)?
    var onConfirm: (() -> Void)?
    var onCalibrate: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 9) {
                Text(card.kind.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(background, in: Capsule())

                Spacer()

                if onOpenDetail != nil || onOpenSource != nil || onEdit != nil
                    || onCategorize != nil || onToggleHighlighted != nil
                    || onToggleUnderstood != nil || onConfirm != nil
                    || onCalibrate != nil || onDelete != nil {
                    Menu {
                        if let onOpenDetail {
                            Button("查看详情", systemImage: "rectangle.stack", action: onOpenDetail)
                        }
                        if let onOpenSource {
                            Button("打开来源", systemImage: "doc.text.magnifyingglass", action: onOpenSource)
                        }
                        if let onEdit {
                            Button("编辑", systemImage: "pencil", action: onEdit)
                        }
                        if let onCategorize {
                            Button("快捷归类", systemImage: "folder.badge.plus", action: onCategorize)
                        }
                        if let onToggleHighlighted {
                            Button(
                                card.isHighlighted ? "取消重点" : "标为重点",
                                systemImage: card.isHighlighted ? "star.slash" : "star",
                                action: onToggleHighlighted
                            )
                        }
                        if let onToggleUnderstood {
                            Button(
                                card.isUnderstood ? "标记为未理解" : "标记已理解",
                                systemImage: card.isUnderstood ? "circle.dashed" : "checkmark.circle",
                                action: onToggleUnderstood
                            )
                        }
                        if let onConfirm, card.calibrationState != .confirmed {
                            Button("确认节点", systemImage: "checkmark.seal", action: onConfirm)
                        }
                        if let onCalibrate {
                            Button("详细校准", systemImage: "slider.horizontal.3", action: onCalibrate)
                        }
                        if let onDelete {
                            Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .frame(width: 24, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }

            Text(card.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)
                .lineLimit(2)

            Text(card.content)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
                .lineLimit(5)

            calibrationBadges

            if let sourceDescription = card.sourceDescription {
                Label(sourceDescription, systemImage: "doc.text")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.pathTeal)
                    .lineLimit(1)
            }

            if !card.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(Array(card.tags.prefix(3)), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.slateBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.coolGray.opacity(0.72), in: Capsule())
                    }
                }
            }

            if let onOpenDetail {
                Button(action: onOpenDetail) {
                    HStack {
                        Text("查看卡片")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(accent.opacity(0.24), lineWidth: 1)
        }
    }

    private var calibrationBadges: some View {
        HStack(spacing: 5) {
            Text(card.calibrationState.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(calibrationAccent)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(calibrationAccent.opacity(0.12), in: Capsule())

            if card.isHighlighted {
                Label("重点", systemImage: "star.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.amberAccent)
            }

            if card.isUnderstood {
                Label("已理解", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.pathTeal)
            }
        }
    }

    private var calibrationAccent: Color {
        switch card.calibrationState {
        case .pendingReview: AppTheme.softViolet
        case .confirmed: AppTheme.pathTeal
        case .needsFollowUp: AppTheme.softPlum
        }
    }

    private var accent: Color {
        switch card.kind {
        case .concept: AppTheme.deepIndigo
        case .quote, .note: AppTheme.slateBlue
        case .summary: AppTheme.softViolet
        case .method, .question: AppTheme.knowledgeBlue
        case .argument: AppTheme.softPlum
        case .evidence: AppTheme.pathTeal
        case .reflection: AppTheme.softPlum
        }
    }

    private var background: Color {
        switch card.kind {
        case .summary: AppTheme.paleLavender
        case .evidence: AppTheme.paleMint
        case .reflection: AppTheme.warmIvory
        default: AppTheme.coolGray.opacity(0.72)
        }
    }
}
