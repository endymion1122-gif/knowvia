import SwiftUI

struct ResearchConsentView: View {
    @Binding var participationStatusRaw: String
    var requiresDecision = true
    var allowsDeferral = false
    var onAcknowledged: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    KnowviaLogo(markSize: 42)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("参与知径 Knowvia 学习研究计划")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(AppTheme.deepIndigo)

                                Text("知情同意说明")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.softViolet)
                            }

                            Spacer()

                            if !requiresDecision {
                                Button {
                                    dismiss()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .frame(width: 28, height: 28)
                                        .background(AppTheme.coolGray.opacity(0.72), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .help("关闭")
                            }
                        }
                    }

                    consentParagraph(ResearchParticipationCopy.intro)
                    consentParagraph(ResearchParticipationCopy.collectedData)
                    consentParagraph(ResearchParticipationCopy.excludedData)
                    consentParagraph(ResearchParticipationCopy.voluntary)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(AppTheme.pathTeal)
                        Text(ResearchParticipationCopy.demoNotice)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineSpacing(3)
                    }
                    .padding(13)
                    .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(24)
            }

            HStack(spacing: 10) {
                Button("暂不参与") {
                    choose(.declined)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.coolGray.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))

                if allowsDeferral {
                    Button("稍后再说") {
                        deferDecision()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                Button("我同意参与") {
                    choose(.participating)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(18)
            .background(AppTheme.warmWhite)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppTheme.coolGray)
                    .frame(height: 1)
            }
        }
        .frame(width: 620, height: 620)
        .background(AppTheme.warmWhite)
        .interactiveDismissDisabled(requiresDecision)
    }

    private func consentParagraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.primaryText)
            .lineSpacing(5)
    }

    private func choose(_ status: ResearchParticipationStatus) {
        participationStatusRaw = status.rawValue
        onAcknowledged?()
        dismiss()
    }

    private func deferDecision() {
        onAcknowledged?()
        dismiss()
    }
}
