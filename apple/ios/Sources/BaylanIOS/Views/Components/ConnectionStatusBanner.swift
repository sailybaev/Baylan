import SwiftUI
import BaylanCore

struct ConnectionStatusBanner: View {
    let meshDeviceCount: Int

    var body: some View {
        HStack(spacing: BaylanSpacing.xs) {
            Circle()
                .fill(meshDeviceCount > 0 ? Color.green : BaylanTheme.textTertiary)
                .frame(width: 6, height: 6)
                .shadow(color: meshDeviceCount > 0 ? Color.green.opacity(0.8) : .clear, radius: 4)

            Text(statusText)
                .font(BaylanTypography.caption)
                .foregroundStyle(BaylanTheme.textSecondary)
        }
        .padding(.horizontal, BaylanSpacing.md)
        .padding(.vertical, 6)
        .glass()
        .padding(.horizontal, BaylanSpacing.lg)
        .animation(.spring(response: 0.3), value: meshDeviceCount)
    }

    private var statusText: String {
        switch meshDeviceCount {
        case 0: return "No nearby devices"
        case 1: return "1 device in mesh"
        default: return "\(meshDeviceCount) devices in mesh"
        }
    }
}
