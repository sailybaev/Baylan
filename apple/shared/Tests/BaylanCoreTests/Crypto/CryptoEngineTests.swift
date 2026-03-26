import Testing
import Foundation
@testable import BaylanCore

@Suite("CryptoEngine")
struct CryptoEngineTests {

    let crypto = CryptoEngine()

    @Test("Encrypt and decrypt round-trip")
    func encryptDecryptRoundTrip() throws {
        let senderPair = try crypto.generateAgreementKeyPair()
        let recipientPair = try crypto.generateAgreementKeyPair()
        let plaintext = Data("Hello, mesh!".utf8)

        let ciphertext = try crypto.encrypt(
            plaintext,
            recipientPublicKey: recipientPair.publicKey,
            senderPrivateKey: senderPair.privateKey
        )
        let decrypted = try crypto.decrypt(
            ciphertext,
            senderPublicKey: senderPair.publicKey,
            recipientPrivateKey: recipientPair.privateKey
        )
        #expect(decrypted == plaintext)
    }

    @Test("Decryption with wrong key fails")
    func decryptWithWrongKeyFails() throws {
        let senderPair = try crypto.generateAgreementKeyPair()
        let recipientPair = try crypto.generateAgreementKeyPair()
        let wrongPair = try crypto.generateAgreementKeyPair()
        let plaintext = Data("Secret".utf8)

        let ciphertext = try crypto.encrypt(
            plaintext,
            recipientPublicKey: recipientPair.publicKey,
            senderPrivateKey: senderPair.privateKey
        )

        #expect(throws: (any Error).self) {
            try crypto.decrypt(
                ciphertext,
                senderPublicKey: senderPair.publicKey,
                recipientPrivateKey: wrongPair.privateKey
            )
        }
    }

    @Test("Sign and verify")
    func signAndVerify() throws {
        let pair = try crypto.generateSigningKeyPair()
        let data = Data("Authenticate this".utf8)
        let signature = try crypto.sign(data, with: pair.privateKey)
        let valid = try crypto.verify(signature, for: data, publicKey: pair.publicKey)
        #expect(valid == true)
    }

    @Test("Verification fails with wrong public key")
    func verifyFailsWithWrongKey() throws {
        let pair = try crypto.generateSigningKeyPair()
        let wrongPair = try crypto.generateSigningKeyPair()
        let data = Data("test".utf8)
        let signature = try crypto.sign(data, with: pair.privateKey)
        let valid = try crypto.verify(signature, for: data, publicKey: wrongPair.publicKey)
        #expect(valid == false)
    }

    @Test("User ID is 32 hex characters")
    func userIdLength() throws {
        let pair = try crypto.generateSigningKeyPair()
        let userId = crypto.deriveUserId(from: pair.publicKey)
        #expect(userId.count == 32)
        #expect(userId.allSatisfy { $0.isHexDigit })
    }
}
