import Foundation

/// In-memory mock transport for unit testing all layers above the transport.
public final class MockTransport: TransportProtocol, @unchecked Sendable {

    public let events: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation

    public private(set) var sentMessages: [(data: Data, peerId: String)] = []
    public private(set) var isAdvertising = false
    public private(set) var isBrowsing = false
    private var _connectedPeerIds: [String] = []
    private let lock = NSLock()

    public init() {
        var continuation: AsyncStream<TransportEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    // MARK: - TransportProtocol

    public func startAdvertising() async { isAdvertising = true }
    public func stopAdvertising() async { isAdvertising = false }
    public func startBrowsing() async { isBrowsing = true }
    public func stopBrowsing() async { isBrowsing = false }

    public func send(_ data: Data, to peerId: String) async throws {
        lock.withLock { sentMessages.append((data, peerId)) }
    }

    public func disconnect(_ peerId: String) async {
        lock.withLock { _connectedPeerIds.removeAll { $0 == peerId } }
    }

    public func connectedPeerIds() async -> [String] {
        lock.withLock { _connectedPeerIds }
    }

    // MARK: - Test Helpers

    /// Simulate receiving data from a remote peer.
    public func simulateReceive(_ data: Data, from peerId: String) {
        continuation.yield(.dataReceived(data: data, fromPeerId: peerId))
    }

    /// Simulate a peer appearing on the mesh.
    public func simulatePeerFound(_ info: PeerInfo) {
        lock.withLock { _connectedPeerIds.append(info.peerId) }
        continuation.yield(.peerFound(info))
        continuation.yield(.connectionStateChanged(peerId: info.peerId, state: .connected))
    }

    /// Simulate a peer leaving the mesh.
    public func simulatePeerLost(peerId: String) {
        lock.withLock { _connectedPeerIds.removeAll { $0 == peerId } }
        continuation.yield(.peerLost(peerId: peerId))
    }

    /// Reset sent message history.
    public func resetSentMessages() {
        lock.withLock { sentMessages.removeAll() }
    }
}
