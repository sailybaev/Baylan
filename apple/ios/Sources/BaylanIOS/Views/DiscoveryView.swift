import SwiftUI
import BaylanCore

struct DiscoveryView: View {
    @Environment(\.appEnvironment) private var appEnvironment

    @State private var viewModel: DiscoveryViewModel?
    @State private var selectedPeer: Peer?
    @State private var navigateToThreadId: UUID?
    @State private var pendingThreadId: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                BaylanTheme.background.ignoresSafeArea()

                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    ProgressView().tint(BaylanTheme.accent)
                }
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $navigateToThreadId) { threadId in
                if let env = appEnvironment {
                    ChatView(threadId: threadId, appEnvironment: env)
                }
            }
        }
        .onAppear { setupViewModel() }
        .sheet(item: $selectedPeer, onDismiss: {
            if let threadId = pendingThreadId {
                navigateToThreadId = threadId
                pendingThreadId = nil
            }
        }) { peer in
            if let vm = viewModel {
                PeerProfileView(peer: peer, viewModel: vm) { threadId in
                    pendingThreadId = threadId
                }
            }
        }
    }

    @ViewBuilder
    private func content(vm: DiscoveryViewModel) -> some View {
        if vm.isSearching {
            searchingState
        } else {
            peerList(vm: vm)
        }
    }

    private var searchingState: some View {
        VStack(spacing: BaylanSpacing.xl) {
            Spacer()

            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .strokeBorder(BaylanTheme.accent.opacity(0.3 - Double(index) * 0.08), lineWidth: 1)
                        .frame(width: CGFloat(80 + index * 50), height: CGFloat(80 + index * 50))
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(index) * 0.4),
                            value: true
                        )
                }

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(BaylanTheme.accent)
                    .symbolEffect(.pulse)
            }
            .frame(height: 200)

            VStack(spacing: BaylanSpacing.sm) {
                Text("Searching for Peers")
                    .font(BaylanTypography.title3)
                    .foregroundStyle(BaylanTheme.textPrimary)

                Text("Make sure the other person has Baylan open.")
                    .font(BaylanTypography.subheadline)
                    .foregroundStyle(BaylanTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, BaylanSpacing.xxl)
    }

    private func peerList(vm: DiscoveryViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: BaylanSpacing.xs) {
                ForEach(vm.nearbyPeers) { peer in
                    Button {
                        #if !targetEnvironment(macCatalyst)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        selectedPeer = peer
                    } label: {
                        PeerRow(peer: peer)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, BaylanSpacing.md)
            .padding(.top, BaylanSpacing.sm)
        }
    }

    private func setupViewModel() {
        guard viewModel == nil, let env = appEnvironment else { return }
        viewModel = DiscoveryViewModel(
            peerService: env.peerService,
            threadService: env.threadService
        )
    }
}

