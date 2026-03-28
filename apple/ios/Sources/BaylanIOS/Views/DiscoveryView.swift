import SwiftUI
import BaylanCore

struct PeopleView: View {
    @Environment(\.appEnvironment) private var appEnvironment

    @State private var viewModel: DiscoveryViewModel?
    @State private var selectedPeer: Peer?
    @State private var presentedChatThreadId: UUID?

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
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.large)
            #if targetEnvironment(macCatalyst)
            .navigationDestination(item: $presentedChatThreadId) { threadId in
                if let env = appEnvironment {
                    ChatView(threadId: threadId, appEnvironment: env)
                }
            }
            #endif
        }
        #if !targetEnvironment(macCatalyst)
        .fullScreenCover(isPresented: Binding(
            get: { presentedChatThreadId != nil },
            set: { if !$0 { presentedChatThreadId = nil } }
        )) {
            if let threadId = presentedChatThreadId, let env = appEnvironment {
                NavigationStack {
                    ChatView(threadId: threadId, appEnvironment: env)
                }
            }
        }
        #endif
        .sheet(item: $selectedPeer) { peer in
            if let vm = viewModel {
                PeerProfileView(peer: peer, viewModel: vm) { threadId in
                    selectedPeer = nil
                    #if targetEnvironment(macCatalyst)
                    presentedChatThreadId = threadId
                    #else
                    // Brief delay lets the profile sheet dismiss before covering
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        presentedChatThreadId = threadId
                    }
                    #endif
                }
            }
        }
        .onAppear { setupViewModel() }
    }

    @ViewBuilder
    private func content(vm: DiscoveryViewModel) -> some View {
        if vm.isSearching {
            searchingState(vm: vm)
        } else {
            peerList(vm: vm)
        }
    }

    private func searchingState(vm: DiscoveryViewModel) -> some View {
        VStack(spacing: BaylanSpacing.xl) {
            Spacer()
            PulseRadar(peerCount: vm.nearbyPeers.count, size: 200)
            VStack(spacing: BaylanSpacing.sm) {
                Text("Searching for peers")
                    .font(BaylanTypography.title3)
                    .foregroundStyle(BaylanTheme.textPrimary)
                Text("Make sure Bayla is open on nearby devices")
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
            LazyVStack(spacing: BaylanSpacing.xs, pinnedViews: []) {
                // Section: Nearby Now
                sectionHeader("NEARBY NOW")

                ForEach(vm.nearbyPeers) { peer in
                    Button {
                        #if !targetEnvironment(macCatalyst)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        selectedPeer = peer
                    } label: {
                        PeerRow(peer: peer)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    ))
                }

                // Scan QR card
                scanQRPlaceholder
            }
            .padding(.horizontal, BaylanSpacing.md)
            .padding(.top, BaylanSpacing.sm)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.nearbyPeers.map(\.id))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BaylanTheme.textTertiary)
                .kerning(0.5)
            Spacer()
        }
        .padding(.horizontal, BaylanSpacing.xs)
        .padding(.top, BaylanSpacing.sm)
        .padding(.bottom, 4)
    }

    private var scanQRPlaceholder: some View {
        Button {
            // Scan QR is available from the You tab
        } label: {
            HStack(spacing: BaylanSpacing.md) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(BaylanTheme.accent)
                    .frame(width: BaylanSpacing.avatarMedium, height: BaylanSpacing.avatarMedium)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Scan QR Code")
                        .font(BaylanTypography.headline)
                        .foregroundStyle(BaylanTheme.textPrimary)
                    Text("Verify a contact's identity in person")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(BaylanTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BaylanTheme.textTertiary)
            }
            .padding(.horizontal, BaylanSpacing.md)
            .padding(.vertical, BaylanSpacing.sm + 2)
            .background(BaylanTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: BaylanSpacing.cornerRadius))
        }
        .buttonStyle(.plain)
        .padding(.top, BaylanSpacing.lg)
        .disabled(true)
        .opacity(0.6)
    }

    private func setupViewModel() {
        guard viewModel == nil, let env = appEnvironment else { return }
        viewModel = DiscoveryViewModel(
            peerService: env.peerService,
            threadService: env.threadService
        )
    }
}
