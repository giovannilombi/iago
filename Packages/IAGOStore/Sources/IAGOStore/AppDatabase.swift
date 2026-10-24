import Foundation
import GRDB

/// The SQLite archive (spec 8, ADR-0007): WAL, `secure_delete`, migrations applied on open.
public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    init(_ writer: any DatabaseWriter, migrate: Bool = true) throws {
        self.writer = writer
        if migrate { try Migrations.migrator.migrate(writer) }
    }

    /// Opens the app's database for writing without running migrations: the MCP server's write connection
    /// (ADR-0044). The schema is the app's, which ships in the same bundle.
    public static func openWithoutMigrating(at url: URL) throws -> AppDatabase {
        try AppDatabase(DatabasePool(path: url.path, configuration: configuration()), migrate: false)
    }

    /// Opens the app's database read-only, without migrations: for the MCP server (ADR-0043), which reads
    /// while the app keeps writing. Fails if the file does not exist.
    public static func openReadOnly(at url: URL) throws -> AppDatabase {
        var configuration = configuration()
        configuration.readonly = true
        return try AppDatabase(DatabasePool(path: url.path, configuration: configuration), migrate: false)
    }

    /// Opens (or creates) the database file. WAL lets readers run while the app writes (spec 12).
    public static func open(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try AppDatabase(DatabasePool(path: url.path, configuration: configuration()))
    }

    /// In-memory database, for tests and previews.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue(configuration: configuration()))
    }

    static func configuration() -> Configuration {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.busyMode = .timeout(5)
        configuration.prepareDatabase { db in
            // Deleted content is overwritten on disk, not just unlinked (spec 9.3).
            try db.execute(sql: "PRAGMA secure_delete = ON")
        }
        return configuration
    }
}
