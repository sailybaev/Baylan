import Foundation
import SwiftData

@Model
public final class StoredIdentity {
    @Attribute(.unique) public var userId: String
    public var displayName: String
    public var publicKey: Data
    public var isSelf: Bool
    public var firstSeen: Date
    public var lastSeen: Date
    public var verified: Bool

    public init(
        userId: String,
        displayName: String,
        publicKey: Data,
        isSelf: Bool,
        firstSeen: Date = Date(),
        lastSeen: Date = Date(),
        verified: Bool = false
    ) {
        self.userId = userId
        self.displayName = displayName
        self.publicKey = publicKey
        self.isSelf = isSelf
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.verified = verified
    }
}
