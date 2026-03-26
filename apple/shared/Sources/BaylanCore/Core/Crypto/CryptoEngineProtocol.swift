import Foundation

public struct KeyPair: Sendable {
    public let privateKey: Data
    public let publicKey: Data

    public init(privateKey: Data, publicKey: Data) {
        self.privateKey = privateKey
        self.publicKey = publicKey
    }
}

public protocol CryptoEngineProtocol: Sendable {
    func generateSigningKeyPair() throws -> KeyPair
    func generateAgreementKeyPair() throws -> KeyPair
    func sign(_ data: Data, with privateKey: Data) throws -> Data
    func verify(_ signature: Data, for data: Data, publicKey: Data) throws -> Bool
    func encrypt(_ plaintext: Data, recipientPublicKey: Data, senderPrivateKey: Data) throws -> Data
    func decrypt(_ ciphertext: Data, senderPublicKey: Data, recipientPrivateKey: Data) throws -> Data
    func deriveUserId(from signingPublicKey: Data) -> String
}
