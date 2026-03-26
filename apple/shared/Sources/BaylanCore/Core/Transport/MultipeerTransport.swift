import Foundation
import MultipeerConnectivity

/// Multipeer Connectivity transport implementation.
/// Handles peer discovery, session management, and data transfer over Wi-Fi Direct + BLE.
public final class MultipeerTransport: NSObject, TransportProtocol, @unchecked Sendable {

    // MARK: - Constants

    /// Must be 1–15 characters, lowercase ASCII/hyphens.
    private static let serviceType = "baylan-mesh"

    // MARK: - Events stream

    public let events: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation

    // MARK: - MCFramework objects

    private let localPeerId: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    // MARK: - State

    private var connectedPeers: Set<String> = []
    private let lock = NSLock()

    // MARK: - Init

    public init(displayName: String) {
        self.localPeerId = MCPeerID(displayName: displayName)

        var continuation: AsyncStream<TransportEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation

        self.session = MCSession(
            peer: localPeerId,
            securityIdentity: nil,
            encryptionPreference: .optional
        )
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: localPeerId,
            discoveryInfo: nil,
            serviceType: MultipeerTransport.serviceType
        )
        self.browser = MCNearbyServiceBrowser(
            peer: localPeerId,
            serviceType: MultipeerTransport.serviceType
        )
        super.init()

        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    deinit {
        continuation.finish()
    }

    // MARK: - TransportProtocol

    public func startAdvertising() async {
        advertiser.startAdvertisingPeer()
    }

    public func stopAdvertising() async {
        advertiser.stopAdvertisingPeer()
    }

    public func startBrowsing() async {
        browser.startBrowsingForPeers()
    }

    public func stopBrowsing() async {
        browser.stopBrowsingForPeers()
    }

    public func send(_ data: Data, to peerId: String) async throws {
        let peers = session.connectedPeers.filter { $0.displayName == peerId }
        guard !peers.isEmpty else { return }
        try session.send(data, toPeers: peers, with: .reliable)
    }

    public func disconnect(_ peerId: String) async {
        session.disconnect()
    }

    public func connectedPeerIds() async -> [String] {
        session.connectedPeers.map { $0.displayName }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerTransport: MCSessionDelegate {

    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let connectionState: ConnectionState
        switch state {
        case .connecting:  connectionState = .connecting
        case .connected:   connectionState = .connected
        case .notConnected: connectionState = .disconnected
        @unknown default:  connectionState = .disconnected
        }
        lock.withLock {
            if state == .connected {
                connectedPeers.insert(peerID.displayName)
            } else {
                connectedPeers.remove(peerID.displayName)
            }
        }
        continuation.yield(.connectionStateChanged(peerId: peerID.displayName, state: connectionState))
        if state == .notConnected {
            continuation.yield(.peerLost(peerId: peerID.displayName))
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        continuation.yield(.dataReceived(data: data, fromPeerId: peerID.displayName))
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept all invitations in mesh mode
        invitationHandler(true, session)
    }

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        print("[Baylan] Advertiser failed: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {

    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        continuation.yield(.peerFound(PeerInfo(peerId: peerID.displayName, displayName: peerID.displayName)))
        // Auto-invite: no UI confirmation needed in mesh mode
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        continuation.yield(.peerLost(peerId: peerID.displayName))
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        print("[Baylan] Browser failed: \(error)")
    }
}
