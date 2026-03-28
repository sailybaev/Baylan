import SwiftUI
import BaylanCore

struct PeerProfileView: View {
    let peer: Peer
    let onStartChat: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isStartingChat = false
    @State private var viewModel: DiscoveryViewModel?

    init(peer: Peer, viewModel: DiscoveryViewModel, onStartChat: @escaping (UUID) -> Void) {
        self.peer = peer
        self.onStartChat = onStartChat
        _viewModel = .init(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            BaylanTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(BaylanTheme.separator)
                    .frame(width: 36, height: 4)
                    .padding(.top, BaylanSpacing.md)
                    .padding(.bottom, BaylanSpacing.xxl)

                // Avatar
                AvatarView(
                    name: peer.identity.displayName,
                    userId: peer.identity.userId,
                    size: BaylanSpacing.avatarLarge,
                    showAccentRing: peer.isConnected
                )

                Spacer().frame(height: BaylanSpacing.lg)

                // Name + verified
                HStack(spacing: BaylanSpacing.xs) {
                    Text(peer.identity.displayName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(BaylanTheme.textPrimary)

                    if peer.identity.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(BaylanTheme.accent)
                    }
                }

                Spacer().frame(height: 6)

                // userId
                Text(peer.identity.displayId)
                    .font(BaylanTypography.mono)
                    .foregroundStyle(BaylanTheme.textTertiary)

                Spacer().frame(height: BaylanSpacing.sm)

                // Status row
                HStack(spacing: 5) {
                    ConnectionDot(state: peer.isConnected ? .connected : .disconnected, size: 6)
                    Text(peer.isConnected ? "Nearby · \(peer.distanceLabel)" : "Not nearby")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(BaylanTheme.textSecondary)
                }

                Spacer().frame(height: BaylanSpacing.xxxl)

                // Message button
                Button {
                    startChat()
                } label: {
                    HStack {
                        if isStartingChat {
                            ProgressView().tint(.black)
                        } else {
                            Text("Message")
                                .font(BaylanTypography.headline)
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BaylanSpacing.md)
                    .background(BaylanTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: BaylanSpacing.cornerRadius))
                }
                .disabled(isStartingChat)
                .padding(.horizontal, BaylanSpacing.xxl)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
    }

    private func startChat() {
        guard let vm = viewModel else { return }
        isStartingChat = true
        Task {
            let threadId = await vm.startChat(with: peer)
            onStartChat(threadId)
        }
    }
}
