import SwiftUI
import BaylanCore

struct ChatView: View {
    let threadId: UUID
    let appEnvironment: AppEnvironment

    @State private var viewModel: ChatViewModel?
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?

    private var isNearby: Bool { threadId == MessageThread.nearbyThreadId }

    var body: some View {
        ZStack(alignment: .bottom) {
            BaylanTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                messagesArea
                FloatingInputBar(text: $inputText, onSend: sendMessage)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await loadViewModel() }
    }

    private var navTitle: String {
        if isNearby { return "Nearby" }
        return viewModel?.thread?.displayName ?? "Chat"
    }

    @ViewBuilder
    private var messagesArea: some View {
        if let vm = viewModel {
            if vm.isLoading {
                ProgressView().tint(BaylanTheme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.messages.isEmpty {
                EmptyStateView(icon: "bubble.left", title: "No Messages", message: "Be the first to say something.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    @ViewBuilder
    private func messageList(vm: ChatViewModel) -> some View {
        let selfId = appEnvironment.identityService.localIdentity.userId
        ForEach(Array(vm.messages.enumerated()), id: \.element.messageId) { index, message in
            let isFromSelf = message.senderId == selfId
            let showDate = index == 0 || !Calendar.current.isDate(
                vm.messages[index - 1].createdAt, inSameDayAs: message.createdAt
            )

            if showDate {
                dateSeparator(for: message.createdAt)
            }

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
            .font(BaylanTypography.caption)
            .foregroundStyle(BaylanTheme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BaylanSpacing.xs)
    }

    private func senderName(for senderId: String, in vm: ChatViewModel) -> String {
        vm.messages.first { $0.senderId == senderId }
            .map { _ in String(senderId.prefix(8)) } ?? String(senderId.prefix(8))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(navTitle)
                    .font(BaylanTypography.headline)
                    .foregroundStyle(BaylanTheme.textPrimary)
                if isNearby {
                    let count = appEnvironment.peerService.connectedPeerCount
                    Text(count == 0 ? "No nearby devices" : "\(count) nearby")
                        .font(BaylanTypography.caption2)
                        .foregroundStyle(count > 0 ? BaylanTheme.accent : BaylanTheme.textTertiary)
                }
            }
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
