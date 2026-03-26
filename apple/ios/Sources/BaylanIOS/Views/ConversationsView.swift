import SwiftUI
import BaylanCore

struct ConversationsView: View {
    @Environment(\.appEnvironment) private var appEnvironment

    @State private var viewModel: ConversationsViewModel?
    @State private var searchText = ""
    @State private var selectedThreadId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    ProgressView()
                        .tint(BaylanTheme.accent)
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search conversations")
            .background(BaylanTheme.background)
        }
        .onAppear { setupViewModel() }
        .onChange(of: searchText) { _, newValue in
            viewModel?.searchText = newValue
        }
    }

    @ViewBuilder
    private func content(vm: ConversationsViewModel) -> some View {
        if vm.filteredThreads.isEmpty {
            EmptyStateView(
                icon: "message",
                title: searchText.isEmpty ? "No Conversations" : "No Results",
                message: searchText.isEmpty
                    ? "Nearby people will appear automatically when in range."
                    : "Try a different search term."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: BaylanSpacing.xs) {
                    ForEach(vm.filteredThreads) { thread in
                        NavigationLink(value: thread.threadId) {
                            ConversationCell(
                                thread: thread,
                                connectedPeerCount: appEnvironment?.peerService.connectedPeerCount ?? 0
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, BaylanSpacing.md)
                .padding(.top, BaylanSpacing.sm)
            }
            .navigationDestination(for: UUID.self) { threadId in
                if let env = appEnvironment {
                    ChatView(threadId: threadId, appEnvironment: env)
                }
            }
        }
    }

    private func setupViewModel() {
        guard viewModel == nil, let env = appEnvironment else { return }
        viewModel = ConversationsViewModel(threadService: env.threadService)
    }
}
