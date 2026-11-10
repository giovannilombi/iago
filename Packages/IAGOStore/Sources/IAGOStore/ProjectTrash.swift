import Foundation
import GRDB

/// A project in the trash (ADR-0099): it disappears from the sidebar, the pickers, search, «Inbox», the graph and
/// Claude, but stays on the Mac for `trashRetention` (30 days), then it is deleted for good with `deleteProject`.
/// Its items go to the trash with it, with their own reason, so every query that leaves out trashed items leaves
/// them out too; its notes, key points, checklists and streams are left out with `outsideTrashedProjects`.
extension Archive {
    /// `trash_reason` of the items that went to the trash with their project (not listed among the trashed items).
    static let projectTrashReason = "project"

    /// SQL condition: `column` (a project id, possibly NULL) is not a project in the trash.
    public static func outsideTrashedProjects(_ column: String) -> String {
        "(\(column) IS NULL OR \(column) NOT IN (SELECT id FROM project WHERE trashed_at IS NOT NULL))"
    }

    /// Moves a project to the trash, with its items (those already in the trash keep their own date).
    public func trashProject(_ id: String) throws {
        let writer = self.writer
        let now = self.now()
        try database.writer.write { db in
            var project = try Self.require(Project.fetchOne(db, key: id), id)
            guard project.deletedAt == nil, project.trashedAt == nil else { return }
            for var item in try Item.filter(
                Column("project_id") == id && Column("deleted_at") == nil && Column("trashed_at") == nil
            ).fetchAll(db) {
                item.trashedAt = now
                item.trashReason = Self.projectTrashReason
                try writer.save(&item, db)
            }
            project.trashedAt = now
            try writer.save(&project, db)
        }
    }

    /// Puts a project back as it was, with the items that went to the trash with it.
    public func restoreProject(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            var project = try Self.require(Project.fetchOne(db, key: id), id)
            guard project.deletedAt == nil, project.trashedAt != nil else { return }
            for var item in try Item.filter(
                Column("project_id") == id && Column("deleted_at") == nil
                    && Column("trash_reason") == Self.projectTrashReason
            ).fetchAll(db) {
                item.trashedAt = nil
                item.trashReason = nil
                try writer.save(&item, db)
            }
            // The client may have been deleted meanwhile: then the project comes back without one.
            if let clientID = project.clientId,
                try Client.filter(key: clientID).filter(Column("deleted_at") == nil).fetchCount(db) == 0
            {
                project.clientId = nil
            }
            project.trashedAt = nil
            try writer.save(&project, db)
        }
    }

    /// Projects in the trash, most recent first.
    public func trashedProjects() throws -> [Project] {
        try database.writer.read { db in
            try Project.filter(Column("deleted_at") == nil && Column("trashed_at") != nil)
                .order(Column("trashed_at").desc).fetchAll(db)
        }
    }

    public struct StreamStats: Sendable, Equatable {
        public var items: Int
        public var decisions: Int
        public var notes: Int
    }

    /// What loses the label when a stream is deleted (shown in its confirmation).
    public func streamStats(_ id: String) throws -> StreamStats {
        try database.writer.read { db in
            let items =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT count(*) FROM item_stream JOIN item ON item.id = item_stream.item_id
                        WHERE item_stream.stream_id = ? AND item.deleted_at IS NULL
                        """, arguments: [id]) ?? 0
            let decisions =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT count(*) FROM decision_stream JOIN decision ON decision.id = decision_stream.decision_id
                        WHERE decision_stream.stream_id = ? AND decision.deleted_at IS NULL
                        """, arguments: [id]) ?? 0
            let notes =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT count(*) FROM note_stream JOIN note ON note.id = note_stream.note_id
                        WHERE note_stream.stream_id = ? AND note.deleted_at IS NULL
                        """, arguments: [id]) ?? 0
            return StreamStats(items: items, decisions: decisions, notes: notes)
        }
    }
}
