import Foundation
import SwiftData

@Model
public final class StoredMessage {
    @Attribute(.unique) public var messageIdString: String
    public var threadIdString: String
    public var senderId: String
    public var recipientId: String
    public var body: String?
    public var typeRaw: String
    public var stateRaw: String
    public var createdAt: Date
    public var deliveredAt: Date?
    public var hopCount: Int

    public init(
        messageIdString: String,
        threadIdString: String,
        senderId: String,
        recipientId: String,
        body: String?,
        typeRaw: String,
        stateRaw: String,
        createdAt: Date,
        deliveredAt: Date? = nil,
        hopCount: Int = 0
    ) {
        self.messageIdString = messageIdString
        self.threadIdString = threadIdString
        self.senderId = senderId
        self.recipientId = recipientId
        self.body = body
        self.typeRaw = typeRaw
        self.stateRaw = stateRaw
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.hopCount = hopCount
    }
}
