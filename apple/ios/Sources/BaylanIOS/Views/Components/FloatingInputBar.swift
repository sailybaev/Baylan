import SwiftUI
import BaylanCore

struct FloatingInputBar: View {
    @Binding var text: String
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: BaylanSpacing.sm) {
            TextField("Message", text: $text, axis: .vertical)
                .font(BaylanTypography.body)
                .foregroundStyle(BaylanTheme.textPrimary)
                .lineLimit(1...5)
                .focused($isFocused)
                .tint(BaylanTheme.accent)
                .padding(.horizontal, BaylanSpacing.md)
                .padding(.vertical, BaylanSpacing.sm)
                .background(BaylanTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: BaylanSpacing.cornerRadiusSmall))
                .onSubmit {
                    #if targetEnvironment(macCatalyst)
                    sendMessage()
                    #endif
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? BaylanTheme.textTertiary
                        : .black)
                    .frame(width: 36, height: 36)
                    .background(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? BaylanTheme.surfaceElevated
                            : BaylanTheme.accent
                    )
                    .clipShape(Circle())
                    .animation(.spring(response: 0.2), value: text.isEmpty)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, BaylanSpacing.md)
        .padding(.vertical, BaylanSpacing.sm)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().foregroundStyle(BaylanTheme.surfaceElevated)
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
