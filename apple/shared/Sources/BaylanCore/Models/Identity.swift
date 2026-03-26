import Foundation

public struct Identity: Identifiable, Hashable, Sendable, Codable {
    public var id: String { userId }

    public let userId: String
    public var displayName: String
    public let publicKey: Data
    public let isSelf: Bool
    public let firstSeen: Date
    public var lastSeen: Date
    public var verified: Bool

    /// First 8 hex characters of userId — shown in UI as fingerprint.
    public var displayId: String {
        String(userId.prefix(8))
    }

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
