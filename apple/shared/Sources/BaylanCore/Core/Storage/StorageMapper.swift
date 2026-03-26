import Foundation

/// Maps between SwiftData @Model classes and domain structs.
public enum StorageMapper {

    // MARK: - Identity

    public static func toDomain(_ stored: StoredIdentity) -> Identity {
        Identity(
            userId: stored.userId,
            displayName: stored.displayName,
            publicKey: stored.publicKey,
            isSelf: stored.isSelf,
            firstSeen: stored.firstSeen,
            lastSeen: stored.lastSeen,
            verified: stored.verified
        )
    }

    public static func update(_ stored: StoredIdentity, from identity: Identity) {
        stored.displayName = identity.displayName
        stored.lastSeen = identity.lastSeen
        stored.verified = identity.verified
    }

    public static func toStored(_ identity: Identity) -> StoredIdentity {
        StoredIdentity(
            userId: identity.userId,
            displayName: identity.displayName,
            publicKey: identity.publicKey,
            isSelf: identity.isSelf,
            firstSeen: identity.firstSeen,
            lastSeen: identity.lastSeen,
            verified: identity.verified
        )
    }

    // MARK: - Message

    public static func toDomain(_ stored: StoredMessage) -> Message? {
        guard
            let messageId = UUID(uuidString: stored.messageIdString),
            let threadId = UUID(uuidString: stored.threadIdString),
            let type = BaylanMessageKind(rawValue: stored.typeRaw),
            let state = DeliveryState(rawValue: stored.stateRaw)
        else { return nil }

        return Message(
            messageId: messageId,
            threadId: threadId,
            senderId: stored.senderId,
            recipientId: stored.recipientId,
            body: stored.body,
            type: type,
            state: state,
            createdAt: stored.createdAt,
            deliveredAt: stored.deliveredAt,
            hopCount: stored.hopCount
        )
    }

    public static func toStored(_ message: Message) -> StoredMessage {
        StoredMessage(
            messageIdString: message.messageId.uuidString,
            threadIdString: message.threadId.uuidString,
            senderId: message.senderId,
            recipientId: message.recipientId,
            body: message.body,
            typeRaw: message.type.rawValue,
            stateRaw: message.state.rawValue,
            createdAt: message.createdAt,
            deliveredAt: message.deliveredAt,
            hopCount: message.hopCount
        )
    }

    // MARK: - Thread

    public static func toDomain(_ stored: StoredThread, lastMessage: Message? = nil) -> MessageThread? {
        guard
            let threadId = UUID(uuidString: stored.threadIdString),
            let conversationType = ConversationType(rawValue: stored.conversationTypeRaw)
        else { return nil }

        return MessageThread(
            threadId: threadId,
            peerId: stored.peerId,
            conversationType: conversationType,
            lastMessage: lastMessage,
            unreadCount: stored.unreadCount,
            updatedAt: stored.updatedAt
        )
    }

    public static func toStored(_ thread: MessageThread) -> StoredThread {
        StoredThread(
            threadIdString: thread.threadId.uuidString,
            peerId: thread.peerId,
            conversationTypeRaw: thread.conversationType.rawValue,
            lastMessageIdString: thread.lastMessage?.messageId.uuidString,
            unreadCount: thread.unreadCount,
            updatedAt: thread.updatedAt
        )
    }

    // MARK: - RelayQueueEntry

    public static func toDomain(_ stored: StoredRelayEntry) -> RelayQueueEntry? {
        guard let entryId = UUID(uuidString: stored.entryIdString) else { return nil }
        return RelayQueueEntry(
            entryId: entryId,
            envelopeData: stored.envelopeData,
            createdAt: stored.createdAt,
            storeTTL: stored.expiresAt.timeIntervalSince(stored.createdAt),
            attempts: stored.attempts
        )
    }

    public static func toStored(_ entry: RelayQueueEntry) -> StoredRelayEntry {
        StoredRelayEntry(
            entryIdString: entry.entryId.uuidString,
            envelopeData: entry.envelopeData,
            createdAt: entry.createdAt,
            expiresAt: entry.expiresAt,
            attempts: entry.attempts
        )
    }
}
