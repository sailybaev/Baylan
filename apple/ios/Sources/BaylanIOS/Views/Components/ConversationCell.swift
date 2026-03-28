import SwiftUI
import BaylanCore

struct ConversationCell: View {
    let thread: MessageThread
    let connectedPeerCount: Int
    var isConnected: Bool = false

    var body: some View {
        HStack(spacing: BaylanSpacing.md) {
            avatarSection
            contentSection
            Spacer(minLength: 0)
            trailingSection
        }
        .padding(.horizontal, BaylanSpacing.md)
        .padding(.vertical, BaylanSpacing.sm + 2)
        .background(
            thread.isNearbyChannel
                ? BaylanTheme.accent.opacity(0.04)
                : BaylanTheme.surface
        )
        .clipShape(RoundedRectangle(cornerRadius: BaylanSpacing.cornerRadius))
    }

    private var avatarSection: some View {
        ZStack {
            if thread.isNearbyChannel {
                nearbyAvatar
            } else {
                AvatarView(
                    name: thread.displayName,
                    userId: thread.peerId,
                    showAccentRing: isConnected
                )
            }
        }
    }

    private var nearbyAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [BaylanTheme.accent.opacity(0.25), BaylanTheme.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: BaylanSpacing.avatarMedium, height: BaylanSpacing.avatarMedium)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(BaylanTheme.accent)
        }
        .frame(width: BaylanSpacing.avatarMedium, height: BaylanSpacing.avatarMedium)
        .overlay {
            if connectedPeerCount > 0 {
                Circle()
                    .strokeBorder(BaylanTheme.accent, lineWidth: 1.5)
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(thread.displayName)
                .font(BaylanTypography.headline)
                .foregroundStyle(BaylanTheme.textPrimary)
                .lineLimit(1)

            if let last = thread.lastMessage?.body, !last.isEmpty {
                Text(last)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(BaylanTheme.textSecondary)
                    .lineLimit(1)
            } else if thread.isNearbyChannel {
                Text(connectedPeerCount == 0
                     ? "No one nearby"
                     : "\(connectedPeerCount) \(connectedPeerCount == 1 ? "person" : "people") nearby")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(connectedPeerCount > 0 ? BaylanTheme.accent.opacity(0.8) : BaylanTheme.textTertiary)
                    .lineLimit(1)
            } else {
                Text("No messages yet")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(BaylanTheme.textTertiary)
                    .italic()
            }
        }
    }

    private var trailingSection: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 8) {
                // Connection dot for direct threads (not nearby)
                if !thread.isNearbyChannel {
                    ConnectionDot(
                        state: isConnected ? .connected : .disconnected,
                        size: 6
                    )
                }

                Text(thread.updatedAt.relativeString)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(BaylanTheme.textTertiary)
            }

            UnreadBadge(count: thread.unreadCount)
        }
    }
}

private extension Date {
    var relativeString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            return formatted(date: .abbreviated, time: .omitted)
        }
    }
}
