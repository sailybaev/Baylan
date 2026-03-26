import Foundation
import SwiftData

@Model
public final class StoredRelayEntry {
    @Attribute(.unique) public var entryIdString: String
    public var envelopeData: Data
    public var createdAt: Date
    public var expiresAt: Date
    public var attempts: Int

    public init(
        entryIdString: String,
        envelopeData: Data,
        createdAt: Date = Date(),
        expiresAt: Date,
        attempts: Int = 0
    ) {
        self.entryIdString = entryIdString
        self.envelopeData = envelopeData
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.attempts = attempts
    }
}
