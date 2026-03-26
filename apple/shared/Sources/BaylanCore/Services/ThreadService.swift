import Foundation
import Observation

@Observable
@MainActor
public final class ThreadService {

    // MARK: - Published state

    public private(set) var threads: [MessageThread] = []

    // MARK: - Dependencies

    private let repository: any MessageRepositoryProtocol

    // MARK: - Init

    public init(repository: any MessageRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Public

    public func loadThreads() async {
        do {
            var fetched = try await repository.allThreads()
            // Ensure Nearby channel is always present at the top
            if !fetched.contains(where: { $0.isNearbyChannel }) {
                let nearby = MessageThread.nearbyChannel
                try await repository.saveThread(nearby)
                fetched.insert(nearby, at: 0)
            } else {
                // Move nearby to top if it's not already
                if let idx = fetched.firstIndex(where: { $0.isNearbyChannel }), idx != 0 {
                    let nearby = fetched.remove(at: idx)
                    fetched.insert(nearby, at: 0)
                }
            }
            threads = fetched
        } catch {
            // Non-fatal: threads remain empty until next load
        }
    }

    public func markAsRead(_ threadId: UUID) async {
        try? await repository.updateUnreadCount(threadId, count: 0)
        if let idx = threads.firstIndex(where: { $0.threadId == threadId }) {
            threads[idx] = MessageThread(
                threadId: threads[idx].threadId,
                peerId: threads[idx].peerId,
                conversationType: threads[idx].conversationType,
                lastMessage: threads[idx].lastMessage,
                unreadCount: 0,
                updatedAt: threads[idx].updatedAt
            )
        }
    }

    public func deleteThread(_ threadId: UUID) async {
        try? await repository.deleteThread(threadId)
        threads.removeAll { $0.threadId == threadId }
    }

    /// Returns an existing thread for this peer, or creates a new one.
    public func getOrCreateThread(for peerId: String, conversationType: ConversationType) async -> MessageThread {
        if let existing = try? await repository.thread(forPeer: peerId) {
            return existing
        }
        let threadId = conversationType == .nearby ? MessageThread.nearbyThreadId : UUID()
        let thread = MessageThread(
            threadId: threadId,
            peerId: peerId,
            conversationType: conversationType
        )
        try? await repository.saveThread(thread)
        await loadThreads()
        return thread
    }

    /// Call this when a new message arrives to refresh the thread list.
    public func refresh() async {
        await loadThreads()
    }
}
