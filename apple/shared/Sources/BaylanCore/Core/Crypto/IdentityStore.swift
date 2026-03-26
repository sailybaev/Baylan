import Foundation
import Security
import CryptoKit

/// Persists the user's keypair in the Keychain, with a file-based fallback
/// for Mac Catalyst where Keychain entitlements may not be configured.
public final class IdentityStore: @unchecked Sendable {

    private let signingPrivateKeyTag = "com.baylan.signing.private"
    private let agreementPrivateKeyTag = "com.baylan.agreement.private"
    private let displayNameKey = "com.baylan.identity.displayName"

    private let crypto: CryptoEngineProtocol

    public init(crypto: CryptoEngineProtocol) {
        self.crypto = crypto
    }

    // MARK: - Public

    public func loadOrCreateIdentity() throws -> Identity {
        if let existing = try loadExistingIdentity() {
            return existing
        }
        return try createNewIdentity()
    }

    public func signingPrivateKey() throws -> Data {
        try loadKey(tag: signingPrivateKeyTag)
    }

    public func agreementPrivateKey() throws -> Data {
        try loadKey(tag: agreementPrivateKeyTag)
    }

    public func signingPublicKey() throws -> Data {
        let privData = try signingPrivateKey()
        let privKey = try CurveSigningKey(rawRepresentation: privData)
        return privKey.publicKey
    }

    public func agreementPublicKey() throws -> Data {
        let privData = try agreementPrivateKey()
        let privKey = try CurveAgreementKey(rawRepresentation: privData)
        return privKey.publicKey
    }

    public func updateDisplayName(_ name: String) {
        UserDefaults.standard.set(name, forKey: displayNameKey)
    }

    public func savedDisplayName() -> String? {
        UserDefaults.standard.string(forKey: displayNameKey)
    }

    // MARK: - Private: identity assembly

    private func loadExistingIdentity() throws -> Identity? {
        guard
            (try? loadKey(tag: signingPrivateKeyTag)) != nil,
            (try? loadKey(tag: agreementPrivateKeyTag)) != nil
        else { return nil }

        let signingPub = try signingPublicKey()
        let agreementPub = try agreementPublicKey()
        let userId = crypto.deriveUserId(from: signingPub)
        let displayName = UserDefaults.standard.string(forKey: displayNameKey) ?? "Anonymous"
        let publicKeyPayload = signingPub + agreementPub

        return Identity(
            userId: userId,
            displayName: displayName,
            publicKey: publicKeyPayload,
            isSelf: true,
            verified: true
        )
    }

    private func createNewIdentity() throws -> Identity {
        let signingPair = try crypto.generateSigningKeyPair()
        let agreementPair = try crypto.generateAgreementKeyPair()

        try saveKey(signingPair.privateKey, tag: signingPrivateKeyTag)
        try saveKey(agreementPair.privateKey, tag: agreementPrivateKeyTag)

        let userId = crypto.deriveUserId(from: signingPair.publicKey)
        let displayName = UserDefaults.standard.string(forKey: displayNameKey) ?? "Anonymous"
        let publicKeyPayload = signingPair.publicKey + agreementPair.publicKey

        return Identity(
            userId: userId,
            displayName: displayName,
            publicKey: publicKeyPayload,
            isSelf: true,
            verified: true
        )
    }

    // MARK: - Storage: Keychain with file fallback

    private func saveKey(_ keyData: Data, tag: String) throws {
        if keychainSave(keyData, tag: tag) { return }
        try fileSave(keyData, tag: tag)
    }

    private func loadKey(tag: String) throws -> Data {
        if let data = keychainLoad(tag: tag) { return data }
        return try fileLoad(tag: tag)
    }

    // MARK: - Keychain

    @discardableResult
    private func keychainSave(_ keyData: Data, tag: String) -> Bool {
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tag,
            kSecAttrService: "com.baylan",
            kSecUseDataProtectionKeychain: true
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tag,
            kSecAttrService: "com.baylan",
            kSecValueData: keyData,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecUseDataProtectionKeychain: true
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func keychainLoad(tag: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tag,
            kSecAttrService: "com.baylan",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - File fallback (Mac Catalyst / sandboxed environments)

    private func keyFileURL(tag: String) throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("com.baylan/keys", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = tag.replacingOccurrences(of: ".", with: "_")
        return dir.appendingPathComponent(filename)
    }

    private func fileSave(_ keyData: Data, tag: String) throws {
        let url = try keyFileURL(tag: tag)
        try keyData.write(to: url, options: .atomic)
        // Restrict permissions to owner read/write only
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func fileLoad(tag: String) throws -> Data {
        let url = try keyFileURL(tag: tag)
        return try Data(contentsOf: url)
    }
}

// MARK: - Helpers

private struct CurveSigningKey {
    let publicKey: Data
    init(rawRepresentation: Data) throws {
        let privKey = try Curve25519.Signing.PrivateKey(rawRepresentation: rawRepresentation)
        self.publicKey = privKey.publicKey.rawRepresentation
    }
}

private struct CurveAgreementKey {
    let publicKey: Data
    init(rawRepresentation: Data) throws {
        let privKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: rawRepresentation)
        self.publicKey = privKey.publicKey.rawRepresentation
    }
}

// MARK: - Error

public enum IdentityStoreError: Error, Sendable {
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed(OSStatus)
    case identityNotFound
}
