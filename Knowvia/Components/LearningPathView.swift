import SwiftUI

struct LearningPathView: View {
    private let steps = [
        ("开始", "设定学习目标"),
        ("基础认知", "理解核心概念"),
        ("刻意实践", "建立可持续行动"),
        ("融会贯通", "形成自己的知识体系"),
        ("分享输出", "让知识产生影响"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("你的学习路径")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("让每一次阅读，都成为长期积累的一部分。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.pathTeal)
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 7) {
                        ZStack {
                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(index == 0 ? AppTheme.pathTeal : AppTheme.coolGray)
                                    .frame(height: 2)
                                    .frame(maxWidth: .infinity)
                                    .offset(x: 48)
                            }
                            Circle()
                                .fill(index == 0 ? AppTheme.deepIndigo : AppTheme.cardBackground)
                                .stroke(index == 0 ? AppTheme.deepIndigo : AppTheme.coolGray, lineWidth: 2)
                                .frame(width: 16, height: 16)
                        }
                        .frame(height: 16)

                        Text(step.0)
                            .font(.system(size: 11, weight: index == 0 ? .semibold : .regular))
                            .foregroundStyle(index == 0 ? AppTheme.deepIndigo : AppTheme.secondaryText)
                        Text(step.1)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 98)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(AppTheme.warmIvory, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }
}
