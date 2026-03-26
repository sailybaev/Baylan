import Foundation
import Observation

@Observable
@MainActor
public final class DiscoveryViewModel {

    public var nearbyPeers: [Peer] {
        peerService.nearbyPeers.filter { $0.isNearby }
    }

    public var isSearching: Bool {
        peerService.nearbyPeers.isEmpty
    }

    private let peerService: PeerService
    private let threadService: ThreadService

    public init(peerService: PeerService, threadService: ThreadService) {
        self.peerService = peerService
        self.threadService = threadService
    }

    /// Returns the thread ID to navigate to after starting a chat.
    @discardableResult
    public func startChat(with peer: Peer) async -> UUID {
        let thread = await threadService.getOrCreateThread(
            for: peer.identity.userId,
            conversationType: .direct
        )
        return thread.threadId
    }
}
