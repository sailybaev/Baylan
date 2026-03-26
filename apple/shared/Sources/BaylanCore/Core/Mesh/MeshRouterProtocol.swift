import Foundation

public enum MeshEvent: Sendable {
    case messageReceived(Message)
    case presenceReceived(Identity)
    case ackReceived(messageId: String, senderId: String)
}

public protocol MeshRouterProtocol: Sendable {
    var events: AsyncStream<MeshEvent> { get }

    func start() async
    func stop() async
    func route(_ envelope: BaylanMeshEnvelope) async
    func send(_ envelope: BaylanMeshEnvelope) async throws
}
