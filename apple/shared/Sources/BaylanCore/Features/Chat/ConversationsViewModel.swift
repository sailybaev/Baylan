import Foundation
import Observation

@Observable
@MainActor
public final class ConversationsViewModel {

    public private(set) var threads: [MessageThread] = []
    public var searchText: String = ""

    private let threadService: ThreadService

    public init(threadService: ThreadService) {
        self.threadService = threadService
    }

    public var filteredThreads: [MessageThread] {
        let all = threadService.threads
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.peerId.localizedCaseInsensitiveContains(searchText) ||
            ($0.lastMessage?.body?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    public var nearbyThread: MessageThread? {
        threadService.threads.first { $0.isNearbyChannel }
    }

    public var directThreads: [MessageThread] {
        threadService.threads.filter { !$0.isNearbyChannel }
    }

    public var totalUnread: Int {
        threadService.threads.reduce(0) { $0 + $1.unreadCount }
    }

    public func load() async {
        await threadService.loadThreads()
    }

    public func deleteThread(_ threadId: UUID) async {
        await threadService.deleteThread(threadId)
    }
}
