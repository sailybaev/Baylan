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
        NavigationStack {
            ZStack {
                BaylanTheme.background.ignoresSafeArea()

                VStack(spacing: BaylanSpacing.xxl) {
                    Spacer()

                    AvatarView(
                        name: peer.identity.displayName,
                        userId: peer.identity.userId,
                        size: BaylanSpacing.avatarLarge,
                        showAccentRing: peer.isConnected
                    )

                    VStack(spacing: BaylanSpacing.sm) {
                        HStack(spacing: BaylanSpacing.xs) {
                            Text(peer.identity.displayName)
                                .font(BaylanTypography.title2)
                                .foregroundStyle(BaylanTheme.textPrimary)

                            if peer.identity.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(BaylanTheme.accent)
                            }
                        }

                        Text(peer.identity.displayId)
                            .font(BaylanTypography.caption)
                            .foregroundStyle(BaylanTheme.textTertiary)
                            .fontDesign(.monospaced)

                        if peer.isConnected {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Nearby")
                                    .font(BaylanTypography.caption)
                                    .foregroundStyle(BaylanTheme.textSecondary)
                            }
                        }
                    }

                    Button {
                        startChat()
                    } label: {
                        HStack {
                            if isStartingChat {
                                ProgressView().tint(.black)
                            } else {
                                Text("Start Chat")
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
                    .padding(.horizontal, BaylanSpacing.xl)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BaylanTheme.accent)
                }
            }
        }
    }

    private func startChat() {
        guard let vm = viewModel else { return }
        isStartingChat = true
        Task {
            let threadId = await vm.startChat(with: peer)
            onStartChat(threadId)  // sets pendingThreadId before sheet dismisses
            dismiss()
        }
    }
}
