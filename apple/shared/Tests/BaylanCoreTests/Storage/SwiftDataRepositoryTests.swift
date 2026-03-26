import Testing
import Foundation
import SwiftData
@testable import BaylanCore

@Suite("SwiftDataMessageRepository")
struct SwiftDataRepositoryTests {

    func makeRepository() throws -> SwiftDataMessageRepository {
        let container = try SwiftDataMessageRepository.makeContainer(inMemory: true)
        return SwiftDataMessageRepository(modelContainer: container)
    }

    @Test("Save and fetch message")
    func saveAndFetchMessage() async throws {
        let repo = try makeRepository()
        let threadId = UUID()

        // Save the thread first
        let thread = MessageThread(threadId: threadId, peerId: "alice", conversationType: .direct)
        try await repo.saveThread(thread)

        let message = Message(
            threadId: threadId,
            senderId: "alice",
            recipientId: "bob",
            body: "Hello",
            type: .text
        )
        try await repo.saveMessage(message)

        let fetched = try await repo.messages(forThread: threadId)
        #expect(fetched.count == 1)
        #expect(fetched.first?.body == "Hello")
        #expect(fetched.first?.senderId == "alice")
    }

    @Test("Update message state")
    func updateMessageState() async throws {
        let repo = try makeRepository()
        let threadId = UUID()
        let thread = MessageThread(threadId: threadId, peerId: "alice", conversationType: .direct)
        try await repo.saveThread(thread)

        let message = Message(threadId: threadId, senderId: "alice", recipientId: "bob", body: nil, type: .text, state: .sending)
        try await repo.saveMessage(message)

        try await repo.updateMessageState(message.messageId, state: .delivered)
        let fetched = try await repo.messages(forThread: threadId)
        #expect(fetched.first?.state == .delivered)
        #expect(fetched.first?.deliveredAt != nil)
    }

    @Test("Save and fetch thread")
    func saveAndFetchThread() async throws {
        let repo = try makeRepository()
        let thread = MessageThread(threadId: UUID(), peerId: "alice", conversationType: .direct)
        try await repo.saveThread(thread)

        let fetched = try await repo.thread(forPeer: "alice")
        #expect(fetched?.peerId == "alice")
        #expect(fetched?.conversationType == .direct)
    }

    @Test("All threads returns sorted by updatedAt")
    func allThreadsSorted() async throws {
        let repo = try makeRepository()
        let t1 = MessageThread(threadId: UUID(), peerId: "alice", conversationType: .direct, updatedAt: Date(timeIntervalSinceNow: -100))
        let t2 = MessageThread(threadId: UUID(), peerId: "bob", conversationType: .direct, updatedAt: Date())
        try await repo.saveThread(t1)
        try await repo.saveThread(t2)

        let all = try await repo.allThreads()
        #expect(all.first?.peerId == "bob")
    }

    @Test("Save and fetch identity")
    func saveAndFetchIdentity() async throws {
        let repo = try makeRepository()
        let identity = Identity(userId: "abc123", displayName: "Alice", publicKey: Data([1, 2, 3]), isSelf: false)
        try await repo.saveIdentity(identity)

        let fetched = try await repo.identity(for: "abc123")
        #expect(fetched?.displayName == "Alice")
        #expect(fetched?.publicKey == Data([1, 2, 3]))
    }

    @Test("Update unread count")
    func updateUnreadCount() async throws {
        let repo = try makeRepository()
        let threadId = UUID()
        let thread = MessageThread(threadId: threadId, peerId: "carol", conversationType: .direct)
        try await repo.saveThread(thread)

        try await repo.updateUnreadCount(threadId, count: 5)
        let fetched = try await repo.thread(forPeer: "carol")
        #expect(fetched?.unreadCount == 5)
    }
}
