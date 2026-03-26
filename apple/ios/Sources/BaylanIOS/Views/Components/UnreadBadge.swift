import SwiftUI
import BaylanCore

struct UnreadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(BaylanTypography.caption2)
                .fontWeight(.bold)
                .foregroundStyle(BaylanTheme.background)
                .padding(.horizontal, count > 9 ? 6 : 5)
                .padding(.vertical, 3)
                .background(BaylanTheme.accent)
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3), value: count)
        }
    }
}
