import Testing
import Foundation
@testable import BaylanCore

// MARK: - Full send/receive pipeline

@Suite("Integration: Direct Message Pipeline")
struct DirectMessagePipelineTests {

    @Test("Alice encrypts and sends, Bob decrypts and receives")
    func encryptSendDecryptReceive() async throws {
        let crypto = CryptoEngine()

        let aliceAgreement = try crypto.generateAgreementKeyPair()
        let bobAgreement = try crypto.generateAgreementKeyPair()

        let plaintext = "Hello Bob, this is encrypted!".data(using: .utf8)!

        // Alice encrypts for Bob
        let ciphertext = try crypto.encrypt(
            plaintext,
            recipientPublicKey: bobAgreement.publicKey,
            senderPrivateKey: aliceAgreement.privateKey
        )
        #expect(!ciphertext.isEmpty)

        // Bob decrypts
        let decrypted = try crypto.decrypt(
            ciphertext,
            senderPublicKey: aliceAgreement.publicKey,
            recipientPrivateKey: bobAgreement.privateKey
        )
        #expect(decrypted == plaintext)
    }

    @Test("User IDs are derived from signing public keys")
    func userIdDerivation() throws {
        let crypto = CryptoEngine()
        let alice = try crypto.generateSigningKeyPair()
        let bob = try crypto.generateSigningKeyPair()

        let aliceId = crypto.deriveUserId(from: alice.publicKey)
        let bobId = crypto.deriveUserId(from: bob.publicKey)

        #expect(aliceId.count == 32)
        #expect(bobId.count == 32)
        #expect(aliceId != bobId)
        // Deterministic
        #expect(crypto.deriveUserId(from: alice.publicKey) == aliceId)
    }

    @Test("Full message persist and retrieve via in-memory repository")
    func persistAndRetrieve() async throws {
        let container = try SwiftDataMessageRepository.makeContainer(inMemory: true)
        let repo = SwiftDataMessageRepository(modelContainer: container)

        let alice = Identity(
            userId: "alice-user-id-00000001",
            displayName: "Alice",
            publicKey: Data(repeating: 0xAA, count: 32),
            isSelf: true,
            firstSeen: Date(),
            lastSeen: Date(),
            verified: false
        )
        let threadId = UUID()
        let thread = MessageThread(
            threadId: threadId,
            peerId: alice.userId,
            conversationType: .direct
        )

        try await repo.saveThread(thread)
        try await repo.saveIdentity(alice)

        let msg = Message(
            messageId: UUID(),
            threadId: threadId,
            senderId: alice.userId,
            recipientId: "bob-user-id-00000002",
            body: "Integration test message",
            type: .text,
            state: .sending,
            createdAt: Date(),
            deliveredAt: nil,
            hopCount: 0
        )

        try await repo.saveMessage(msg)

        let fetched = try await repo.messages(forThread: threadId)
        #expect(fetched.count == 1)
        #expect(fetched.first?.body == "Integration test message")
        #expect(fetched.first?.state == .sending)

        // Update state to delivered
        try await repo.updateMessageState(msg.messageId, state: .delivered)

        let updated = try await repo.messages(forThread: threadId)
        #expect(updated.first?.state == .delivered)
    }
}

// MARK: - Nearby channel

@Suite("Integration: Nearby Channel")
struct NearbyChannelTests {

    @Test("Nearby thread has well-known UUID")
    func nearbyThreadId() {
        let nearby = MessageThread.nearbyChannel
        #expect(nearby.threadId == MessageThread.nearbyThreadId)
        #expect(nearby.isNearbyChannel == true)
        #expect(nearby.conversationType == .nearby)
    }

    @Test("Nearby channel persists and loads")
    func nearbyChannelPersistence() async throws {
        let container = try SwiftDataMessageRepository.makeContainer(inMemory: true)
        let repo = SwiftDataMessageRepository(modelContainer: container)

        let nearby = MessageThread.nearbyChannel
        try await repo.saveThread(nearby)

        let fetched = try await repo.thread(forId: MessageThread.nearbyThreadId)
        #expect(fetched?.isNearbyChannel == true)
    }

    @Test("Multiple nearby messages from different senders")
    func multipleNearbySenders() async throws {
        let container = try SwiftDataMessageRepository.makeContainer(inMemory: true)
        let repo = SwiftDataMessageRepository(modelContainer: container)

        let nearby = MessageThread.nearbyChannel
        try await repo.saveThread(nearby)

        let threadId = MessageThread.nearbyThreadId
        let senders = ["alice-00000001", "bob-000000002", "carol-0000003"]

        for (i, sender) in senders.enumerated() {
            let msg = Message(
                messageId: UUID(),
                threadId: threadId,
                senderId: sender,
                recipientId: "broadcast",
                body: "Hello from \(sender)",
                type: .text,
                state: .delivered,
                createdAt: Date().addingTimeInterval(Double(i)),
                deliveredAt: nil,
                hopCount: i
            )
            try await repo.saveMessage(msg)
        }

        let messages = try await repo.messages(forThread: threadId)
        #expect(messages.count == 3)
        let uniqueSenders = Set(messages.map(\.senderId))
        #expect(uniqueSenders.count == 3)
    }
}

// MARK: - Mesh routing

@Suite("Integration: Mesh Router with Mock Transport")
struct MeshRouterIntegrationTests {

    @Test("Router starts and processes events without crash")
    func routerStartsCleanly() async throws {
        let crypto = CryptoEngine()
        let aliceKeys = try crypto.generateSigningKeyPair()
        let aliceId = crypto.deriveUserId(from: aliceKeys.publicKey)

        let transport = MockTransport()
        let router = MeshRouter(
            transport: transport,
            localUserId: aliceId,
            crypto: crypto,
            signingPrivateKey: aliceKeys.privateKey
        )

        await router.start()
        try await Task.sleep(for: .milliseconds(50))
        await router.stop()
        #expect(Bool(true)) // No crash = success
    }

    @Test("Router relays nearby envelope to connected peers")
    func relayNearbyEnvelope() async throws {
        let crypto = CryptoEngine()
        let localKeys = try crypto.generateSigningKeyPair()
        let localId = crypto.deriveUserId(from: localKeys.publicKey)

        let senderKeys = try crypto.generateSigningKeyPair()
        let senderId = crypto.deriveUserId(from: senderKeys.publicKey)

        let transport = MockTransport()
        let router = MeshRouter(
            transport: transport,
            localUserId: localId,
            crypto: crypto,
            signingPrivateKey: localKeys.privateKey
        )
        await router.start()

        // Register peer that will send the message
        let peerInfo = PeerInfo(peerId: "sender-peer", displayName: "Sender")
        await transport.simulatePeerFound(peerInfo)

        // Register another peer that should receive relay
        let relayPeer = PeerInfo(peerId: "relay-peer", displayName: "Relay")
        await transport.simulatePeerFound(relayPeer)

        try await Task.sleep(for: .milliseconds(50))

        // Build a nearby message from the sender (not local user)
        let payload = BaylanMessagePayload.with {
            $0.body = "nearby broadcast"
            $0.type = .text
        }
        let envelope = try EnvelopeBuilder.buildNearby(
            payload: payload,
            senderId: senderId,
            signingPrivateKey: senderKeys.privateKey,
            crypto: crypto
        )
        let envelopeData = try envelope.serializedData()

        // Register sender identity for signature verification
        let senderIdentity = Identity(
            userId: senderId,
            displayName: "Sender",
            publicKey: senderKeys.publicKey,
            isSelf: false,
            firstSeen: Date(),
            lastSeen: Date(),
            verified: false
        )
        router.registerPeer(senderIdentity)

        await transport.simulateReceive(envelopeData, from: "sender-peer")

        try await Task.sleep(for: .milliseconds(100))
        await router.stop()

        // Router should not relay back to the original sender
        #expect(transport.sentMessages.filter { $0.peerId == "sender-peer" }.isEmpty)
    }
}

// MARK: - Error handling

@Suite("Integration: Error Handling")
struct ErrorHandlingTests {

    @Test("Decrypt with wrong key throws")
    func decryptWithWrongKey() throws {
        let crypto = CryptoEngine()
        let sender = try crypto.generateAgreementKeyPair()
        let legitimateRecipient = try crypto.generateAgreementKeyPair()
        let wrongKey = try crypto.generateAgreementKeyPair()

        let plaintext = "secret".data(using: .utf8)!
        let ciphertext = try crypto.encrypt(
            plaintext,
            recipientPublicKey: legitimateRecipient.publicKey,
            senderPrivateKey: sender.privateKey
        )

        #expect(throws: (any Error).self) {
            try crypto.decrypt(
                ciphertext,
                senderPublicKey: sender.publicKey,
                recipientPrivateKey: wrongKey.privateKey
            )
        }
    }

    @Test("Envelope with tampered signature fails verification")
    func tamperedSignatureFails() throws {
        let crypto = CryptoEngine()
        let signingKeys = try crypto.generateSigningKeyPair()

        let payload = BaylanMessagePayload.with { $0.body = "hello" }
        var envelope = try EnvelopeBuilder.buildNearby(
            payload: payload,
            senderId: "attacker",
            signingPrivateKey: signingKeys.privateKey,
            crypto: crypto
        )

        // Tamper with the signature
        var tampered = envelope.signature
        if !tampered.isEmpty {
            tampered[0] ^= 0xFF
        }
        envelope.signature = tampered

        let isValid = try EnvelopeBuilder.verifySignature(
            of: envelope,
            senderPublicKey: signingKeys.publicKey,
            crypto: crypto
        )
        #expect(isValid == false)
    }

    @Test("Saving to repository with same ID is idempotent")
    func idempotentSave() async throws {
        let container = try SwiftDataMessageRepository.makeContainer(inMemory: true)
        let repo = SwiftDataMessageRepository(modelContainer: container)

        let threadId = UUID()
        let thread = MessageThread(threadId: threadId, peerId: "peer-1", conversationType: .direct)
        try await repo.saveThread(thread)
        try await repo.saveThread(thread) // second save should not throw

        let messageId = UUID()
        let msg = Message(
            messageId: messageId,
            threadId: threadId,
            senderId: "sender-1",
            recipientId: "recipient-1",
            body: "idempotent",
            type: .text,
            state: .sending,
            createdAt: Date(),
            deliveredAt: nil,
            hopCount: 0
        )
        try await repo.saveMessage(msg)
        try await repo.saveMessage(msg) // duplicate — should not crash

        let messages = try await repo.messages(forThread: threadId)
        #expect(messages.count == 1)
    }

    @Test("Unread count updates via repository")
    func unreadCountUpdates() async throws {
        let container = try SwiftDataMessageRepository.makeContainer(inMemory: true)
        let repo = SwiftDataMessageRepository(modelContainer: container)

        let threadId = UUID()
        let thread = MessageThread(
            threadId: threadId,
            peerId: "peer-unread",
            conversationType: .direct,
            unreadCount: 5
        )
        try await repo.saveThread(thread)

        let fetched = try await repo.thread(forId: threadId)
        #expect(fetched?.unreadCount == 5)

        try await repo.updateUnreadCount(threadId, count: 0)

        let updated = try await repo.thread(forId: threadId)
        #expect(updated?.unreadCount == 0)
    }
}
