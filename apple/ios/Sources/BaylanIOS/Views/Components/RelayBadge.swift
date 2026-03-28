import SwiftUI
import BaylanCore

/// Shows below a message bubble when hopCount > 0.
/// Tapping expands to show the relay path as a dot chain.
struct RelayBadge: View {
    let hopCount: Int
    @State private var expanded = false

    var body: some View {
        if hopCount > 0 {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9, weight: .medium))
                        Text("relayed · \(hopCount) \(hopCount == 1 ? "hop" : "hops")")
                            .font(.system(size: 11, weight: .regular))
                    }
                    .foregroundStyle(BaylanTheme.textTertiary)
                }
                .buttonStyle(.plain)

                if expanded {
                    relayPath
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                }
            }
        }
    }

    private var relayPath: some View {
        HStack(spacing: 0) {
            // You
            Circle()
                .fill(BaylanTheme.accent)
                .frame(width: 6, height: 6)

            // Relay nodes
            ForEach(0..<hopCount, id: \.self) { _ in
                Rectangle()
                    .fill(BaylanTheme.textTertiary.opacity(0.4))
                    .frame(width: 16, height: 1)
                Circle()
                    .fill(BaylanTheme.textTertiary.opacity(0.5))
                    .frame(width: 6, height: 6)
            }

            // Final line to recipient
            Rectangle()
                .fill(BaylanTheme.textTertiary.opacity(0.4))
                .frame(width: 16, height: 1)
            Circle()
                .fill(BaylanTheme.textSecondary)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 2)
    }
}
