import Testing
import Foundation
@testable import BaylanCore

@Suite("Identity")
struct IdentityTests {

    @Test("displayId returns first 8 characters of userId")
    func displayIdIsPrefix() {
        let identity = Identity(
            userId: "a3f7c9018b2de456ff001122",
            displayName: "Alice",
            publicKey: Data(),
            isSelf: true
        )
        #expect(identity.displayId == "a3f7c901")
    }

    @Test("Identity round-trips through Codable")
    func codableRoundTrip() throws {
        let original = Identity(
            userId: "abcdef1234567890abcdef12",
            displayName: "Bob",
            publicKey: Data([0x01, 0x02, 0x03]),
            isSelf: false,
            verified: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Identity.self, from: data)
        #expect(decoded.userId == original.userId)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.publicKey == original.publicKey)
        #expect(decoded.verified == original.verified)
    }
}
