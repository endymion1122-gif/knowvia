import SwiftUI

struct CardReviewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    let cards: [KnowledgeCard]
    var onSave: (() -> Void)?

    @State private var currentIndex = 0
    @State private var isRevealed = false
    @State private var isComplete = false
    @State private var reviewedCount = 0

    private let reviewService = CardReviewService()

    private var currentCard: KnowledgeCard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("卡片复习")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("主动回忆 · 间隔复习")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.pathTeal)
                }
                Spacer()

                // Progress indicator
                Text("\(min(currentIndex + 1, cards.count)) / \(cards.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.paleLavender, in: Capsule())

                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(20)

            Divider()

            if isComplete {
                completionView
            } else if let card = currentCard {
                reviewContent(for: card)
            }
        }
        .frame(width: 560, height: 520)
        .background(AppTheme.pageBackground)
    }

    // MARK: - Review Content

    @ViewBuilder
    private func reviewContent(for card: KnowledgeCard) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Card display area
            VStack(spacing: 16) {
                // Type badge
                Text(card.kind.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.paleLavender, in: Capsule())

                // Title (always visible)
                Text(card.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)

                // Tags
                if !card.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(card.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.pathTeal)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.paleMint, in: Capsule())
                        }
                    }
                }

                Divider()
                    .frame(width: 120)

                // Content (revealed or hidden)
                if isRevealed {
                    ScrollView {
                        Text(card.content)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)

                    // Source info
                    if let source = card.sourceDescription {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                            Text(source)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(AppTheme.tertiaryText)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.coolGray)
                        Text("点击下方按钮揭示内容")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .frame(height: 140)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.coolGray, lineWidth: 1)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Action buttons
            if !isRevealed {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isRevealed = true
                    }
                } label: {
                    Label("揭示内容", systemImage: "eye")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 16) {
                    ForEach(ReviewRating.allCases, id: \.self) { rating in
                        ratingButton(rating)
                    }
                }
            }

            Spacer()
        }
    }

    private func ratingButton(_ rating: ReviewRating) -> some View {
        Button {
            reviewService.scheduleReview(currentCard!, rating: rating)
            reviewedCount += 1
            onSave?()

            if currentIndex + 1 < cards.count {
                currentIndex += 1
                isRevealed = false
            } else {
                isComplete = true
            }
        } label: {
            VStack(spacing: 4) {
                Text(rating.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(ratingColor(rating))
            .frame(width: 90)
            .padding(.vertical, 12)
            .background(ratingColor(rating).opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(ratingColor(rating).opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func ratingColor(_ rating: ReviewRating) -> Color {
        switch rating {
        case .easy: AppTheme.pathTeal
        case .medium: AppTheme.softViolet
        case .hard: Color.orange
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.softViolet)
                .padding(24)
                .background(AppTheme.paleLavender, in: Circle())

            Text("本轮复习完成")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            Text("已复习 \(reviewedCount) 张卡片")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)

            let dueCount = reviewService.dueCards(in: cards).count
            if dueCount > 0 {
                Text("还有 \(dueCount) 张卡片待复习")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.pathTeal)
            } else {
                Text("全部卡片已复习完毕，继续保持！")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.pathTeal)
            }

            Button("完成") {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 9))

            Spacer()
        }
    }
}
