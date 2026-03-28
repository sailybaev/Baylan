import SwiftUI
import BaylanCore

struct FloatingInputBar: View {
    @Binding var text: String
    var isSendDisabled: Bool = false
    var isOffline: Bool = false
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    private var placeholder: String {
        isOffline ? "Peer offline — queued when in range" : "Message"
    }

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: BaylanSpacing.sm) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(BaylanTypography.body)
                .foregroundStyle(BaylanTheme.textPrimary)
                .lineLimit(1...5)
                .focused($isFocused)
                .tint(BaylanTheme.accent)
                .padding(.horizontal, BaylanSpacing.md)
                .padding(.vertical, BaylanSpacing.sm)
                .background(BaylanTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: BaylanSpacing.cornerRadius))
                .onSubmit {
                    #if targetEnvironment(macCatalyst)
                    sendMessage()
                    #endif
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(hasContent ? .black : BaylanTheme.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(hasContent ? BaylanTheme.accent : BaylanTheme.surfaceElevated)
                    .clipShape(Circle())
                    .animation(.spring(response: 0.2), value: hasContent)
                    .scaleEffect(hasContent ? 1.0 : 0.95)
                    .animation(.spring(response: 0.2), value: hasContent)
            }
            .disabled(!hasContent || isSendDisabled)
        }
        .padding(.horizontal, BaylanSpacing.md)
        .padding(.vertical, BaylanSpacing.sm)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(BaylanTheme.separator.opacity(0.5))
                .frame(height: 0.5)
        }
    }

    private func sendMessage() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend()
        text = ""
        #if !targetEnvironment(macCatalyst)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
