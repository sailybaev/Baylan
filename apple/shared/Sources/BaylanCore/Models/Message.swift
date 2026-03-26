import Foundation

public struct Message: Identifiable, Sendable, Codable {
    public var id: UUID { messageId }

    public let messageId: UUID
    public let threadId: UUID
    public let senderId: String
    public let recipientId: String
    public let body: String?
    public let type: BaylanMessageKind
    public var state: DeliveryState
    public let createdAt: Date
    public var deliveredAt: Date?
    public let hopCount: Int

    public init(
        messageId: UUID = UUID(),
        threadId: UUID,
        senderId: String,
        recipientId: String,
        body: String?,
        type: BaylanMessageKind,
        state: DeliveryState = .sending,
        createdAt: Date = Date(),
        deliveredAt: Date? = nil,
        hopCount: Int = 0
    ) {
        self.messageId = messageId
        self.threadId = threadId
        self.senderId = senderId
        self.recipientId = recipientId
        self.body = body
        self.type = type
        self.state = state
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.hopCount = hopCount
    }
}
