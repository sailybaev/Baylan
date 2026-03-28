import SwiftUI
import BaylanCore

/// Primary "Mesh" tab — unified feed with Nearby pinned first, then direct threads.
struct MeshFeedView: View {
    @Environment(\.appEnvironment) private var appEnvironment

    @State private var viewModel: ConversationsViewModel?
    @State private var searchText = ""
    @State private var presentedThreadId: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                BaylanTheme.background.ignoresSafeArea()

                Group {
                    if let vm = viewModel {
                        content(vm: vm)
                    } else {
                        ProgressView().tint(BaylanTheme.accent)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search conversations")
            .background(BaylanTheme.background)
            .toolbar { toolbarContent }
            #if targetEnvironment(macCatalyst)
            .navigationDestination(for: UUID.self) { threadId in
                if let env = appEnvironment {
                    ChatView(threadId: threadId, appEnvironment: env)
                }
            }
            #endif
        }
        #if !targetEnvironment(macCatalyst)
        .fullScreenCover(isPresented: Binding(
            get: { presentedThreadId != nil },
            set: { if !$0 { presentedThreadId = nil } }
        )) {
            if let threadId = presentedThreadId, let env = appEnvironment {
                NavigationStack {
                    ChatView(threadId: threadId, appEnvironment: env)
                }
            }
        }
        #endif
        .onAppear { setupViewModel() }
        .onChange(of: searchText) { _, newValue in
            viewModel?.searchText = newValue
        }
        .onChange(of: appEnvironment?.messageService.lastIncomingMessageAt) { _, _ in
            guard let env = appEnvironment else { return }
            Task { await env.threadService.refresh() }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Center: "Mesh" title + live status subtitle on iOS
        // On Mac, nav title handled by the system; status pill stays in trailing position
        #if targetEnvironment(macCatalyst)
        ToolbarItem(placement: .principal) {
            Text("Mesh")
                .font(BaylanTypography.headline)
                .foregroundStyle(BaylanTheme.textPrimary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if let env = appEnvironment {
                MeshStatusPill(peerCount: env.peerService.nearbyPeers.count)
            }
        }
        #else
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text("Mesh")
                    .font(BaylanTypography.headline)
                    .foregroundStyle(BaylanTheme.textPrimary)

                statusSubtitle
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(BaylanTheme.textSecondary)
                    .contentTransition(.numericText())
            }
            .animation(.spring(response: 0.4), value: appEnvironment?.peerService.nearbyPeers.count)
        }
        #endif
    }

    @ViewBuilder
    private var statusSubtitle: some View {
        if let env = appEnvironment {
            let count = env.peerService.nearbyPeers.count
            if count == 0 {
                Text("Searching...")
            } else if count == 1 {
                Text("1 device in mesh")
            } else {
                Text("\(count) devices in mesh")
            }
        }
    }

    @ViewBuilder
    private func content(vm: ConversationsViewModel) -> some View {
        if vm.filteredThreads.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: BaylanSpacing.xs) {
                    ForEach(vm.filteredThreads) { thread in
                        #if targetEnvironment(macCatalyst)
                        NavigationLink(value: thread.threadId) {
                            ConversationCell(
                                thread: thread,
                                connectedPeerCount: appEnvironment?.peerService.connectedPeerCount ?? 0,
                                isConnected: isConnected(for: thread)
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                        #else
                        Button {
                            presentedThreadId = thread.threadId
                        } label: {
                            ConversationCell(
                                thread: thread,
                                connectedPeerCount: appEnvironment?.peerService.connectedPeerCount ?? 0,
                                isConnected: isConnected(for: thread)
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                        #endif
                    }
                }
                .padding(.horizontal, BaylanSpacing.md)
                .padding(.top, BaylanSpacing.sm)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.filteredThreads.map(\.threadId))
        }
    }

    private var emptyState: some View {
        VStack(spacing: BaylanSpacing.xl) {
            Spacer()
            PulseRadar(peerCount: 0, size: 160)
            VStack(spacing: BaylanSpacing.sm) {
                Text("No one nearby yet")
                    .font(BaylanTypography.title3)
                    .foregroundStyle(BaylanTheme.textPrimary)
                Text("Move closer to other Bayla users")
                    .font(BaylanTypography.subheadline)
                    .foregroundStyle(BaylanTheme.textSecondary)
            }
            Spacer()
        }
    }

    private func isConnected(for thread: MessageThread) -> Bool {
        guard !thread.isNearbyChannel else {
            return (appEnvironment?.peerService.connectedPeerCount ?? 0) > 0
        }
        return appEnvironment?.peerService.connectedPeerIds.contains(thread.peerId) ?? false
    }

    private func setupViewModel() {
        guard viewModel == nil, let env = appEnvironment else { return }
        viewModel = ConversationsViewModel(threadService: env.threadService)
    }
}
