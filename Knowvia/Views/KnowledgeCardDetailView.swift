import SwiftUI

struct KnowledgeCardDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let card: KnowledgeCard
    var onEdit: (() -> Void)?
    var onOpenSource: (() -> Void)?
    var similarCards: [SimilarCard] = []
    var onTapSimilarCard: ((KnowledgeCard) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(card.content)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                    metadata

                    if !similarCards.isEmpty {
                        Divider()
                        similarCardsSection
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 640, height: 600)
        .background(AppTheme.pageBackground)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(card.kind.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(badgeBackground, in: Capsule())

            VStack(alignment: .leading, spacing: 5) {
                Text(card.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                    .textSelection(.enabled)

                Text("知识卡片详情")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            if let onOpenSource {
                actionButton("打开来源", symbol: "doc.text.magnifyingglass") {
                    dismiss()
                    onOpenSource()
                }
            }

            if let onEdit {
                actionButton("编辑", symbol: "pencil") {
                    dismiss()
                    onEdit()
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.coolGray.opacity(0.64), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(AppTheme.warmWhite)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("卡片信息")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            metadataRow("来源", value: card.sourceDescription ?? "未关联资料")
            metadataRow("创建方式", value: createdByTitle)
            metadataRow("校准状态", value: card.calibrationState.title)
            metadataRow("学习标记", value: learningMarkers)
            metadataRow(
                "更新时间",
                value: card.updatedAt.formatted(date: .abbreviated, time: .shortened)
            )

            if !card.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("标签")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.slateBlue)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 68), spacing: 7)],
                        alignment: .leading,
                        spacing: 7
                    ) {
                        ForEach(card.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.slateBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.coolGray.opacity(0.72), in: Capsule())
                        }
                    }
                }
            }

            if !card.calibrationNote.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("校准备注")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.slateBlue)
                    Text(card.calibrationNote)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private var learningMarkers: String {
        var markers: [String] = []
        if card.isHighlighted {
            markers.append("重点")
        }
        if card.isUnderstood {
            markers.append("已理解")
        }
        return markers.isEmpty ? "未标记" : markers.joined(separator: "，")
    }

    private var createdByTitle: String {
        switch card.createdBy {
        case "ai":
            "AI 辅助"
        case "ai-demo", "demo-experience":
            "本地示例"
        default:
            "手动创建"
        }
    }

    private var accent: Color {
        switch card.kind {
        case .concept:
            AppTheme.deepIndigo
        case .quote, .note:
            AppTheme.slateBlue
        case .summary:
            AppTheme.softViolet
        case .method, .question:
            AppTheme.knowledgeBlue
        case .argument, .reflection:
            AppTheme.softPlum
        case .evidence:
            AppTheme.pathTeal
        }
    }

    private var badgeBackground: Color {
        switch card.kind {
        case .summary:
            AppTheme.paleLavender
        case .evidence:
            AppTheme.paleMint
        case .reflection:
            AppTheme.warmIvory
        default:
            AppTheme.coolGray.opacity(0.72)
        }
    }

    private func actionButton(
        _ title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private var similarCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("相关概念")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            ForEach(similarCards) { similar in
                Button {
                    dismiss()
                    onTapSimilarCard?(similar.card)
                } label: {
                    HStack(spacing: 8) {
                        Text(similar.card.kind.title)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppTheme.softViolet)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.paleLavender, in: Capsule())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(similar.card.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(1)

                            if hasCrossPathwaySimilarCard(similar) {
                                Text("跨路径关联")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.pathTeal)
                            }
                        }

                        Spacer()

                        Text(String(format: "%.0f%%", similar.score * 100))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .padding(10)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.coolGray.opacity(0.5), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private func hasCrossPathwaySimilarCard(_ similar: SimilarCard) -> Bool {
        let sourcePathways = Set(card.pathwayIDs)
        let targetPathways = Set(similar.card.pathwayIDs)
        return sourcePathways.isDisjoint(with: targetPathways)
            && !sourcePathways.isEmpty
            && !targetPathways.isEmpty
    }

    private func metadataRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.slateBlue)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
                .textSelection(.enabled)
        }
    }
}
