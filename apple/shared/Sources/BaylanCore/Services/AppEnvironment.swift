import Foundation
import SwiftData
import Observation

/// Central dependency container. Created once at app launch and injected via SwiftUI environment.
@Observable
@MainActor
public final class AppEnvironment {

    // MARK: - Services (public read access)

    public let identityService: IdentityService
    public let messageService: MessageService
    public let threadService: ThreadService
    public let peerService: PeerService
    public let meshRouter: MeshRouter
    public let repository: any MessageRepositoryProtocol

    // MARK: - Init (internal, use create())

    init(
        identityService: IdentityService,
        messageService: MessageService,
        threadService: ThreadService,
        peerService: PeerService,
        meshRouter: MeshRouter,
        repository: any MessageRepositoryProtocol
    ) {
        self.identityService = identityService
        self.messageService = messageService
        self.threadService = threadService
        self.peerService = peerService
        self.meshRouter = meshRouter
        self.repository = repository
    }

    // MARK: - Factory

    public static func create() throws -> AppEnvironment {
        let crypto = CryptoEngine()
        let identityStore = IdentityStore(crypto: crypto)
        let identityService = try IdentityService(identityStore: identityStore)

        let transport = MultipeerTransport(
            displayName: identityService.localIdentity.userId
        )
        let meshRouter = MeshRouter(
            transport: transport,
            localUserId: identityService.localIdentity.userId,
            crypto: crypto,
            signingPrivateKey: (try? identityStore.signingPrivateKey()) ?? Data()
        )

        let container = try SwiftDataMessageRepository.makeContainer(inMemory: false)
        let repository = SwiftDataMessageRepository(modelContainer: container)

        let messageService = MessageService(
            meshRouter: meshRouter,
            repository: repository,
            crypto: crypto,
            identityStore: identityStore
        )
        let threadService = ThreadService(repository: repository)
        let peerService = PeerService(
            meshRouter: meshRouter,
            identityService: identityService,
            repository: repository
        )

        return AppEnvironment(
            identityService: identityService,
            messageService: messageService,
            threadService: threadService,
            peerService: peerService,
            meshRouter: meshRouter,
            repository: repository
        )
    }

    // MARK: - Lifecycle

    /// Call from App.body .task modifier after environment is injected.
    public func start() async {
        await meshRouter.start()
        peerService.start()
        messageService.startReceiving()
        await threadService.loadThreads()
    }

    public func stop() async {
        messageService.stopReceiving()
        peerService.stop()
        await meshRouter.stop()
    }
}
