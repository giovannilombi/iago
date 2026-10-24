import Foundation
import GRDB

/// Client › Project › Stream (ADR-0038). Clients only group projects; streams split a project and can be
/// set on items and decisions, several at a time.
extension Archive {
    /// Colors given in turn to new clients and streams (the UI maps the names to system colors).
    public static let palette = [
        "blue", "green", "orange", "purple", "pink", "teal", "yellow", "red", "indigo", "brown",
    ]

    // MARK: Clients

    public func clients(includeArchived: Bool = false) throws -> [Client] {
        try database.writer.read { db in
            var request = Client.filter(Column("deleted_at") == nil)
            if !includeArchived { request = request.filter(Column("archived") == false) }
            return try request.order(Column("name").collating(.localizedCaseInsensitiveCompare)).fetchAll(db)
        }
    }

    @discardableResult
    public func createClient(name: String) throws -> Client {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let writer = self.writer
        return try database.writer.write { db in
            let count = try Client.fetchCount(db)
            var client = Client(
                id: newID(at: writer.now), name: trimmed, color: Self.palette[count % Self.palette.count])
            try writer.save(&client, db)
            return client
        }
    }

    public func updateClient(_ id: String, _ change: @Sendable (inout Client) -> Void) throws {
        let writer = self.writer
        try database.writer.write { db in
            var client = try Self.require(Client.fetchOne(db, key: id), id)
            change(&client)
            client.name = client.name.trimmingCharacters(in: .whitespacesAndNewlines)
            try writer.save(&client, db)
        }
    }

    /// Deletes a client: its projects stay, without a client.
    public func deleteClient(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            for var project in try Project.filter(Column("client_id") == id).fetchAll(db) {
                project.clientId = nil
                try writer.save(&project, db)
            }
            var client = try Self.require(Client.fetchOne(db, key: id), id)
            client.name = ""
            try writer.tombstone(&client, db)
        }
    }

    public func setProjectClient(_ projectID: String, _ clientID: String?) throws {
        let writer = self.writer
        try database.writer.write { db in
            var project = try Self.require(Project.fetchOne(db, key: projectID), projectID)
            project.clientId = clientID
            try writer.save(&project, db)
        }
    }

    // MARK: Streams

    /// Streams of one project (or of every project), in their order.
    public func streams(projectID: String? = nil, includeArchived: Bool = false) throws -> [ProjectStream] {
        try database.writer.read { db in
            var request = ProjectStream.filter(Column("deleted_at") == nil)
            if let projectID { request = request.filter(Column("project_id") == projectID) }
            if !includeArchived { request = request.filter(Column("archived") == false) }
            return try request.order(Column("sort_order"), Column("name")).fetchAll(db)
        }
    }

    @discardableResult
    public func createStream(projectID: String, name: String) throws -> ProjectStream {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let writer = self.writer
        return try database.writer.write { db in
            let count = try ProjectStream.filter(Column("project_id") == projectID).fetchCount(db)
            var stream = ProjectStream(
                id: newID(at: writer.now), projectId: projectID, name: trimmed,
                color: Self.palette[count % Self.palette.count], sortOrder: count)
            try writer.save(&stream, db)
            return stream
        }
    }

    public func updateStream(_ id: String, _ change: @Sendable (inout ProjectStream) -> Void) throws {
        let writer = self.writer
        try database.writer.write { db in
            var stream = try Self.require(ProjectStream.fetchOne(db, key: id), id)
            change(&stream)
            stream.name = stream.name.trimmingCharacters(in: .whitespacesAndNewlines)
            try writer.save(&stream, db)
        }
    }

    /// Deletes a stream: items and decisions only lose the label.
    public func deleteStream(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in try deleteStream(id, writer: writer, db) }
    }

    func deleteStream(_ id: String, writer: SyncWriter, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM item_stream WHERE stream_id = ?", arguments: [id])
        try db.execute(sql: "DELETE FROM decision_stream WHERE stream_id = ?", arguments: [id])
        try db.execute(sql: "DELETE FROM note_stream WHERE stream_id = ?", arguments: [id])
        var stream = try Self.require(ProjectStream.fetchOne(db, key: id), id)
        stream.name = ""
        try writer.tombstone(&stream, db)
    }

    public func streamIDs(itemID: String) throws -> [String] {
        try database.writer.read { db in
            try String.fetchAll(db, sql: "SELECT stream_id FROM item_stream WHERE item_id = ?", arguments: [itemID])
        }
    }

    /// Sets the streams of an item; streams of other projects are ignored.
    public func setStreams(_ streamIDs: [String], itemID: String) throws {
        try database.writer.write { db in
            let projectID = try String.fetchOne(
                db, sql: "SELECT project_id FROM item WHERE id = ?", arguments: [itemID])
            try db.execute(sql: "DELETE FROM item_stream WHERE item_id = ?", arguments: [itemID])
            for id in Set(streamIDs) where try Self.stream(id, belongsTo: projectID, db) {
                try db.execute(
                    sql: "INSERT INTO item_stream (item_id, stream_id) VALUES (?, ?)", arguments: [itemID, id])
            }
        }
    }

    public func streamIDs(noteID: String) throws -> [String] {
        try database.writer.read { db in
            try String.fetchAll(db, sql: "SELECT stream_id FROM note_stream WHERE note_id = ?", arguments: [noteID])
        }
    }

    /// Sets the streams of a note (ADR-0047): streams of the note's project, or of its item's project.
    public func setStreams(_ streamIDs: [String], noteID: String) throws {
        try database.writer.write { db in
            let note = try Self.require(Note.fetchOne(db, key: noteID), noteID)
            try setNoteStreams(streamIDs, note: note, db)
        }
    }

    func setNoteStreams(_ streamIDs: [String], note: Note, _ db: Database) throws {
        let projectID =
            try note.projectId
            ?? note.itemId.flatMap {
                try String.fetchOne(db, sql: "SELECT project_id FROM item WHERE id = ?", arguments: [$0])
            }
        try db.execute(sql: "DELETE FROM note_stream WHERE note_id = ?", arguments: [note.id])
        for id in Set(streamIDs) where try Self.stream(id, belongsTo: projectID, db) {
            try db.execute(sql: "INSERT INTO note_stream (note_id, stream_id) VALUES (?, ?)", arguments: [note.id, id])
        }
    }

    func setDecisionStreams(_ streamIDs: [String], decisionID: String, projectID: String?, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM decision_stream WHERE decision_id = ?", arguments: [decisionID])
        for id in Set(streamIDs) where try Self.stream(id, belongsTo: projectID, db) {
            try db.execute(
                sql: "INSERT INTO decision_stream (decision_id, stream_id) VALUES (?, ?)", arguments: [decisionID, id])
        }
    }

    private static func stream(_ id: String, belongsTo projectID: String?, _ db: Database) throws -> Bool {
        guard let projectID else { return false }
        return try ProjectStream.filter(key: id).filter(
            Column("project_id") == projectID && Column("deleted_at") == nil
        )
        .fetchCount(db) > 0
    }

    /// After a move to another project: the old project's streams no longer apply.
    func dropForeignStreams(itemID: String, projectID: String?, _ db: Database) throws {
        try db.execute(
            sql: """
                DELETE FROM item_stream WHERE item_id = ?
                AND stream_id NOT IN (SELECT id FROM stream WHERE project_id IS ?)
                """, arguments: [itemID, projectID])
    }

    func dropForeignStreams(decisionID: String, projectID: String?, _ db: Database) throws {
        try db.execute(
            sql: """
                DELETE FROM decision_stream WHERE decision_id = ?
                AND stream_id NOT IN (SELECT id FROM stream WHERE project_id IS ?)
                """, arguments: [decisionID, projectID])
    }
}
