import SwiftUI
import BaylanCore

struct MessageBubble: View {
    let message: Message
    let isFromSelf: Bool
    let senderName: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: BaylanSpacing.xs) {
            if isFromSelf { Spacer(minLength: 40) }

            VStack(alignment: isFromSelf ? .trailing : .leading, spacing: 2) {
                if let name = senderName, !isFromSelf {
                    Text(name)
                        .font(BaylanTypography.caption)
                        .foregroundStyle(BaylanTheme.accent)
                        .padding(.horizontal, 4)
                }

                bubbleContent

                HStack(spacing: 4) {
                    if message.hopCount > 0 {
                        Label("\(message.hopCount)", systemImage: "arrow.triangle.2.circlepath")
                            .font(BaylanTypography.caption2)
                            .foregroundStyle(BaylanTheme.textTertiary)
                    }

                    if isFromSelf {
                        DeliveryStateIndicator(state: message.state)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isFromSelf { Spacer(minLength: 40) }
        }
    }

    private var bubbleContent: some View {
        Text(message.body ?? "")
            .font(BaylanTypography.body)
            .foregroundStyle(BaylanTheme.textPrimary)
            .padding(.horizontal, BaylanSpacing.md)
            .padding(.vertical, BaylanSpacing.sm)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: BaylanSpacing.cornerRadiusSmall))
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
