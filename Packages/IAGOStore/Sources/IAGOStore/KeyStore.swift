import CryptoKit
import Foundation
import Security

/// Holds the master key (spec 9.2, ADR-0028).
public protocol MasterKeyStore: Sendable {
    /// Returns the master key, creating it on first use.
    func masterKey() throws -> SymmetricKey
}

public enum KeyStoreError: Error, Sendable, CustomStringConvertible {
    case keychain(OSStatus)
    case corruptKey

    public var description: String {
        switch self {
        case .keychain(let status):
            "Keychain error \(status): \(SecCopyErrorMessageString(status, nil) as String? ?? "")"
        case .corruptKey: "Master key has an invalid length"
        }
    }
}

/// Master key in the login keychain, readable by IAGO's code signature without prompts. Created
/// on the first launch; never leaves the Mac (not synchronizable).
public struct KeychainMasterKeyStore: MasterKeyStore {
    public let service: String
    public let account: String

    public init(service: String = "com.giovannilombi.iago", account: String = "master-key") {
        self.service = service
        self.account = account
    }

    public func masterKey() throws -> SymmetricKey {
        if let existing = try read() { return existing }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: "IAGO master key",
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem, let existing = try read() { return existing }
        guard status == errSecSuccess else { throw KeyStoreError.keychain(status) }
        return key
    }

    /// Restore from a backup (ADR-0041): the key of the backup becomes the master key. The current one is kept
    /// under `previousAccount`, so the archive moved aside stays readable until the user deletes it.
    public func replace(with key: SymmetricKey, keepingCurrentAs previousAccount: String) throws {
        if let current = try read() {
            let keep = KeychainMasterKeyStore(service: service, account: previousAccount)
            try keep.write(current)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw KeyStoreError.keychain(status) }
        }
        try write(key)
    }

    /// The key if it exists; never creates one (the MCP server's own copy, ADR-0043).
    public func existingKey() throws -> SymmetricKey? { try read() }

    /// Stores `key` under this account, replacing what was there. The MCP server keeps its own copy of the master
    /// key this way: an item it creates itself is readable by it without a keychain prompt (ADR-0043, user's
    /// choice 2026-10-15).
    public func store(_ key: SymmetricKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeyStoreError.keychain(status) }
        try write(key)
    }

    /// Deletes this account's key. Only for the keys kept by a restore, when the user deletes the replaced
    /// archive they opened; never called on the live master key.
    public func remove() throws {
        precondition(account != "master-key", "The live master key is never deleted")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeyStoreError.keychain(status) }
    }

    private func write(_ key: SymmetricKey) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: account == "master-key" ? "IAGO master key" : "IAGO master key (\(account))",
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: key.withUnsafeBytes { Data($0) },
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyStoreError.keychain(status) }
    }

    private func read() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeyStoreError.keychain(status) }
        guard data.count == 32 else { throw KeyStoreError.corruptKey }
        return SymmetricKey(data: data)
    }
}

/// In-memory master key, for tests.
public struct EphemeralMasterKeyStore: MasterKeyStore {
    private let key: SymmetricKey

    public init(key: SymmetricKey = SymmetricKey(size: .bits256)) {
        self.key = key
    }

    public func masterKey() throws -> SymmetricKey { key }
}

/// Per-item keys (spec 9.2): random AES-256 keys stored in `item_key`, sealed with the master key and
/// bound to the item ID. Deleting the row makes the item's files unreadable (crypto-shredding, 9.3).
struct ItemKeyring: Sendable {
    let master: SymmetricKey

    func newWrappedKey(for itemID: String) throws -> (key: SymmetricKey, wrapped: Data) {
        let key = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal(
            key.withUnsafeBytes { Data($0) }, using: master, authenticating: Data(itemID.utf8))
        return (key, sealed.combined!)
    }

    func unwrap(_ wrapped: Data, for itemID: String) throws -> SymmetricKey {
        let box = try AES.GCM.SealedBox(combined: wrapped)
        return SymmetricKey(data: try AES.GCM.open(box, using: master, authenticating: Data(itemID.utf8)))
    }
}
