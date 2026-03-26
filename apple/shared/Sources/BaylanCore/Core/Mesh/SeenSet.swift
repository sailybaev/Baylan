import Foundation
import Collections

/// Thread-safe actor that tracks recently-seen message IDs to prevent forwarding loops.
/// Uses a fixed-size LRU eviction policy and a time-based TTL.
public actor SeenSet {

    private static let maxCapacity = 2048
    private static let ttl: TimeInterval = 600 // 10 minutes

    private var store: OrderedDictionary<String, Date> = [:]

    public init() {}

    public func contains(_ messageId: String) -> Bool {
        guard let seenAt = store[messageId] else { return false }
        if Date().timeIntervalSince(seenAt) > SeenSet.ttl {
            store.removeValue(forKey: messageId)
            return false
        }
        return true
    }

    public func insert(_ messageId: String) {
        evictStale()
        if store.count >= SeenSet.maxCapacity {
            store.removeFirst()
        }
        store[messageId] = Date()
    }

    // MARK: - Private

    private func evictStale() {
        let cutoff = Date().addingTimeInterval(-SeenSet.ttl)
        store = store.filter { $0.value > cutoff }
    }
}
