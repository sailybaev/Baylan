import Foundation
import Network

/// Network.framework-based transport using Bonjour over regular Wi-Fi infrastructure.
/// Works on both iOS and Mac Catalyst (avoids AWDL/peer-to-peer limitations in Catalyst sandbox).
public final class NetworkFrameworkTransport: TransportProtocol, @unchecked Sendable {

    private static let serviceType = "_baylan-mesh._tcp"

    // MARK: - Events

    public let events: AsyncStream<TransportEvent>
    private let eventContinuation: AsyncStream<TransportEvent>.Continuation

    // MARK: - State

    private let localName: String
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.baylan.nwtransport", qos: .userInitiated)

    // MARK: - Init

    public init(displayName: String) {
        self.localName = displayName
        var cont: AsyncStream<TransportEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont
    }

    deinit {
        eventContinuation.finish()
    }

    // MARK: - TransportProtocol

    public func startAdvertising() async {
        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let l = try NWListener(using: params)
            l.service = NWListener.Service(name: localName, type: Self.serviceType)
            l.newConnectionHandler = { [weak self] conn in self?.acceptIncoming(conn) }
            l.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    print("[Baylan] Listener failed: \(error)")
                }
            }
            l.start(queue: queue)
            listener = l
        } catch {
            print("[Baylan] Failed to create listener: \(error)")
        }
    }

    public func stopAdvertising() async {
        listener?.cancel()
        listener = nil
    }

    public func startBrowsing() async {
        let params = NWParameters()
        params.includePeerToPeer = true

        let b = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: params)
        b.browseResultsChangedHandler = { [weak self] _, changes in
            guard let self else { return }
            for change in changes {
                switch change {
                case .added(let result):
                    guard case .service(let name, _, _, _) = result.endpoint,
                          name != self.localName else { continue }
                    self.connectOutbound(to: result.endpoint, peerId: name)
                case .removed(let result):
                    guard case .service(let name, _, _, _) = result.endpoint else { continue }
                    self.dropConnection(peerId: name)
                default: break
                }
            }
        }
        b.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("[Baylan] Browser failed: \(error)")
            }
        }
        b.start(queue: queue)
        browser = b
    }

    public func stopBrowsing() async {
        browser?.cancel()
        browser = nil
    }

    public func send(_ data: Data, to peerId: String) async throws {
        guard let conn = lock.withLock({ connections[peerId] }) else { return }
        let frame = frame(data)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: frame, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            })
        }
    }

    public func disconnect(_ peerId: String) async {
        dropConnection(peerId: peerId)
    }

    public func connectedPeerIds() async -> [String] {
        lock.withLock { Array(connections.keys) }
    }

    // MARK: - Outbound connection (browser side)

    private func connectOutbound(to endpoint: NWEndpoint, peerId: String) {
        // Avoid double-connecting
        guard lock.withLock({ connections[peerId] == nil }) else { return }

        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let conn = NWConnection(to: endpoint, using: params)

        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                // Send handshake: our display name
                let handshake = self.frame(Data(self.localName.utf8))
                conn.send(content: handshake, completion: .contentProcessed { _ in })
                self.registerConnection(conn, peerId: peerId)
            case .failed(let error):
                print("[Baylan] Outbound connection to \(peerId) failed: \(error)")
                self.lock.withLock { self.connections.removeValue(forKey: peerId) }
                self.eventContinuation.yield(.connectionStateChanged(peerId: peerId, state: .disconnected))
                self.eventContinuation.yield(.peerLost(peerId: peerId))
            case .cancelled:
                self.lock.withLock { self.connections.removeValue(forKey: peerId) }
            default: break
            }
        }
        conn.start(queue: queue)
    }

    // MARK: - Inbound connection (listener side)

    private func acceptIncoming(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                // Read handshake to discover peer's name
                self.readHandshake(from: conn)
            case .failed(let error):
                print("[Baylan] Inbound connection failed: \(error)")
                conn.cancel()
            case .cancelled: break
            default: break
            }
        }
        conn.start(queue: queue)
    }

    private func readHandshake(from conn: NWConnection) {
        receiveFrame(from: conn) { [weak self] data in
            guard let self, let data, let peerId = String(data: data, encoding: .utf8) else {
                conn.cancel()
                return
            }
            // If already connected (e.g. we initiated outbound), drop this duplicate
            if lock.withLock({ connections[peerId] != nil }) {
                conn.cancel()
                return
            }
            self.registerConnection(conn, peerId: peerId)
        }
    }

    // MARK: - Shared connection management

    private func registerConnection(_ conn: NWConnection, peerId: String) {
        lock.withLock { connections[peerId] = conn }
        eventContinuation.yield(.peerFound(PeerInfo(peerId: peerId, displayName: peerId)))
        eventContinuation.yield(.connectionStateChanged(peerId: peerId, state: .connected))
        receiveLoop(from: conn, peerId: peerId)
    }

    private func dropConnection(peerId: String) {
        let conn = lock.withLock { connections.removeValue(forKey: peerId) }
        conn?.cancel()
        eventContinuation.yield(.peerLost(peerId: peerId))
    }

    // MARK: - Framing (4-byte big-endian length prefix)

    private func frame(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        return Data(bytes: &length, count: 4) + data
    }

    private func receiveFrame(from conn: NWConnection, completion: @escaping (Data?) -> Void) {
        conn.receive(minimumIncompleteLength: 4, maximumLength: 4) { header, _, _, error in
            guard let header, header.count == 4, error == nil else {
                completion(nil)
                return
            }
            let length = Int(UInt32(bigEndian: header.withUnsafeBytes { $0.load(as: UInt32.self) }))
            guard length > 0, length < 10_000_000 else { completion(nil); return }

            conn.receive(minimumIncompleteLength: length, maximumLength: length) { body, _, _, error in
                completion(error == nil ? body : nil)
            }
        }
    }

    private func receiveLoop(from conn: NWConnection, peerId: String) {
        receiveFrame(from: conn) { [weak self] data in
            guard let self else { return }
            if let data {
                self.eventContinuation.yield(.dataReceived(data: data, fromPeerId: peerId))
                self.receiveLoop(from: conn, peerId: peerId)
            } else {
                // Connection closed
                self.lock.withLock { self.connections.removeValue(forKey: peerId) }
                self.eventContinuation.yield(.connectionStateChanged(peerId: peerId, state: .disconnected))
                self.eventContinuation.yield(.peerLost(peerId: peerId))
            }
        }
    }
}
