import SwiftUI
import BaylanCore

/// Checkmark-based delivery indicator — lives inside the message bubble footer.
/// sending → spinner
/// relayed  → single checkmark
/// delivered → double checkmark (accent tint)
/// failed   → red exclamation
struct DeliveryStateIndicator: View {
    let state: DeliveryState

    var body: some View {
        Group {
            switch state {
            case .sending:
                ProgressView()
                    .controlSize(.mini)
                    .tint(BaylanTheme.textTertiary)

            case .relayed:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BaylanTheme.textTertiary)

            case .delivered:
                // Double checkmark via overlapping images
                HStack(spacing: -5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(BaylanTheme.accent.opacity(0.8))

            case .failed:
                Image(systemName: "exclamationmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BaylanTheme.destructive)
            }
        }
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: state)
    }
}
