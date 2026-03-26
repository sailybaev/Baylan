import Foundation

public protocol MessageRepositoryProtocol: Sendable {
    // MARK: Messages
    func saveMessage(_ message: Message) async throws
    func messages(forThread threadId: UUID) async throws -> [Message]
    func updateMessageState(_ messageId: UUID, state: DeliveryState) async throws

    // MARK: Threads
    func saveThread(_ thread: MessageThread) async throws
    func allThreads() async throws -> [MessageThread]
    func thread(forPeer peerId: String) async throws -> MessageThread?
    func thread(forId threadId: UUID) async throws -> MessageThread?
    func deleteThread(_ threadId: UUID) async throws
    func updateUnreadCount(_ threadId: UUID, count: Int) async throws

    // MARK: Identities
    func saveIdentity(_ identity: Identity) async throws
    func identity(for userId: String) async throws -> Identity?
    func allIdentities() async throws -> [Identity]
}
