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
                // No horizontal padding for single digits — frame becomes square → Capsule = circle
                .padding(.horizontal, count > 9 ? 6 : 0)
                .frame(minWidth: 20, minHeight: 20)
                .background(BaylanTheme.accent)
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3), value: count)
        }
    }
}
