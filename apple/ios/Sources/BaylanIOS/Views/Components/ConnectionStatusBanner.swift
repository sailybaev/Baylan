import SwiftUI
import BaylanCore

struct ConnectionStatusBanner: View {
    let connectedCount: Int

    var body: some View {
        HStack(spacing: BaylanSpacing.xs) {
            Circle()
                .fill(connectedCount > 0 ? Color.green : BaylanTheme.textTertiary)
                .frame(width: 6, height: 6)
                .shadow(color: connectedCount > 0 ? Color.green.opacity(0.8) : .clear, radius: 4)

            Text(statusText)
                .font(BaylanTypography.caption)
                .foregroundStyle(BaylanTheme.textSecondary)
        }
        .padding(.horizontal, BaylanSpacing.md)
        .padding(.vertical, 6)
        .glass()
        .padding(.horizontal, BaylanSpacing.lg)
        .animation(.spring(response: 0.3), value: connectedCount)
    }

    private var statusText: String {
        switch connectedCount {
        case 0: "No nearby devices"
        case 1: "Connected to 1 device"
        default: "Connected to \(connectedCount) devices"
        }
    }
}
