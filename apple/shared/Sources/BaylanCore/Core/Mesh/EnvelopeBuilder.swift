import Foundation
import CryptoKit
import SwiftProtobuf

public enum EnvelopeBuilderError: Error, Sendable {
    case missingRecipientKey
    case encryptionFailed
    case serializationFailed
}

public struct EnvelopeBuilder: Sendable {

    private static let defaultTTL: UInt32 = 7
    private static let nearbyTTL: UInt32 = 3

    // MARK: - Build

    /// Builds a signed MeshEnvelope for direct (1-on-1) messaging.
    /// Payload is encrypted with NaCl-box equivalent.
    public static func buildDirect(
        payload: BaylanMessagePayload,
        senderId: String,
        recipientId: String,
        recipientPublicKey: Data,
        senderAgreementPrivateKey: Data,
        signingPrivateKey: Data,
        crypto: CryptoEngineProtocol
    ) throws -> BaylanMeshEnvelope {
        let payloadData = try payload.serializedData()
        let encrypted = try crypto.encrypt(payloadData, recipientPublicKey: recipientPublicKey, senderPrivateKey: senderAgreementPrivateKey)

        var envelope = BaylanMeshEnvelope()
        envelope.messageID = UUID().uuidString
        envelope.senderID = senderId
        envelope.recipientID = recipientId
        envelope.payload = encrypted
        envelope.ttl = defaultTTL
        envelope.hopCount = 0
        envelope.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
        envelope.conversationType = .direct
        envelope.signature = try signEnvelope(envelope, signingPrivateKey: signingPrivateKey, crypto: crypto)
        return envelope
    }

    /// Builds a signed MeshEnvelope for the Nearby public channel.
    /// Payload is plaintext (no encryption). TTL capped at 3 hops.
    public static func buildNearby(
        payload: BaylanMessagePayload,
        senderId: String,
        signingPrivateKey: Data,
        crypto: CryptoEngineProtocol
    ) throws -> BaylanMeshEnvelope {
        let payloadData = try payload.serializedData()

        var envelope = BaylanMeshEnvelope()
        envelope.messageID = UUID().uuidString
        envelope.senderID = senderId
        envelope.recipientID = "nearby"
        envelope.payload = payloadData
        envelope.ttl = nearbyTTL
        envelope.hopCount = 0
        envelope.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
        envelope.conversationType = .nearby
        envelope.signature = try signEnvelope(envelope, signingPrivateKey: signingPrivateKey, crypto: crypto)
        return envelope
    }

    /// Builds an ACK envelope sent back to the original sender.
    public static func buildAck(
        originalMessageId: String,
        senderId: String,
        recipientId: String,
        signingPrivateKey: Data,
        crypto: CryptoEngineProtocol
    ) throws -> BaylanMeshEnvelope {
        var ackPayload = BaylanDeliveryAck()
        ackPayload.messageID = originalMessageId
        ackPayload.senderID = senderId
        ackPayload.receivedAt = Int64(Date().timeIntervalSince1970 * 1000)

        var msgPayload = BaylanMessagePayload()
        msgPayload.type = .ack
        msgPayload.body = (try? ackPayload.serializedData().base64EncodedString()) ?? ""
        msgPayload.timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        var envelope = BaylanMeshEnvelope()
        envelope.messageID = UUID().uuidString
        envelope.senderID = senderId
        envelope.recipientID = recipientId
        envelope.payload = (try? msgPayload.serializedData()) ?? Data()
        envelope.ttl = 7
        envelope.hopCount = 0
        envelope.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
        envelope.conversationType = .direct
        envelope.signature = try signEnvelope(envelope, signingPrivateKey: signingPrivateKey, crypto: crypto)
        return envelope
    }

    // MARK: - Signing

    /// Returns the canonical byte representation of an envelope for signing/verification.
    /// Covers fields 1–7 (excludes signature itself).
    public static func signableData(from envelope: BaylanMeshEnvelope) -> Data {
        var data = Data()
        data.append(contentsOf: envelope.messageID.utf8)
        data.append(contentsOf: envelope.senderID.utf8)
        data.append(contentsOf: envelope.recipientID.utf8)
        data.append(envelope.payload)
        withUnsafeBytes(of: envelope.ttl.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: envelope.hopCount.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: envelope.createdAt.bigEndian) { data.append(contentsOf: $0) }
        return data
    }

    public static func verifySignature(of envelope: BaylanMeshEnvelope, senderPublicKey: Data, crypto: CryptoEngineProtocol) throws -> Bool {
        let data = signableData(from: envelope)
        return try crypto.verify(envelope.signature, for: data, publicKey: senderPublicKey)
    }

    // MARK: - Private

    private static func signEnvelope(_ envelope: BaylanMeshEnvelope, signingPrivateKey: Data, crypto: CryptoEngineProtocol) throws -> Data {
        let data = signableData(from: envelope)
        return try crypto.sign(data, with: signingPrivateKey)
    }
}
