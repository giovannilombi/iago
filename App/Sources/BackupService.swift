import AppKit
import CryptoKit
import Foundation
import IAGOCapture
import IAGOStore
import os

/// Encrypted backup and restore (spec 9.3, ADR-0041). A restore is unpacked and checked right away, then put in
/// place at the next launch, before the database is opened.
enum BackupService {
    private static let logger = Logger(subsystem: "com.giovannilombi.iago", category: "backup")
    static let lastBackupKey = "last_backup_at"

    static func create(archive: Archive, paths: StoragePaths, password: String, to destination: URL) async throws
        -> Backup.Manifest
    {
        let staging = paths.scratch.appendingPathComponent("backup-staging", isDirectory: true)
        let manifest = try await Task.detached(priority: .userInitiated) {
            try Backup.create(
                archive: archive, masterKey: try KeychainMasterKeyStore().masterKey(), password: password,
                to: destination, staging: staging)
        }.value
        try? archive.audit(.backup, action: "backup_created", detail: "\(manifest.items) items")
        try? archive.setSetting(lastBackupKey, ISO8601DateFormatter().string(from: Date()))
        return manifest
    }

    /// Unpacks and checks the backup; the swap happens at the next launch.
    static func prepareRestore(_ backup: URL, password: String, paths: StoragePaths) async throws -> Backup.Manifest {
        let pending = paths.restorePending
        return try await Task.detached(priority: .userInitiated) {
            try Backup.extract(backup, password: password, to: pending)
        }.value
    }

    /// At launch, before the database opens: if a restore is waiting, the current archive moves to
    /// "Archivi sostituiti/<date>", its key is kept in the keychain under a dated name, the backup takes its place.
    static func installPendingRestore(paths: StoragePaths) {
        let pending = paths.restorePending
        guard FileManager.default.fileExists(atPath: pending.path) else { return }
        do {
            let stamp = Self.stamp()
            let key = try Backup.masterKey(in: pending)
            try Backup.install(
                from: pending, database: paths.database, items: paths.items,
                previous: paths.replacedArchives.appendingPathComponent(stamp, isDirectory: true))
            try KeychainMasterKeyStore().replace(with: key, keepingCurrentAs: "master-key-before-restore-\(stamp)")
            try FileManager.default.removeItem(at: pending)
            logger.notice("Backup restored; previous archive kept as \(stamp, privacy: .public)")
        } catch {
            logger.error("Restore failed: \(error)")
            try? FileManager.default.removeItem(at: pending)
        }
    }

    /// An archive put aside by a restore: its folder and the keychain account of its key.
    struct ReplacedArchive: Identifiable, Hashable {
        var stamp: String
        var folder: URL
        var bytes: Int64
        var id: String { stamp }
        var keyAccount: String { "master-key-before-restore-\(stamp)" }
        var date: Date? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
            return formatter.date(from: stamp)
        }
    }

    static func replacedArchives(paths: StoragePaths) -> [ReplacedArchive] {
        let manager = FileManager.default
        let folders =
            (try? manager.contentsOfDirectory(
                at: paths.replacedArchives, includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles)) ?? []
        return
            folders
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { ReplacedArchive(stamp: $0.lastPathComponent, folder: $0, bytes: size(of: $0)) }
            .sorted { $0.stamp > $1.stamp }
    }

    /// Destroys a replaced archive for good: its files and the key kept for it in the keychain.
    static func deleteReplacedArchive(_ replaced: ReplacedArchive, archive: Archive) throws {
        try FileManager.default.removeItem(at: replaced.folder)
        try KeychainMasterKeyStore(account: replaced.keyAccount).remove()
        try? archive.audit(.backup, action: "replaced_archive_deleted", detail: replaced.stamp)
        logger.notice("Replaced archive deleted: \(replaced.stamp, privacy: .public)")
    }

    private static func size(of folder: URL) -> Int64 {
        let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey])
        var total: Int64 = 0
        while let url = enumerator?.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true { total += Int64(values?.totalFileAllocatedSize ?? 0) }
        }
        return total
    }

    /// Quits and opens IAGO again (the restore is applied at launch).
    @MainActor
    static func relaunch() {
        let path = Bundle.main.bundleURL.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"\(path)\""]
        try? process.run()
        NSApp.terminate(nil)
    }

    static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }
}
