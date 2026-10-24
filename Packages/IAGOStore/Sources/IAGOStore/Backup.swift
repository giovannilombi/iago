import AppleArchive
import CommonCrypto
import CryptoKit
import Foundation
import GRDB
import System

/// Encrypted backup of the whole archive (spec 9.3, ADR-0041): one Apple Encrypted Archive (scrypt, AES-CTR,
/// HMAC) protected by a password, with a consistent copy of the database, the encrypted item files and the
/// master key. Restoring it on another Mac gives back the same archive.
public enum Backup {
    public struct Manifest: Codable, Sendable, Equatable {
        public var format = 1
        public var createdAt: Date
        public var deviceID: String
        public var items: Int
    }

    public enum BackupError: Error, Sendable, Equatable, CustomStringConvertible {
        case passwordTooShort
        case wrongPasswordOrDamaged
        case notABackup
        case archive(String)

        public var description: String {
            switch self {
            case .passwordTooShort: "La password deve avere almeno \(Backup.minimumPasswordLength) caratteri"
            case .wrongPasswordOrDamaged: "Password errata o file di backup danneggiato"
            case .notABackup: "Il file non è un backup di IAGO"
            case .archive(let detail): "Errore nell'archivio di backup: \(detail)"
            }
        }
    }

    public static let minimumPasswordLength = 10
    public static let fileExtension = "iagobackup"
    static let manifestName = "manifest.json"
    static let keyName = "master.key"
    static let databaseName = "iago.sqlite"
    static let itemsName = "Items"

    // MARK: Create

    /// Writes the backup to `destination`. `staging` is a scratch folder on the same volume (files are cloned,
    /// not copied, on APFS) and is emptied afterwards.
    public static func create(
        archive: Archive, masterKey: SymmetricKey, password: String, to destination: URL, staging: URL
    ) throws -> Manifest {
        guard password.count >= minimumPasswordLength else { throw BackupError.passwordTooShort }
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        // A consistent snapshot of the database, even while the app writes.
        let snapshot = try DatabaseQueue(path: staging.appendingPathComponent(databaseName).path)
        try archive.database.writer.backup(to: snapshot)
        try snapshot.close()
        if fileManager.fileExists(atPath: archive.itemsRoot.path) {
            try fileManager.copyItem(at: archive.itemsRoot, to: staging.appendingPathComponent(itemsName))
        } else {
            try fileManager.createDirectory(
                at: staging.appendingPathComponent(itemsName), withIntermediateDirectories: true)
        }
        try masterKey.withUnsafeBytes { Data($0) }.write(to: staging.appendingPathComponent(keyName))
        let manifest = Manifest(
            // Whole seconds: the manifest stores ISO 8601 dates.
            createdAt: Date(timeIntervalSince1970: archive.now().timeIntervalSince1970.rounded(.down)),
            deviceID: archive.deviceID, items: try archive.items().count)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: staging.appendingPathComponent(manifestName))

        try? fileManager.removeItem(at: destination)
        guard
            let file = ArchiveByteStream.fileStream(
                path: FilePath(destination.path), mode: .writeOnly, options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o600))
        else { throw BackupError.archive("cannot create \(destination.lastPathComponent)") }
        defer { try? file.close() }
        let context = try encryptionContext(password)
        guard let encrypted = ArchiveByteStream.encryptionStream(writingTo: file, encryptionContext: context),
            let encoderStream = ArchiveStream.encodeStream(writingTo: encrypted),
            let keys = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,MOD,FLG,MTM,BTM,CTM")
        else { throw BackupError.archive("cannot open the encryption stream") }
        do {
            try encoderStream.writeDirectoryContents(archiveFrom: FilePath(staging.path), keySet: keys)
            try encoderStream.close()
            try encrypted.close()
        } catch {
            try? fileManager.removeItem(at: destination)
            throw BackupError.archive("\(error)")
        }
        return manifest
    }

    // MARK: Restore

    /// Decrypts and unpacks a backup into `folder` (emptied first) and checks it: manifest, master key and a
    /// database that opens with the current migrations.
    public static func extract(_ backup: URL, password: String, to folder: URL) throws -> Manifest {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: folder)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        guard
            let file = ArchiveByteStream.fileStream(
                path: FilePath(backup.path), mode: .readOnly, options: [], permissions: FilePermissions(rawValue: 0o600)
            )
        else { throw BackupError.notABackup }
        defer { try? file.close() }
        guard let context = ArchiveEncryptionContext(from: file) else { throw BackupError.notABackup }
        do {
            try context.setPassword(try stretched(password))
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.wrongPasswordOrDamaged
        }
        guard let decrypted = ArchiveByteStream.decryptionStream(readingFrom: file, encryptionContext: context),
            let decoder = ArchiveStream.decodeStream(readingFrom: decrypted),
            let extractor = ArchiveStream.extractStream(
                extractingTo: FilePath(folder.path), flags: [.ignoreOperationNotPermitted])
        else { throw BackupError.wrongPasswordOrDamaged }
        do {
            _ = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor)
            try extractor.close()
            try decoder.close()
            try decrypted.close()
        } catch {
            try? fileManager.removeItem(at: folder)
            throw BackupError.wrongPasswordOrDamaged
        }
        return try validate(folder)
    }

    /// Checks an unpacked backup and returns its manifest.
    @discardableResult
    public static func validate(_ folder: URL) throws -> Manifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(manifestName)),
            let manifest = try? decoder.decode(Manifest.self, from: data),
            (try? Data(contentsOf: folder.appendingPathComponent(keyName)))?.count == 32
        else { throw BackupError.notABackup }
        let database = try AppDatabase.open(at: folder.appendingPathComponent(databaseName))
        try database.writer.read { db in _ = try Item.fetchCount(db) }
        return manifest
    }

    /// The master key inside an unpacked backup.
    public static func masterKey(in folder: URL) throws -> SymmetricKey {
        let data = try Data(contentsOf: folder.appendingPathComponent(keyName))
        guard data.count == 32 else { throw BackupError.notABackup }
        return SymmetricKey(data: data)
    }

    /// Puts an unpacked backup in place of the current archive. The current database and items are moved to
    /// `previous` (kept, never deleted here); the key file is removed from disk once the caller has stored it.
    public static func install(from folder: URL, database: URL, items: URL, previous: URL) throws {
        let fileManager = FileManager.default
        try validate(folder)
        try fileManager.createDirectory(at: previous, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let current = URL(fileURLWithPath: database.path + suffix)
            if fileManager.fileExists(atPath: current.path) {
                try fileManager.moveItem(
                    at: current, to: previous.appendingPathComponent(database.lastPathComponent + suffix))
            }
        }
        if fileManager.fileExists(atPath: items.path) {
            try fileManager.moveItem(at: items, to: previous.appendingPathComponent(items.lastPathComponent))
        }
        try fileManager.moveItem(at: folder.appendingPathComponent(databaseName), to: database)
        try fileManager.moveItem(at: folder.appendingPathComponent(itemsName), to: items)
    }

    // MARK: Password

    static func encryptionContext(_ password: String) throws -> ArchiveEncryptionContext {
        let context = ArchiveEncryptionContext(
            profile: .hkdf_sha256_aesctr_hmac__scrypt__none, compressionAlgorithm: .lzfse)
        do {
            try context.setPassword(try stretched(password))
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.archive("password rejected")
        }
        return context
    }

    /// Apple Archive accepts only long passwords: the user's one is stretched with PBKDF2-SHA256 into 64 hex
    /// characters; the archive then applies scrypt with its own random salt.
    static func stretched(_ password: String) throws -> String {
        guard password.count >= minimumPasswordLength else { throw BackupError.passwordTooShort }
        let salt = Array("com.giovannilombi.iago.backup.v1".utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = password.withCString { pointer in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2), pointer, strlen(pointer), salt, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 600_000, &derived, derived.count)
        }
        guard status == kCCSuccess else { throw BackupError.archive("key derivation failed") }
        return derived.map { String(format: "%02x", $0) }.joined()
    }
}
