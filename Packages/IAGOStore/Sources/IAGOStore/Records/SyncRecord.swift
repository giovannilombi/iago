import Foundation
import GRDB
import IAGOCore

/// A user table row with the sync columns of spec 8.1. Every write goes through `SyncWriter`, which
/// bumps the version and appends to `change_log` in the same transaction.
public protocol SyncRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    var id: String { get }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var version: Int { get set }
    var deviceId: String { get set }
}

extension SyncRecord {
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }
}

/// New UUIDv7 identifier as stored in the database (lowercase string, ADR-0008).
func newID(at date: Date) -> String {
    UUIDv7.make(at: date).uuidString.lowercased()
}

struct ChangeLog {
    enum Operation: String {
        case insert, update, delete
    }

    static func append(_ db: Database, table: String, rowID: String, op: Operation, version: Int, at: Date) throws {
        try db.execute(
            sql: "INSERT INTO change_log (table_name, row_id, op, version, at) VALUES (?, ?, ?, ?, ?)",
            arguments: [table, rowID, op.rawValue, version, at])
    }
}

struct SyncWriter {
    let deviceID: String
    let now: Date

    /// Inserts or updates `record`: sets the sync columns and logs the change.
    func save<R: SyncRecord>(_ record: inout R, _ db: Database) throws {
        let current = try Int.fetchOne(
            db, sql: "SELECT version FROM \(R.databaseTableName) WHERE id = ?", arguments: [record.id])
        if current == nil { record.createdAt = now }
        record.version = (current ?? 0) + 1
        record.updatedAt = now
        record.deviceId = deviceID
        try record.save(db)
        let op: ChangeLog.Operation = current == nil ? .insert : (record.deletedAt != nil ? .delete : .update)
        try ChangeLog.append(db, table: R.databaseTableName, rowID: record.id, op: op, version: record.version, at: now)
    }

    /// Tombstone (spec 8.1): the row stays for the future sync, the caller clears sensitive content.
    func tombstone<R: SyncRecord>(_ record: inout R, _ db: Database) throws {
        record.deletedAt = now
        try save(&record, db)
    }
}
