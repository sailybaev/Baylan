import Foundation

public struct Peer: Identifiable, Sendable {
    public var id: String { identity.userId }

    public let identity: Identity
    public var isConnected: Bool
    public var lastPresence: Date?
    /// Signal strength heuristic 0.0–1.0 (derived from transport metadata).
    public var signalStrength: Double?

    /// True if a presence message was received within the last 90 seconds.
    public var isNearby: Bool {
        guard let last = lastPresence else { return false }
        return Date().timeIntervalSince(last) < 90
    }

    /// Human-readable distance approximation based on signal strength.
    public var distanceLabel: String {
        guard let strength = signalStrength else { return "Nearby" }
        switch strength {
        case 0.8...: return "~5m"
        case 0.5..<0.8: return "~20m"
        case 0.2..<0.5: return "~50m"
        default: return "~100m"
        }
    }

    public init(identity: Identity, isConnected: Bool = false, lastPresence: Date? = nil, signalStrength: Double? = nil) {
        self.identity = identity
        self.isConnected = isConnected
        self.lastPresence = lastPresence
        self.signalStrength = signalStrength
    }
}
