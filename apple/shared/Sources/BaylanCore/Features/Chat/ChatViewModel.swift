import Foundation
import Observation

@Observable
@MainActor
public final class ChatViewModel {

    public private(set) var messages: [Message] = []
    public private(set) var thread: MessageThread?
    public private(set) var participantNames: [String: String] = [:]
    public var isLoading = false

    public let threadId: UUID
    private let messageService: MessageService
    private let threadService: ThreadService
    private let repository: any MessageRepositoryProtocol

    public init(
        threadId: UUID,
        messageService: MessageService,
        threadService: ThreadService,
        repository: any MessageRepositoryProtocol
    ) {
        self.threadId = threadId
        self.messageService = messageService
        self.threadService = threadService
        self.repository = repository
    }

    public var isNearbyChannel: Bool {
        threadId == MessageThread.nearbyThreadId
    }

    public func loadMessages() async {
        if messages.isEmpty {
            isLoading = true
        }
        defer { isLoading = false }
        messages = (try? await repository.messages(forThread: threadId)) ?? []
        
        var loadedThread = try? await repository.thread(forId: threadId)
        if let t = loadedThread, !t.isNearbyChannel {
             if let identity = try? await repository.identity(for: t.peerId) {
                 loadedThread?.peerName = identity.displayName
                 threadService.updateCache(peerId: t.peerId, name: identity.displayName)
             }
        }
        thread = loadedThread
        
        // Load names for all participants in the thread
        var names: [String: String] = [:]
        let uniquePeers = Set(messages.map(\.senderId))
        for peer in uniquePeers {
            if let identity = try? await repository.identity(for: peer) {
                names[peer] = identity.displayName
                threadService.updateCache(peerId: peer, name: identity.displayName)
            }
        }
        participantNames = names
        
        await threadService.markAsRead(threadId)
    }

    public func sendMessage(_ body: String) async {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            if isNearbyChannel {
                try await messageService.sendNearbyMessage(body: body)
            } else if let thread, let peerIdentity = try? await repository.identity(for: thread.peerId) {
                try await messageService.sendDirectMessage(
                    body: body,
                    to: peerIdentity.userId,
                    threadId: threadId,
                    recipientPublicKey: peerIdentity.publicKey
                )
            }
        } catch {
            // Error handling: UI shows failed state via message state
        }
        await loadMessages()
    }
}
