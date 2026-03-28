import SwiftUI
import BaylanCore

struct MessageBubble: View {
    let message: Message
    let isFromSelf: Bool
    let senderName: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: BaylanSpacing.xs) {
            if isFromSelf { Spacer(minLength: 52) }

            VStack(alignment: isFromSelf ? .trailing : .leading, spacing: 3) {
                if let name = senderName, !isFromSelf {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BaylanTheme.accent)
                        .padding(.horizontal, BaylanSpacing.xs)
                }

                bubbleContent

                // Relay badge below bubble
                if message.hopCount > 0 {
                    RelayBadge(hopCount: message.hopCount)
                        .padding(.horizontal, BaylanSpacing.xs)
                }
            }

            if !isFromSelf { Spacer(minLength: 52) }
        }
    }

    private var bubbleContent: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.body ?? "")
                .font(BaylanTypography.body)
                .foregroundStyle(BaylanTheme.textPrimary)

            // Footer: timestamp + delivery state (self only)
            HStack(spacing: 3) {
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(BaylanTheme.textTertiary)

                if isFromSelf {
                    DeliveryStateIndicator(state: message.state)
                }
            }
        }
        .padding(.horizontal, BaylanSpacing.md)
        .padding(.vertical, BaylanSpacing.sm)
        .background(bubbleBackground)
        .clipShape(bubbleShape)
    }

    private var bubbleShape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: BaylanSpacing.cornerRadiusBubble,
            bottomLeadingRadius: isFromSelf ? BaylanSpacing.cornerRadiusBubble : BaylanSpacing.cornerRadiusBubbleTail,
            bottomTrailingRadius: isFromSelf ? BaylanSpacing.cornerRadiusBubbleTail : BaylanSpacing.cornerRadiusBubble,
            topTrailingRadius: BaylanSpacing.cornerRadiusBubble
        )
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.threadId == MessageThread.nearbyThreadId {
            BaylanTheme.bubbleNearby
        } else if isFromSelf {
            BaylanTheme.bubbleSent
        } else {
            BaylanTheme.bubbleReceived
        }
    }
}
