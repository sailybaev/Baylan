import Foundation

/// Actor-isolated store-and-forward queue.
/// Holds undeliverable envelopes and attempts redelivery when new peers connect.
public actor RelayQueue {

    private var entries: [RelayQueueEntry] = []

    public init() {}

    // MARK: - Public

    public func enqueue(_ entry: RelayQueueEntry) {
        purgeExpired()
        entries.append(entry)
    }

    public func allPending() -> [RelayQueueEntry] {
        purgeExpired()
        return entries
    }

    public func remove(entryId: UUID) {
        entries.removeAll { $0.entryId == entryId }
    }

    public func incrementAttempts(entryId: UUID) {
        if let idx = entries.firstIndex(where: { $0.entryId == entryId }) {
            entries[idx].attempts += 1
        }
    }

    public var count: Int {
        entries.count
    }

    // MARK: - Private

    private func purgeExpired() {
        entries.removeAll { $0.isExpired }
    }
}
