import Foundation

public struct RelayQueueEntry: Sendable {
    public let entryId: UUID
    public let envelopeData: Data
    public let createdAt: Date
    public let expiresAt: Date
    public var attempts: Int

    public var isExpired: Bool {
        Date() > expiresAt
    }

    public init(
        entryId: UUID = UUID(),
        envelopeData: Data,
        createdAt: Date = Date(),
        storeTTL: TimeInterval = 300,
        attempts: Int = 0
    ) {
        self.entryId = entryId
        self.envelopeData = envelopeData
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(storeTTL)
        self.attempts = attempts
    }
}
