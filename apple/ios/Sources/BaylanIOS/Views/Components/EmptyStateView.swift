import SwiftUI
import BaylanCore

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: BaylanSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(BaylanTheme.textTertiary)
                .symbolEffect(.pulse)

            VStack(spacing: BaylanSpacing.xs) {
                Text(title)
                    .font(BaylanTypography.title3)
                    .foregroundStyle(BaylanTheme.textPrimary)

                Text(message)
                    .font(BaylanTypography.subheadline)
                    .foregroundStyle(BaylanTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(BaylanSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
