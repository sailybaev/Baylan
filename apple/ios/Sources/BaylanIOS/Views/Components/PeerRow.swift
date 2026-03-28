import SwiftUI
import BaylanCore

struct PeerRow: View {
    let peer: Peer

    var body: some View {
        HStack(spacing: BaylanSpacing.md) {
            AvatarView(
                name: peer.identity.displayName,
                userId: peer.identity.userId,
                showAccentRing: peer.isConnected
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: BaylanSpacing.xs) {
                    Text(peer.identity.displayName)
                        .font(BaylanTypography.headline)
                        .foregroundStyle(BaylanTheme.textPrimary)

                    if peer.identity.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(BaylanTheme.accent)
                    }
                }

                HStack(spacing: BaylanSpacing.xs) {
                    ConnectionDot(state: connectionState, size: 5)

                    Text(subtitleText)
                        .font(BaylanTypography.caption)
                        .foregroundStyle(BaylanTheme.textSecondary)
                }
            }

            Spacer(minLength: 0)

            if peer.isConnected {
                SignalBars(strength: peer.signalStrength)
            }
        }
        .padding(.horizontal, BaylanSpacing.md)
        .padding(.vertical, BaylanSpacing.sm + 2)
        .background(BaylanTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BaylanSpacing.cornerRadius))
    }

    private var connectionState: ConnectionState {
        guard peer.isConnected else { return .disconnected }
        guard let s = peer.signalStrength else { return .connected }
        return s < 0.25 ? .weak : .connected
    }

    private var subtitleText: String {
        if peer.isConnected {
            return peer.distanceLabel
        } else if let last = peer.lastPresence {
            return "Last seen \(last.relativeFromNow)"
        } else {
            return "Not seen"
        }
    }
}

private extension Date {
    var relativeFromNow: String {
        let seconds = Int(-timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
