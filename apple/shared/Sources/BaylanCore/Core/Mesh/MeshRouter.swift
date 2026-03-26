import Foundation
import SwiftProtobuf

/// Epidemic mesh router. Receives raw bytes from transport, parses envelopes,
/// applies routing rules (verify → dedup → TTL → deliver/relay), and emits domain events.
public final class MeshRouter: MeshRouterProtocol, @unchecked Sendable {

    // MARK: - Broadcaster (fan-out — supports multiple independent subscribers)

    private let broadcaster = MeshEventBroadcaster()

    /// Subscribe to get an independent stream of mesh events.
    /// Each caller gets its own AsyncStream — every event is delivered to every subscriber.
    /// Use this instead of `.events` when more than one consumer is needed.
    public func subscribe() -> AsyncStream<MeshEvent> {
        broadcaster.subscribe()
    }

    /// Single-consumer stream kept for `MeshRouterProtocol` conformance.
    /// If you need a second consumer, call `subscribe()` instead.
    public nonisolated(unsafe) var events: AsyncStream<MeshEvent> = AsyncStream { _ in }

    // MARK: - Dependencies

    private let transport: any TransportProtocol
    private let seenSet: SeenSet
    private let localUserId: String
    private let crypto: any CryptoEngineProtocol
    private let signingPrivateKey: Data
    /// Maps user_id → Identity for signature verification. Updated by PeerService.
    private var knownPeers: [String: Identity] = [:]

    // MARK: - Send Queue

    private struct QueuedEnvelope: Sendable {
        let envelope: BaylanMeshEnvelope
        let created: Date
    }
    private var sendQueue: [QueuedEnvelope] = []

    private let lock = NSLock()

    // MARK: - Lifecycle

    private var routingTask: Task<Void, Never>?

    public init(
        transport: any TransportProtocol,
        localUserId: String,
        crypto: any CryptoEngineProtocol,
        signingPrivateKey: Data
    ) {
        self.transport = transport
        self.seenSet = SeenSet()
        self.localUserId = localUserId
        self.crypto = crypto
        self.signingPrivateKey = signingPrivateKey
    }

    deinit {
        routingTask?.cancel()
        Task { [broadcaster] in await broadcaster.finish() }
    }

    // MARK: - MeshRouterProtocol

    public func start() async {
        // Wire up the protocol-conformance events stream as one subscription
        events = broadcaster.subscribe()
        await transport.startAdvertising()
        await transport.startBrowsing()
        routingTask = Task { [weak self] in
            guard let self else { return }
            for await event in transport.events {
                await self.handle(transportEvent: event)
            }
        }
    }

    public func stop() async {
        routingTask?.cancel()
        routingTask = nil
        await transport.stopAdvertising()
        await transport.stopBrowsing()
    }

    public func route(_ envelope: BaylanMeshEnvelope) async {
        await process(envelope: envelope, fromPeerId: nil)
    }

    public func send(_ envelope: BaylanMeshEnvelope) async throws {
        let isDirect = envelope.conversationType == .direct
        let targetId = envelope.recipientID
        let peers = await transport.connectedPeerIds()

        if isDirect && targetId != "nearby" {
            if peers.contains(targetId) {
                let data = try envelope.serializedData()
                try await transport.send(data, to: targetId)
            } else {
                lock.withLock { sendQueue.append(QueuedEnvelope(envelope: envelope, created: Date())) }
            }
        } else {
            let data = try envelope.serializedData()
            for peerId in peers {
                try? await transport.send(data, to: peerId)
            }
        }
    }

    // MARK: - Peer registry (used by PeerService)

    public func registerPeer(_ identity: Identity) {
        lock.withLock { knownPeers[identity.userId] = identity }
    }

    public func removePeer(userId: String) {
        lock.withLock { knownPeers.removeValue(forKey: userId) }
    }

    // MARK: - Private

    private func handle(transportEvent event: TransportEvent) async {
        switch event {
        case .dataReceived(let data, let fromPeerId):
            guard let envelope = try? BaylanMeshEnvelope(serializedBytes: data) else { return }
            await process(envelope: envelope, fromPeerId: fromPeerId)
        case .connectionStateChanged(let peerId, let state):
            if state == .connected {
                await drainQueue()
            }
            await broadcaster.yield(.connectionStateChanged(peerId: peerId, state: state))
        case .peerFound, .peerLost:
            break
        }
    }

    private func drainQueue() async {
        let validPeers = await transport.connectedPeerIds()
        guard !validPeers.isEmpty else { return }

        let now = Date()
        let toFlush = lock.withLock { () -> [QueuedEnvelope] in
            let valid = sendQueue.filter { now.timeIntervalSince($0.created) < 86400 }
            sendQueue = []
            return valid
        }

        for item in toFlush {
            let targetId = item.envelope.recipientID
            if validPeers.contains(targetId) {
                if let data = try? item.envelope.serializedData() {
                    try? await transport.send(data, to: targetId)
                }
            } else {
                lock.withLock { sendQueue.append(item) }
            }
        }
    }

    /// Core routing logic — applied to every received envelope.
    private func process(envelope: BaylanMeshEnvelope, fromPeerId: String?) async {
        // 1. Signature verification — only if we know the sender's public key
        let senderIdentity = lock.withLock { knownPeers[envelope.senderID] }
        if let identity = senderIdentity {
            let signingPubKey = identity.publicKey.prefix(32)
            guard (try? EnvelopeBuilder.verifySignature(of: envelope, senderPublicKey: signingPubKey, crypto: crypto)) == true else {
                return
            }
        }

        // 2. Duplicate check
        let messageId = envelope.messageID
        if await seenSet.contains(messageId) { return }
        await seenSet.insert(messageId)

        // 3. TTL check
        var mutableEnvelope = envelope
        guard mutableEnvelope.ttl > 0 else { return }
        mutableEnvelope.ttl -= 1

        // 4. Deliver if addressed to us
        let isForMe = mutableEnvelope.recipientID == localUserId
        let isNearby = mutableEnvelope.recipientID == "nearby"

        if isForMe {
            await deliverToInbox(mutableEnvelope)
            if let ack = try? EnvelopeBuilder.buildAck(
                originalMessageId: messageId,
                senderId: localUserId,
                recipientId: mutableEnvelope.senderID,
                signingPrivateKey: signingPrivateKey,
                crypto: crypto
            ) {
                try? await send(ack)
            }
            return
        }

        if isNearby {
            await deliverToInbox(mutableEnvelope)
        }

        // 5. Relay to all connected peers except original sender
        guard mutableEnvelope.ttl > 0 else { return }
        mutableEnvelope.hopCount += 1
        guard let data = try? mutableEnvelope.serializedData() else { return }
        let peers = await transport.connectedPeerIds()
        for peerId in peers where peerId != fromPeerId {
            try? await transport.send(data, to: peerId)
        }
    }

    private func deliverToInbox(_ envelope: BaylanMeshEnvelope) async {
        // Handle presence advertisements
        if envelope.conversationType == .nearby,
           let presenceData = try? BaylanPresenceAdvertisement(serializedBytes: envelope.payload) {
            let identity = Identity(
                userId: presenceData.senderID,
                displayName: presenceData.displayName,
                publicKey: presenceData.publicKey,
                isSelf: false,
                lastSeen: Date(),
                verified: false
            )
            await broadcaster.yield(.presenceReceived(identity))
            return
        }

        // Handle ACKs
        if let msgPayload = try? BaylanMessagePayload(serializedBytes: envelope.payload),
           msgPayload.type == .ack {
            let ackMsgId = envelope.messageID
            await broadcaster.yield(.ackReceived(messageId: ackMsgId, senderId: envelope.senderID))
            return
        }

        // Build domain Message
        let threadId: UUID
        if envelope.conversationType == .nearby {
            threadId = MessageThread.nearbyThreadId
        } else if let parsed = try? BaylanMessagePayload(serializedBytes: envelope.payload),
                  let tid = UUID(uuidString: parsed.threadID) {
            threadId = tid
        } else {
            threadId = UUID()
        }

        let body: String?
        if envelope.conversationType == .nearby,
           let payload = try? BaylanMessagePayload(serializedBytes: envelope.payload) {
            body = payload.body.isEmpty ? nil : payload.body
        } else {
            body = nil
        }

        let message = Message(
            threadId: threadId,
            senderId: envelope.senderID,
            recipientId: envelope.recipientID,
            body: body,
            type: .text,
            state: .delivered,
            createdAt: Date(timeIntervalSince1970: Double(envelope.createdAt) / 1000),
            hopCount: Int(envelope.hopCount),
            payload: envelope.conversationType == .direct ? envelope.payload : nil
        )
        await broadcaster.yield(.messageReceived(message))
    }
}
