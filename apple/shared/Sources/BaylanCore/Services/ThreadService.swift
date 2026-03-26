import Foundation
import Observation

@Observable
@MainActor
public final class ThreadService {

    // MARK: - Published state

    public private(set) var threads: [MessageThread] = []
    
    private var nameCache: [String: String] = [:]

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
            
            // Populate peer names
            for i in 0..<fetched.count {
                if !fetched[i].isNearbyChannel {
                    let peerId = fetched[i].peerId
                    if let cachedName = nameCache[peerId] {
                        fetched[i].peerName = cachedName
                    } else if let identity = try? await repository.identity(for: peerId) {
                        nameCache[peerId] = identity.displayName
                        fetched[i].peerName = identity.displayName
                    }
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
    
    /// Updates the in-memory cache for a peer's display name and immediately propagates it to active threads.
    public func updateCache(peerId: String, name: String) {
        nameCache[peerId] = name
        if let idx = threads.firstIndex(where: { $0.peerId == peerId && $0.peerName != name }) {
            threads[idx].peerName = name
        }
    }
}
