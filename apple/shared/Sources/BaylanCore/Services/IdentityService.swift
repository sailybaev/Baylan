import Foundation
import Observation

@Observable
@MainActor
public final class IdentityService {
    public private(set) var localIdentity: Identity

    private let identityStore: IdentityStore

    public init(identityStore: IdentityStore) throws {
        self.identityStore = identityStore
        self.localIdentity = try identityStore.loadOrCreateIdentity()
    }

    /// Update the display name. Requires internet connectivity check to be done by the caller.
    public func updateDisplayName(_ name: String) {
        identityStore.updateDisplayName(name)
        localIdentity = Identity(
            userId: localIdentity.userId,
            displayName: name,
            publicKey: localIdentity.publicKey,
            isSelf: true,
            firstSeen: localIdentity.firstSeen,
            lastSeen: Date(),
            verified: true
        )
    }

    /// Returns the JSON payload for QR code generation.
    public func identityPayloadForQR() -> Data {
        let payload: [String: String] = [
            "v": "1",
            "id": localIdentity.userId,
            "pk": localIdentity.publicKey.base64EncodedString(),
            "name": localIdentity.displayName
        ]
        return (try? JSONSerialization.data(withJSONObject: payload, options: [])) ?? Data()
    }
}
