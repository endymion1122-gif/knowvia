import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let symbolName: String
    var accent = AppTheme.deepIndigo

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: symbolName)
                    .font(.system(size: 13))
                    .foregroundStyle(accent)
                    .frame(width: 29, height: 29)
                    .background(accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))

                Spacer()
            }

            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }
}
