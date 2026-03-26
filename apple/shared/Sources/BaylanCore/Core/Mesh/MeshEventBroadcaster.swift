import Foundation

/// Fans out a single stream of `MeshEvent` values to multiple independent `AsyncStream` listeners.
/// Each subscriber gets its own stream and receives every event — no racing.
public actor MeshEventBroadcaster {

    private var continuations: [UUID: AsyncStream<MeshEvent>.Continuation] = [:]

    public init() {}

    // MARK: - Subscription

    /// Returns a new `AsyncStream` that will receive every event yielded to this broadcaster.
    /// `nonisolated` so callers don't need to `await` and the resulting stream can be
    /// created synchronously; registration is dispatched onto the actor asynchronously.
    nonisolated public func subscribe() -> AsyncStream<MeshEvent> {
        let id = UUID()
        let broadcaster = self          // actor refs are Sendable — safe to capture
        return AsyncStream<MeshEvent> { continuation in
            // Both closures capture only Sendable types (UUID, actor ref)
            continuation.onTermination = { _ in
                Task { await broadcaster.unsubscribe(id: id) }
            }
            Task { await broadcaster.register(id: id, continuation: continuation) }
        }
    }

    private func register(id: UUID, continuation: AsyncStream<MeshEvent>.Continuation) {
        continuations[id] = continuation
    }

    private func unsubscribe(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    // MARK: - Publishing

    /// Broadcast an event to all current subscribers.
    public func yield(_ event: MeshEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    public func finish() {
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
    }
}
