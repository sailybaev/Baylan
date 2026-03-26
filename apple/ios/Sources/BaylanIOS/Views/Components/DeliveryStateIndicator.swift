import SwiftUI
import BaylanCore

struct DeliveryStateIndicator: View {
    let state: DeliveryState

    var body: some View {
        Text(statusText)
            .font(BaylanTypography.caption2)
            .foregroundStyle(statusColor)
            .transition(.opacity)
            .animation(.easeInOut, value: state)
    }

    private var statusText: String {
        switch state {
        case .sending: return "Sending..."
        case .relayed: return "Sent"
        case .delivered: return "Delivered"
        case .failed: return "Not Delivered"
        }
    }

    private var statusColor: Color {
        switch state {
        case .sending, .relayed: return BaylanTheme.textTertiary
        case .delivered: return BaylanTheme.textSecondary
        case .failed: return BaylanTheme.destructive
        }
    }
}
