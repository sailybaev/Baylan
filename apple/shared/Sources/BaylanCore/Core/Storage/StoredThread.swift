import Foundation
import SwiftData

@Model
public final class StoredThread {
    @Attribute(.unique) public var threadIdString: String
    public var peerId: String
    public var conversationTypeRaw: String
    public var lastMessageIdString: String?
    public var unreadCount: Int
    public var updatedAt: Date

    public init(
        threadIdString: String,
        peerId: String,
        conversationTypeRaw: String,
        lastMessageIdString: String? = nil,
        unreadCount: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.threadIdString = threadIdString
        self.peerId = peerId
        self.conversationTypeRaw = conversationTypeRaw
        self.lastMessageIdString = lastMessageIdString
        self.unreadCount = unreadCount
        self.updatedAt = updatedAt
    }
}
