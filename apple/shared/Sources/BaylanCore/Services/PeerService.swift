import Foundation
import Observation

@Observable
@MainActor
public final class PeerService {

    // MARK: - Published state

    public private(set) var nearbyPeers: [Peer] = []
    public private(set) var connectedPeerCount: Int = 0
    /// Set of full userIds currently in MCSession .connected state.
    public private(set) var connectedPeerIds: Set<String> = []

    public var connectionStatusText: String {
        if connectedPeerCount == 0 {
            return "Searching for peers…"
        } else if connectedPeerCount == 1 {
            return "Connected to 1 device"
        } else {
            return "Connected to \(connectedPeerCount) devices"
        }
    }

    public var isConnected: Bool { connectedPeerCount > 0 }

    // MARK: - Dependencies

    private let meshRouter: MeshRouter
    private let identityService: IdentityService
    private let repository: any MessageRepositoryProtocol

    // MARK: - Tasks

    nonisolated(unsafe) private var eventTask: Task<Void, Never>?
    nonisolated(unsafe) private var presenceTask: Task<Void, Never>?
    nonisolated(unsafe) private var cleanupTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        meshRouter: MeshRouter,
        identityService: IdentityService,
        repository: any MessageRepositoryProtocol
    ) {
        self.meshRouter = meshRouter
        self.identityService = identityService
        self.repository = repository
    }

    deinit {
        eventTask?.cancel()
        presenceTask?.cancel()
        cleanupTask?.cancel()
    }

    // MARK: - Lifecycle

    public func start() {
        startListeningToMeshEvents()
        startPresenceBroadcast()
        startStaleCleanup()
    }

    public func stop() {
        eventTask?.cancel()
        presenceTask?.cancel()
        cleanupTask?.cancel()
    }

    // MARK: - Private

    private func startListeningToMeshEvents() {
        eventTask = Task { [weak self] in
            guard let self else { return }
            let stream = meshRouter.subscribe()
            for await event in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.handle(meshEvent: event)
                }
            }
        }
    }

    private func handle(meshEvent event: MeshEvent) {
        switch event {
        case .presenceReceived(let identity):
            upsertPeer(identity)
            Task { try? await repository.saveIdentity(identity) }
        case .connectionStateChanged(let peerId, let state):
            // peerId is now the full userId (MCPeerID displayName == identity.userId)
            let isConnected = state == .connected
            if isConnected {
                connectedPeerIds.insert(peerId)
            } else {
                connectedPeerIds.remove(peerId)
            }
            if let idx = nearbyPeers.firstIndex(where: { $0.identity.userId == peerId }) {
                nearbyPeers[idx] = Peer(
                    identity: nearbyPeers[idx].identity,
                    isConnected: isConnected,
                    lastPresence: nearbyPeers[idx].lastPresence,
                    signalStrength: nearbyPeers[idx].signalStrength
                )
            }
            connectedPeerCount = nearbyPeers.filter { $0.isConnected }.count
            print("[Baylan][PeerService] \(String(peerId.prefix(8))) isConnected=\(isConnected) — connectedPeerCount=\(connectedPeerCount)")
        case .messageReceived, .ackReceived:
            break
        }
    }

    private func upsertPeer(_ identity: Identity) {
        if let idx = nearbyPeers.firstIndex(where: { $0.identity.userId == identity.userId }) {
            nearbyPeers[idx] = Peer(
                identity: identity,
                isConnected: nearbyPeers[idx].isConnected,
                lastPresence: Date(),
                signalStrength: nearbyPeers[idx].signalStrength
            )
        } else {
            nearbyPeers.append(Peer(identity: identity, isConnected: false, lastPresence: Date()))
        }
        nearbyPeers.sort { ($0.signalStrength ?? 0) > ($1.signalStrength ?? 0) }
    }

    private func startPresenceBroadcast() {
        presenceTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await self.broadcastPresence()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func broadcastPresence() async {
        let identity = await MainActor.run { identityService.localIdentity }
        var presence = BaylanPresenceAdvertisement()
        presence.senderID = identity.userId
        presence.displayName = identity.displayName
        presence.publicKey = identity.publicKey
        presence.timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        guard let presenceData = try? presence.serializedData() else { return }

        var envelope = BaylanMeshEnvelope()
        envelope.messageID = UUID().uuidString
        envelope.senderID = identity.userId
        envelope.recipientID = "nearby"
        envelope.payload = presenceData
        envelope.ttl = 2
        envelope.hopCount = 0
        envelope.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
        envelope.conversationType = .nearby

        try? await meshRouter.send(envelope)
    }

    private func startStaleCleanup() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { break }
                await MainActor.run {
                    self.nearbyPeers.removeAll { !$0.isNearby }
                    self.connectedPeerCount = self.nearbyPeers.filter { $0.isConnected }.count
                }
            }
        }
    }
}
