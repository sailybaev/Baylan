import SwiftUI
import BaylanCore

struct ConversationCell: View {
    let thread: MessageThread
    let connectedPeerCount: Int

    var body: some View {
        HStack(spacing: BaylanSpacing.md) {
            avatarSection
            contentSection
            Spacer(minLength: 0)
            trailingSection
        }
        .padding(.horizontal, BaylanSpacing.md)
        .padding(.vertical, BaylanSpacing.sm)
        .background(BaylanTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BaylanSpacing.cornerRadiusSmall))
    }

    private var avatarSection: some View {
        ZStack {
            if thread.isNearbyChannel {
                nearbyAvatar
            } else {
                AvatarView(
                    name: thread.displayName,
                    userId: thread.peerId
                )
            }
        }
    }

    private var nearbyAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [BaylanTheme.accent.opacity(0.3), BaylanTheme.accent.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: BaylanSpacing.avatarMedium, height: BaylanSpacing.avatarMedium)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(BaylanTheme.accent)
        }
        .frame(width: BaylanSpacing.avatarMedium, height: BaylanSpacing.avatarMedium)
        .overlay {
            if connectedPeerCount > 0 {
                Circle()
                    .strokeBorder(BaylanTheme.accent, lineWidth: 2)
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: BaylanSpacing.xs) {
                Text(thread.displayName)
                    .font(BaylanTypography.headline)
                    .foregroundStyle(BaylanTheme.textPrimary)
                    .lineLimit(1)

                if thread.isNearbyChannel && connectedPeerCount > 0 {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .font(.system(size: 10))
                        .foregroundStyle(BaylanTheme.accent)
                }
            }

            if let last = thread.lastMessage?.body {
                Text(last)
                    .font(BaylanTypography.subheadline)
                    .foregroundStyle(BaylanTheme.textSecondary)
                    .lineLimit(1)
            } else {
                Text("No messages yet")
                    .font(BaylanTypography.subheadline)
                    .foregroundStyle(BaylanTheme.textTertiary)
                    .italic()
            }
        }
    }

    private var trailingSection: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(thread.updatedAt.relativeString)
                .font(BaylanTypography.caption2)
                .foregroundStyle(BaylanTheme.textTertiary)

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
