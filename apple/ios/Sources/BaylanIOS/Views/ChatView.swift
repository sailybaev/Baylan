import SwiftUI
import BaylanCore

struct ChatView: View {
    let threadId: UUID
    let appEnvironment: AppEnvironment

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ChatViewModel?
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?

    private var isNearby: Bool { threadId == MessageThread.nearbyThreadId }

    private var isConnected: Bool {
        if isNearby { return true }
        guard let peerId = viewModel?.thread?.peerId else { return false }
        return appEnvironment.peerService.connectedPeerIds.contains(peerId)
    }

    private var connectionState: ConnectionState {
        if isNearby {
            return appEnvironment.peerService.nearbyPeers.isEmpty ? .searching : .connected
        }
        guard let peerId = viewModel?.thread?.peerId else { return .disconnected }
        guard appEnvironment.peerService.connectedPeerIds.contains(peerId) else { return .disconnected }
        let strength = appEnvironment.peerService.nearbyPeers
            .first(where: { $0.identity.userId == peerId })?.signalStrength
        return (strength ?? 1.0) < 0.25 ? .weak : .connected
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BaylanTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                messagesArea
                FloatingInputBar(
                    text: $inputText,
                    isSendDisabled: false,
                    isOffline: !isNearby && !isConnected,
                    onSend: sendMessage
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await loadViewModel() }
        .onChange(of: appEnvironment.messageService.lastIncomingMessageAt) { _, _ in
            guard let vm = viewModel else { return }
            Task { await vm.loadMessages() }
        }
    }

    @ViewBuilder
    private var messagesArea: some View {
        if let vm = viewModel {
            if vm.isLoading {
                ProgressView().tint(BaylanTheme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.messages.isEmpty {
                emptyChat
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: BaylanSpacing.xs) {
                            messageList(vm: vm)
                        }
                        .padding(.horizontal, BaylanSpacing.md)
                        .padding(.top, BaylanSpacing.sm)
                        .padding(.bottom, BaylanSpacing.lg)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom(animated: false)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        scrollToBottom(animated: true)
                    }
                }
            }
        } else {
            ProgressView().tint(BaylanTheme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyChat: some View {
        VStack(spacing: BaylanSpacing.sm) {
            Text("👋")
                .font(.system(size: 40))
            Text("Say hello")
                .font(BaylanTypography.subheadline)
                .foregroundStyle(BaylanTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func messageList(vm: ChatViewModel) -> some View {
        let selfId = appEnvironment.identityService.localIdentity.userId
        ForEach(Array(vm.messages.enumerated()), id: \.element.messageId) { index, message in
            let isFromSelf = message.senderId == selfId
            let showDate = index == 0 || !Calendar.current.isDate(
                vm.messages[index - 1].createdAt, inSameDayAs: message.createdAt
            )

            if showDate { dateSeparator(for: message.createdAt) }

            MessageBubble(
                message: message,
                isFromSelf: isFromSelf,
                senderName: isNearby && !isFromSelf ? senderName(for: message.senderId, in: vm) : nil
            )
            .id(message.messageId)
            .transition(.asymmetric(
                insertion: .move(edge: isFromSelf ? .trailing : .leading).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    private func dateSeparator(for date: Date) -> some View {
        Text(date.formatted(date: .abbreviated, time: .omitted))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(BaylanTheme.textTertiary)
            .padding(.horizontal, BaylanSpacing.lg)
            .padding(.vertical, 4)
            .background(BaylanTheme.surfaceElevated.opacity(0.6))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, BaylanSpacing.xs)
    }

    private func senderName(for senderId: String, in vm: ChatViewModel) -> String {
        vm.participantNames[senderId] ?? String(senderId.prefix(8))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Dismiss chevron — iOS only (on Mac, NavigationStack provides back navigation)
        #if !targetEnvironment(macCatalyst)
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BaylanTheme.textSecondary)
            }
        }
        #endif

        // Name + status subtitle (center)
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(navTitle)
                    .font(BaylanTypography.headline)
                    .foregroundStyle(BaylanTheme.textPrimary)

                statusSubtitle
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(BaylanTheme.textSecondary)
            }
            .animation(.spring(response: 0.3), value: connectionState)
        }

        // Connection dot (right)
        ToolbarItem(placement: .topBarTrailing) {
            ConnectionDot(state: connectionState, size: 7)
                .animation(.spring(response: 0.3), value: connectionState)
        }
    }

    private var navTitle: String {
        if isNearby { return "Nearby" }
        return viewModel?.thread?.displayName ?? "Chat"
    }

    @ViewBuilder
    private var statusSubtitle: some View {
        if isNearby {
            let count = appEnvironment.peerService.nearbyPeers.count
            Text(count == 0 ? "No devices nearby" : "\(count) in mesh")
        } else if let peerId = viewModel?.thread?.peerId,
                  let peer = appEnvironment.peerService.nearbyPeers.first(where: { $0.identity.userId == peerId }) {
            Text(peer.signalStrength != nil ? "Nearby · \(peer.distanceLabel)" : "Nearby")
        } else {
            Text("Offline")
        }
    }

    private func sendMessage() {
        guard let vm = viewModel else { return }
        let text = inputText
        Task { await vm.sendMessage(text) }
    }

    private func scrollToBottom(animated: Bool) {
        guard let proxy = scrollProxy, let last = viewModel?.messages.last else { return }
        if animated {
            withAnimation(.spring(response: 0.3)) {
                proxy.scrollTo(last.messageId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.messageId, anchor: .bottom)
        }
    }

    private func loadViewModel() async {
        let vm = ChatViewModel(
            threadId: threadId,
            messageService: appEnvironment.messageService,
            threadService: appEnvironment.threadService,
            repository: appEnvironment.repository
        )
        viewModel = vm
        await vm.loadMessages()
    }
}
