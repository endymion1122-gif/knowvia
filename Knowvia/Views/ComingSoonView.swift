import SwiftUI

struct ComingSoonView: View {
    let destination: SidebarDestination

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: destination.symbolName)
                .font(.system(size: 27))
                .foregroundStyle(AppTheme.softViolet)
                .frame(width: 68, height: 68)
                .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 19))

            Text(destination.title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            Text("长期概念储备")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.pathTeal)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.paleMint, in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.pageBackground)
    }

    private var description: String {
        switch destination {
        case .pathways:
            "围绕理论、课程或研究问题组织多源资料与知识脉络。"
        case .cards:
            "把阅读摘录、笔记和摘要沉淀为可复用的知识卡片。"
        case .graph:
            "知识图谱保留为长期视觉方向，当前不作为重开发入口。"
        case .writing:
            "写作辅助属于研究生场景的后续拓展，当前暂缓开发。"
        case .learningPath:
            "将卡片逐步连接成轻量学习路径。当前保留概念，不做复杂图谱。"
        case .settings:
            "后续将在这里配置本地资料路径与 BYOK 模型服务。"
        default:
            "该功能保留为长期概念储备。"
        }
    }
}
