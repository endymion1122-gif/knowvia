import SwiftUI

/// A hierarchical view that shows claims with their supporting evidence indented beneath,
/// forming readable evidence trails with calibration status and source traceability indicators.
struct ClaimEvidenceChainView: View {
    let pairs: [ClaimEvidencePair]
    var onTapCard: ((KnowledgeCard) -> Void)?

    var body: some View {
        if pairs.isEmpty {
            Text("还没有观点—证据链。将证据节点与观点节点建立“支持”关系后，这里会形成可回溯的证据链。")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(pairs.enumerated()), id: \.element.id) { index, pair in
                    chainRow(pair)
                    if index < pairs.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    // MARK: - Chain Row

    private func chainRow(_ pair: ClaimEvidencePair) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Claim (primary node)
            claimNode(pair.claim)

            // Connector
            HStack(spacing: 6) {
                Rectangle()
                    .fill(AppTheme.pathTeal.opacity(0.3))
                    .frame(width: 2)
                    .padding(.leading, 20)

                Label("由证据支持", systemImage: "arrow.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.pathTeal)
            }

            // Evidence (secondary node, indented)
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(AppTheme.pathTeal.opacity(0.2))
                    .frame(width: 2)
                    .padding(.leading, 20)

                VStack(alignment: .leading, spacing: 4) {
                    evidenceNode(pair.evidence)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    // MARK: - Claim Node

    private func claimNode(_ card: KnowledgeCard) -> some View {
        Button {
            onTapCard?(card)
        } label: {
            HStack(spacing: 8) {
                // Type badge
                Text(card.kind.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.softPlum)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.softPlum.opacity(0.1), in: Capsule())

                Text(card.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)

                Spacer()

                // Calibration status
                calibrationBadge(card)

                // Source traceability warning
                if card.sourceDocumentId == nil {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.orange)
                        .help("缺少来源追溯")
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.softPlum.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Evidence Node

    private func evidenceNode(_ card: KnowledgeCard) -> some View {
        Button {
            onTapCard?(card)
        } label: {
            HStack(spacing: 8) {
                Text(card.kind.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.pathTeal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.pathTeal.opacity(0.1), in: Capsule())

                Text(card.title)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)

                Spacer()

                calibrationBadge(card)

                if card.sourceDocumentId == nil {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.orange)
                        .help("缺少来源追溯")
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppTheme.pathTeal.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Calibration Badge

    private func calibrationBadge(_ card: KnowledgeCard) -> some View {
        let state = card.calibrationState
        if state == .pendingReview && !card.isHighlighted {
            return AnyView(EmptyView())
        }
        return AnyView(
            Text(state.title)
                .font(.system(size: 9))
                .foregroundStyle(calibrationColor(state))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(calibrationColor(state).opacity(0.1), in: Capsule())
        )
    }

    private func calibrationColor(_ state: KnowledgeCardCalibrationStatus) -> Color {
        switch state {
        case .confirmed: AppTheme.pathTeal
        case .needsFollowUp: Color.orange
        case .pendingReview: AppTheme.tertiaryText
        }
    }
}
