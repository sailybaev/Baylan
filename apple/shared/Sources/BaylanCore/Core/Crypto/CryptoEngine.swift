import Foundation
import CryptoKit

public final class CryptoEngine: CryptoEngineProtocol, @unchecked Sendable {

    public init() {}

    // MARK: - Key Generation

    public func generateSigningKeyPair() throws -> KeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        return KeyPair(
            privateKey: privateKey.rawRepresentation,
            publicKey: privateKey.publicKey.rawRepresentation
        )
    }

    public func generateAgreementKeyPair() throws -> KeyPair {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        return KeyPair(
            privateKey: privateKey.rawRepresentation,
            publicKey: privateKey.publicKey.rawRepresentation
        )
    }

    // MARK: - Signing

    public func sign(_ data: Data, with privateKeyData: Data) throws -> Data {
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
        return try privateKey.signature(for: data)
    }

    public func verify(_ signature: Data, for data: Data, publicKey publicKeyData: Data) throws -> Bool {
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        return publicKey.isValidSignature(signature, for: data)
    }

    // MARK: - Encryption (NaCl box equivalent)
    // ECDH (X25519) key agreement → HKDF-SHA256 key derivation → ChaChaPoly AEAD

    public func encrypt(_ plaintext: Data, recipientPublicKey recipientPubData: Data, senderPrivateKey senderPrivData: Data) throws -> Data {
        let senderPrivKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: senderPrivData)
        let recipientPubKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientPubData)
        let sharedSecret = try senderPrivKey.sharedSecretFromKeyAgreement(with: recipientPubKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("baylan-message-v1".utf8),
            outputByteCount: 32
        )
        let sealedBox = try ChaChaPoly.seal(plaintext, using: symmetricKey)
        return sealedBox.combined
    }

    public func decrypt(_ ciphertext: Data, senderPublicKey senderPubData: Data, recipientPrivateKey recipientPrivData: Data) throws -> Data {
        let recipientPrivKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: recipientPrivData)
        let senderPubKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: senderPubData)
        let sharedSecret = try recipientPrivKey.sharedSecretFromKeyAgreement(with: senderPubKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("baylan-message-v1".utf8),
            outputByteCount: 32
        )
        let sealedBox = try ChaChaPoly.SealedBox(combined: ciphertext)
        return try ChaChaPoly.open(sealedBox, using: symmetricKey)
    }

    // MARK: - User ID Derivation

    /// user_id = SHA256(signingPublicKey).prefix(16) as lowercase hex (32 chars)
    public func deriveUserId(from signingPublicKey: Data) -> String {
        let hash = SHA256.hash(data: signingPublicKey)
        return hash.prefix(16).map { String(format: "%02hhx", $0) }.joined()
    }
}
