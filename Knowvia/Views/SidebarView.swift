import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KnowviaLogo(markSize: 34)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)

            sidebarSection("知识路径", destinations: [.dashboard, .pathways])
            sidebarSection("阅读与沉淀", destinations: [.recent, .library, .cards])
            sidebarSection("输出迁移", destinations: [.learningPath])

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text("知行星舱旗下知识学习产品线")
                Text("Knowledge Pathway 主线")
                    .foregroundStyle(AppTheme.pathTeal)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(AppTheme.tertiaryText)
            .padding(.horizontal, 17)
            .padding(.bottom, 14)

            sidebarButton(for: .settings)
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
        }
        .background(AppTheme.warmWhite)
    }

    private func sidebarSection(
        _ title: String,
        destinations: [SidebarDestination]
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.horizontal, 17)
                .padding(.top, 8)

            ForEach(destinations) { destination in
                sidebarButton(for: destination)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 14)
    }

    private func sidebarButton(for destination: SidebarDestination) -> some View {
        let isSelected = appState.selection == destination && appState.activeDocument == nil

        return Button {
            appState.select(destination)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: destination.symbolName)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? AppTheme.softViolet : AppTheme.slateBlue)
                    .frame(width: 17)

                Text(destination.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

                Spacer()

                if !destination.isAvailable {
                    Text("概念储备")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .foregroundStyle(isSelected ? AppTheme.deepIndigo : AppTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AppTheme.paleLavender.opacity(0.72) : .clear)
            }
        }
        .buttonStyle(.plain)
    }
}
