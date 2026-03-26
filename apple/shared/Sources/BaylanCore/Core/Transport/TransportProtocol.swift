import Foundation

public protocol TransportProtocol: Sendable {
    var events: AsyncStream<TransportEvent> { get }

    func startAdvertising() async
    func stopAdvertising() async
    func startBrowsing() async
    func stopBrowsing() async
    func send(_ data: Data, to peerId: String) async throws
    func disconnect(_ peerId: String) async
    func connectedPeerIds() async -> [String]
}
