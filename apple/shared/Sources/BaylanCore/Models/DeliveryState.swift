import Foundation

public enum DeliveryState: String, Codable, Sendable, CaseIterable {
    case sending
    case relayed
    case delivered
    case failed
}
