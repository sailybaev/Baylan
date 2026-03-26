import Foundation
import SwiftData

@ModelActor
public actor SwiftDataMessageRepository: MessageRepositoryProtocol {

    // MARK: - Schema

    public static var schema: Schema {
        Schema([
            StoredMessage.self,
            StoredThread.self,
            StoredIdentity.self,
            StoredRelayEntry.self
        ])
    }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Messages

    public func saveMessage(_ message: Message) throws {
        let stored = StorageMapper.toStored(message)
        modelContext.insert(stored)

        // Upsert thread: create if missing, update lastMessage + updatedAt
        let threadIdStr = message.threadId.uuidString
        let threads = try modelContext.fetch(
            FetchDescriptor<StoredThread>(predicate: #Predicate { $0.threadIdString == threadIdStr })
        )
        if let thread = threads.first {
            thread.lastMessageIdString = message.messageId.uuidString
            thread.updatedAt = message.createdAt
        }
        try modelContext.save()
    }

    public func messages(forThread threadId: UUID) throws -> [Message] {
        let threadIdStr = threadId.uuidString
        let descriptor = FetchDescriptor<StoredMessage>(
            predicate: #Predicate { $0.threadIdString == threadIdStr },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).compactMap { StorageMapper.toDomain($0) }
    }

    public func updateMessageState(_ messageId: UUID, state: DeliveryState) throws {
        let idStr = messageId.uuidString
        let results = try modelContext.fetch(
            FetchDescriptor<StoredMessage>(predicate: #Predicate { $0.messageIdString == idStr })
        )
        results.first?.stateRaw = state.rawValue
        if state == .delivered {
            results.first?.deliveredAt = Date()
        }
        try modelContext.save()
    }

    // MARK: - Threads

    public func saveThread(_ thread: MessageThread) throws {
        let threadIdStr = thread.threadId.uuidString
        let existing = try modelContext.fetch(
            FetchDescriptor<StoredThread>(predicate: #Predicate { $0.threadIdString == threadIdStr })
        )
        if let stored = existing.first {
            stored.unreadCount = thread.unreadCount
            stored.updatedAt = thread.updatedAt
            stored.lastMessageIdString = thread.lastMessage?.messageId.uuidString
        } else {
            modelContext.insert(StorageMapper.toStored(thread))
        }
        try modelContext.save()
    }

    public func allThreads() throws -> [MessageThread] {
        let descriptor = FetchDescriptor<StoredThread>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).compactMap { StorageMapper.toDomain($0) }
    }

    public func thread(forPeer peerId: String) throws -> MessageThread? {
        let results = try modelContext.fetch(
            FetchDescriptor<StoredThread>(predicate: #Predicate { $0.peerId == peerId })
        )
        return results.first.flatMap { StorageMapper.toDomain($0) }
    }

    public func thread(forId threadId: UUID) throws -> MessageThread? {
        let idStr = threadId.uuidString
        let results = try modelContext.fetch(
            FetchDescriptor<StoredThread>(predicate: #Predicate { $0.threadIdString == idStr })
        )
        return results.first.flatMap { StorageMapper.toDomain($0) }
    }

    public func deleteThread(_ threadId: UUID) throws {
        let idStr = threadId.uuidString
        let threads = try modelContext.fetch(
            FetchDescriptor<StoredThread>(predicate: #Predicate { $0.threadIdString == idStr })
        )
        threads.forEach { modelContext.delete($0) }

        let msgs = try modelContext.fetch(
            FetchDescriptor<StoredMessage>(predicate: #Predicate { $0.threadIdString == idStr })
        )
        msgs.forEach { modelContext.delete($0) }
        try modelContext.save()
    }

    public func updateUnreadCount(_ threadId: UUID, count: Int) throws {
        let idStr = threadId.uuidString
        let results = try modelContext.fetch(
            FetchDescriptor<StoredThread>(predicate: #Predicate { $0.threadIdString == idStr })
        )
        results.first?.unreadCount = count
        try modelContext.save()
    }

    // MARK: - Identities

    public func saveIdentity(_ identity: Identity) throws {
        let existing = try modelContext.fetch(
            FetchDescriptor<StoredIdentity>(predicate: #Predicate { $0.userId == identity.userId })
        )
        if let stored = existing.first {
            StorageMapper.update(stored, from: identity)
        } else {
            modelContext.insert(StorageMapper.toStored(identity))
        }
        try modelContext.save()
    }

    public func identity(for userId: String) throws -> Identity? {
        let results = try modelContext.fetch(
            FetchDescriptor<StoredIdentity>(predicate: #Predicate { $0.userId == userId })
        )
        return results.first.map { StorageMapper.toDomain($0) }
    }

    public func allIdentities() throws -> [Identity] {
        try modelContext.fetch(FetchDescriptor<StoredIdentity>()).map { StorageMapper.toDomain($0) }
    }
}
