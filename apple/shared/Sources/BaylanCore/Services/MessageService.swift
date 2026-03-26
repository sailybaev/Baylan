import Foundation
import Observation

@Observable
@MainActor
public final class MessageService {

    // MARK: - Dependencies

    private let meshRouter: MeshRouter
    private let repository: any MessageRepositoryProtocol
    private let crypto: any CryptoEngineProtocol
    private let identityStore: IdentityStore

    // MARK: - Observable state

    /// Bumped on the main actor whenever an inbound message is received.
    /// Observers (e.g. ChatView) can watch this to trigger a reload.
    public var lastIncomingMessageAt: Date? = nil

    // MARK: - Task

    nonisolated(unsafe) private var receiveTask: Task<Void, Never>?
    private var lastIncomingMessageTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        meshRouter: MeshRouter,
        repository: any MessageRepositoryProtocol,
        crypto: any CryptoEngineProtocol,
        identityStore: IdentityStore
    ) {
        self.meshRouter = meshRouter
        self.repository = repository
        self.crypto = crypto
        self.identityStore = identityStore
    }

    deinit {
        receiveTask?.cancel()
    }

    // MARK: - Lifecycle

    public func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            let stream = meshRouter.subscribe()
            for await event in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.handle(meshEvent: event)
                }
            }
        }
    }

    public func stopReceiving() {
        receiveTask?.cancel()
    }

    // MARK: - Sending

    /// Send a 1-on-1 encrypted message to a peer.
    public func sendDirectMessage(
        body: String,
        to recipientId: String,
        threadId: UUID,
        recipientPublicKey: Data
    ) async throws {
        let signingKey = try identityStore.signingPrivateKey()
        let agreementKey = try identityStore.agreementPrivateKey()
        let signingPub = try identityStore.signingPublicKey()
        let localUserId = crypto.deriveUserId(from: signingPub)

        var payload = BaylanMessagePayload()
        payload.type = .text
        payload.body = body
        payload.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        payload.threadID = threadId.uuidString

        // Recipient's agreement key is bytes 32..<64 of their publicKey payload
        let recipientAgreementKey = recipientPublicKey.count >= 64
            ? recipientPublicKey[32..<64]
            : recipientPublicKey

        let envelope = try EnvelopeBuilder.buildDirect(
            payload: payload,
            senderId: localUserId,
            recipientId: recipientId,
            recipientPublicKey: Data(recipientAgreementKey),
            senderAgreementPrivateKey: agreementKey,
            signingPrivateKey: signingKey,
            crypto: crypto
        )

        // Persist as sending
        let message = Message(
            messageId: UUID(uuidString: envelope.messageID) ?? UUID(),
            threadId: threadId,
            senderId: localUserId,
            recipientId: recipientId,
            body: body,
            type: .text,
            state: .sending
        )
        try await repository.saveMessage(message)

        // Send into mesh
        do {
            try await meshRouter.send(envelope)
            // Update to relayed once sent
            try await repository.updateMessageState(message.messageId, state: .relayed)
            self.bumpLastIncomingMessage()
        } catch {
            try await repository.updateMessageState(message.messageId, state: .failed)
            self.bumpLastIncomingMessage()
            throw error
        }
    }

    /// Send a message to the Nearby public mesh channel.
    public func sendNearbyMessage(body: String) async throws {
        let signingKey = try identityStore.signingPrivateKey()
        let signingPub = try identityStore.signingPublicKey()
        let localUserId = crypto.deriveUserId(from: signingPub)

        var payload = BaylanMessagePayload()
        payload.type = .text
        payload.body = body
        payload.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        payload.threadID = MessageThread.nearbyThreadId.uuidString

        let envelope = try EnvelopeBuilder.buildNearby(
            payload: payload,
            senderId: localUserId,
            signingPrivateKey: signingKey,
            crypto: crypto
        )

        let message = Message(
            messageId: UUID(uuidString: envelope.messageID) ?? UUID(),
            threadId: MessageThread.nearbyThreadId,
            senderId: localUserId,
            recipientId: "nearby",
            body: body,
            type: .text,
            state: .relayed
        )
        try await repository.saveMessage(message)
        try await meshRouter.send(envelope)
    }

    // MARK: - Receiving

    private func handle(meshEvent event: MeshEvent) {
        switch event {
        case .messageReceived(var message):
            // Decrypt if direct
            Task { [weak self] in
                guard let self else { return }
                if message.recipientId != "nearby" {
                    message = await decryptIfNeeded(message)
                }
                try? await repository.saveMessage(message)
                
                let isNearby = message.recipientId == "nearby"
                let peerForThread = isNearby ? "nearby" : message.senderId
                
                if let thread = try? await repository.thread(forPeer: peerForThread) {
                    try? await repository.updateUnreadCount(thread.threadId, count: thread.unreadCount + 1)
                } else if !isNearby {
                    let newThread = MessageThread(
                        threadId: message.threadId,
                        peerId: message.senderId,
                        conversationType: .direct,
                        unreadCount: 1
                    )
                    try? await repository.saveThread(newThread)
                }
                self.bumpLastIncomingMessage()
            }

        case .ackReceived(let messageId, _):
            Task { [weak self] in
                guard let self else { return }
                if let uuid = UUID(uuidString: messageId) {
                    try? await repository.updateMessageState(uuid, state: .delivered)
                }
                self.bumpLastIncomingMessage()
            }

        case .presenceReceived:
            break

        case .connectionStateChanged:
            break

        @unknown default:
            break
        }
    }

    private func bumpLastIncomingMessage() {
        lastIncomingMessageTask?.cancel()
        lastIncomingMessageTask = Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms trailing debounce
            guard !Task.isCancelled else { return }
            self.lastIncomingMessageAt = Date()
        }
    }

    /// Attempts to decrypt a direct message payload using our agreement private key.
    /// Falls back to the original message if decryption fails (e.g., not the intended recipient).
    private func decryptIfNeeded(_ message: Message) async -> Message {
        guard message.body == nil else { return message }
        guard let payload = message.payload else { return message }
        
        guard let agreementKey = try? identityStore.agreementPrivateKey() else { return message }
        guard let senderIdentity = try? await repository.identity(for: message.senderId) else { return message }
        
        // Sender's agreement key is bytes 32..<64 of their publicKey payload
        let senderAgreementKey = senderIdentity.publicKey.count >= 64
            ? senderIdentity.publicKey[32..<64]
            : senderIdentity.publicKey

        guard let decrypted = try? crypto.decrypt(
            payload,
            senderPublicKey: Data(senderAgreementKey),
            recipientPrivateKey: agreementKey
        ) else { return message }

        guard let parsed = try? BaylanMessagePayload(serializedBytes: decrypted) else { return message }
        
        var decryptedMessage = message
        decryptedMessage.body = parsed.body.isEmpty ? nil : parsed.body
        if let tid = UUID(uuidString: parsed.threadID) {
            decryptedMessage.threadId = tid
        }
        return decryptedMessage
    }
}
