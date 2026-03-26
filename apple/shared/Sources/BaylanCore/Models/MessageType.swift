import Foundation

public enum BaylanMessageKind: String, Codable, Sendable, CaseIterable {
    case text
    case ack
    case presence
    case keyExchange
}
