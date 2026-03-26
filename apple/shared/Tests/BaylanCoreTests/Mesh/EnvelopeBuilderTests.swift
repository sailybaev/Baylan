import Testing
import Foundation
@testable import BaylanCore

@Suite("EnvelopeBuilder")
struct EnvelopeBuilderTests {

    let crypto = CryptoEngine()

    @Test("Build direct envelope has correct fields")
    func buildDirectEnvelope() throws {
        let senderSigning = try crypto.generateSigningKeyPair()
        let senderAgreement = try crypto.generateAgreementKeyPair()
        let recipientAgreement = try crypto.generateAgreementKeyPair()
        let senderId = crypto.deriveUserId(from: senderSigning.publicKey)

        var payload = BaylanMessagePayload()
        payload.type = .text
        payload.body = "Hello"
        payload.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        payload.threadID = UUID().uuidString

        let envelope = try EnvelopeBuilder.buildDirect(
            payload: payload,
            senderId: senderId,
            recipientId: "recipient-id",
            recipientPublicKey: recipientAgreement.publicKey,
            senderAgreementPrivateKey: senderAgreement.privateKey,
            signingPrivateKey: senderSigning.privateKey,
            crypto: crypto
        )

        #expect(envelope.senderID == senderId)
        #expect(envelope.recipientID == "recipient-id")
        #expect(envelope.ttl == 7)
        #expect(envelope.hopCount == 0)
        #expect(envelope.conversationType == .direct)
        #expect(!envelope.messageID.isEmpty)
        #expect(!envelope.signature.isEmpty)
    }

    @Test("Build nearby envelope has correct fields and TTL 3")
    func buildNearbyEnvelope() throws {
        let signingPair = try crypto.generateSigningKeyPair()
        let senderId = crypto.deriveUserId(from: signingPair.publicKey)

        var payload = BaylanMessagePayload()
        payload.type = .text
        payload.body = "Hey nearby!"
        payload.timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        let envelope = try EnvelopeBuilder.buildNearby(
            payload: payload,
            senderId: senderId,
            signingPrivateKey: signingPair.privateKey,
            crypto: crypto
        )

        #expect(envelope.recipientID == "nearby")
        #expect(envelope.ttl == 3)
        #expect(envelope.conversationType == .nearby)
    }

    @Test("Signature verification passes for valid envelope")
    func signatureVerification() throws {
        let signingPair = try crypto.generateSigningKeyPair()
        let agreementPair = try crypto.generateAgreementKeyPair()
        let recipientAgreement = try crypto.generateAgreementKeyPair()
        let senderId = crypto.deriveUserId(from: signingPair.publicKey)

        var payload = BaylanMessagePayload()
        payload.type = .text
        payload.body = "Signed message"
        payload.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        payload.threadID = UUID().uuidString

        let envelope = try EnvelopeBuilder.buildDirect(
            payload: payload,
            senderId: senderId,
            recipientId: "bob",
            recipientPublicKey: recipientAgreement.publicKey,
            senderAgreementPrivateKey: agreementPair.privateKey,
            signingPrivateKey: signingPair.privateKey,
            crypto: crypto
        )

        let valid = try EnvelopeBuilder.verifySignature(of: envelope, senderPublicKey: signingPair.publicKey, crypto: crypto)
        #expect(valid == true)
    }
}
