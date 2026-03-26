import Foundation

/// Named MessageThread to avoid collision with Swift's Thread type.
public struct MessageThread: Identifiable, Sendable {
    public var id: UUID { threadId }

    /// Well-known thread ID for the Nearby public mesh channel.
    public static let nearbyThreadId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    public let threadId: UUID
    public let peerId: String
    public let conversationType: ConversationType
    public var lastMessage: Message?
    public var unreadCount: Int
    public var updatedAt: Date
    
    /// Optional assigned name of the peer, used for display.
    public var peerName: String?

    public var isNearbyChannel: Bool {
        threadId == MessageThread.nearbyThreadId
    }

    /// Human-readable name shown in the conversation list.
    public var displayName: String {
        isNearbyChannel ? "Nearby" : (peerName ?? String(peerId.prefix(8)))
    }

    public init(
        threadId: UUID = UUID(),
        peerId: String,
        conversationType: ConversationType,
        lastMessage: Message? = nil,
        unreadCount: Int = 0,
        updatedAt: Date = Date(),
        peerName: String? = nil
    ) {
        self.threadId = threadId
        self.peerId = peerId
        self.conversationType = conversationType
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.updatedAt = updatedAt
        self.peerName = peerName
    }

    /// Pre-built nearby channel thread, always available.
    public static var nearbyChannel: MessageThread {
        MessageThread(
            threadId: nearbyThreadId,
            peerId: "nearby",
            conversationType: .nearby
        )
    }
}
