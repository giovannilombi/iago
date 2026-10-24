import Foundation
import GRDB

/// A folder IAGO imports emails from (ADR-0050).
public struct WatchedFolder: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable, Identifiable {
    public static let databaseTableName = "watched_folder"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var path: String
    public var enabled: Bool
    /// Imported files go to the "Importate" subfolder.
    public var moveImported: Bool
    public var createdAt: Date
    public var lastScanAt: Date?
}

/// What happened to one file of a watched folder: the delta register (ADR-0050).
public struct WatchedFile: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable, Identifiable {
    public enum Outcome: String, Codable, Sendable { case imported, duplicate, excluded, failed }

    public static let databaseTableName = "watched_file"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var path: String
    public var folderId: String
    public var size: Int64
    public var modifiedAt: Date
    public var sha256: String
    public var outcome: Outcome
    /// Why it was excluded, or the error.
    public var reason: String?
    public var subject: String?
    public var itemId: String?
    public var seenAt: Date

    public var id: String { path }

    public init(
        path: String, folderId: String, size: Int64, modifiedAt: Date, sha256: String, outcome: Outcome,
        reason: String? = nil, subject: String? = nil, itemId: String? = nil, seenAt: Date = Date()
    ) {
        self.path = path
        self.folderId = folderId
        self.size = size
        self.modifiedAt = modifiedAt
        self.sha256 = sha256
        self.outcome = outcome
        self.reason = reason
        self.subject = subject
        self.itemId = itemId
        self.seenAt = seenAt
    }
}

/// A rule of the user, stored as JSON of `IAGOIngest.ImportRule` (Store does not depend on Ingest).
public struct StoredImportRule: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable, Identifiable {
    public static let databaseTableName = "import_rule"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var position: Int
    public var json: String
}

extension Archive {
    // MARK: Folders

    @discardableResult
    public func addWatchedFolder(path: String) throws -> WatchedFolder {
        let writer = self.writer
        let folder = WatchedFolder(
            id: newID(at: writer.now), path: path, enabled: true, moveImported: false, createdAt: now(), lastScanAt: nil
        )
        try database.writer.write { db in
            guard try WatchedFolder.filter(Column("path") == path).fetchCount(db) == 0 else { return }
            try folder.insert(db)
        }
        return folder
    }

    public func watchedFolders() throws -> [WatchedFolder] {
        try database.writer.read { db in try WatchedFolder.order(Column("created_at")).fetchAll(db) }
    }

    public func updateWatchedFolder(_ id: String, _ change: @Sendable (inout WatchedFolder) -> Void) throws {
        try database.writer.write { db in
            guard var folder = try WatchedFolder.fetchOne(db, key: id) else { throw ArchiveError.notFound(id) }
            change(&folder)
            try folder.update(db)
        }
    }

    /// Stops watching a folder; its register goes too (the emails stay in the archive).
    public func removeWatchedFolder(_ id: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM watched_file WHERE folder_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM watched_folder WHERE id = ?", arguments: [id])
        }
    }

    // MARK: Delta register

    /// The register entry of a path, to skip a file seen before and not changed.
    public func watchedFile(_ path: String) throws -> WatchedFile? {
        try database.writer.read { db in try WatchedFile.fetchOne(db, key: path) }
    }

    /// True if a file with this content was already handled (under another path, e.g. a copy).
    public func watchedContentSeen(sha256: String, except path: String) throws -> Bool {
        try database.writer.read { db in
            try WatchedFile.filter(Column("sha256") == sha256 && Column("path") != path).fetchCount(db) > 0
        }
    }

    public func recordWatchedFile(_ file: WatchedFile) throws {
        try database.writer.write { db in try file.save(db) }
    }

    /// The register moves with a file moved to "Importate".
    public func moveWatchedFile(from path: String, to newPath: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM watched_file WHERE path = ?", arguments: [newPath])
            try db.execute(sql: "UPDATE watched_file SET path = ? WHERE path = ?", arguments: [newPath, path])
        }
    }

    /// Recent excluded and failed files ("Scartate"), most recent first.
    public func discardedWatchedFiles(limit: Int = 200) throws -> [WatchedFile] {
        try database.writer.read { db in
            try WatchedFile.filter(["excluded", "failed"].contains(Column("outcome")))
                .order(Column("seen_at").desc).limit(limit).fetchAll(db)
        }
    }

    // MARK: Rules

    public func importRules() throws -> [StoredImportRule] {
        try database.writer.read { db in try StoredImportRule.order(Column("position")).fetchAll(db) }
    }

    /// Replaces the rules with these, in this order.
    public func setImportRules(_ rules: [(id: String, json: String)]) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM import_rule")
            for (position, rule) in rules.enumerated() {
                try StoredImportRule(id: rule.id, position: position, json: rule.json).insert(db)
            }
        }
    }

    public func newRuleID() -> String { newID(at: now()) }
}
