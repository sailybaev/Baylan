import Foundation

public enum ConnectionState: Sendable {
    case connecting
    case connected
    case disconnected
}

public struct PeerInfo: Sendable {
    public let peerId: String
    public let displayName: String

    public init(peerId: String, displayName: String) {
        self.peerId = peerId
        self.displayName = displayName
    }
}

public enum TransportEvent: Sendable {
    case peerFound(PeerInfo)
    case peerLost(peerId: String)
    case dataReceived(data: Data, fromPeerId: String)
    case connectionStateChanged(peerId: String, state: ConnectionState)
}
