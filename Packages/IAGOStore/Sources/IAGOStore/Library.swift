import Foundation
import GRDB

/// What the library shows (FR-70, reduced for phase 1: filters and timeline come in phase 2).
public enum LibraryScope: Hashable, Sendable {
    /// Items without a project, with or without a category (FR-21): an item leaves it only when it gets
    /// a project.
    case unclassified
    /// "Non definito": items without a project that already have a category (also in `unclassified`).
    case undefinedProject
    case recent
    case project(String)
    /// Every project of a client (ADR-0038).
    case client(String)
    /// Items in one stream of a project.
    case stream(String)
    case category(String)
    case tag(String)
}

/// One row of the item list (FR-73).
public struct ItemSummary: Sendable, Identifiable, Hashable {
    public var item: Item
    public var projectName: String?
    public var categoryName: String?
    public var tags: [String]
    public var streamIDs: [String] = []
    /// Links to other items (FR-202: visible on the timeline).
    public var linkCount = 0
    /// Direction and sender of an email.
    public var email: EmailMeta?
    public var hasAudio: Bool
    public var hasTranscript: Bool
    public var hasActiveJob: Bool

    public var id: String { item.id }
}

extension Archive {
    public func summaries(_ scope: LibraryScope) throws -> [ItemSummary] {
        try database.writer.read { db in
            var request = Item.filter(Column("deleted_at") == nil && Column("trashed_at") == nil)
            switch scope {
            case .unclassified: request = request.filter(Column("project_id") == nil)
            case .undefinedProject:
                request = request.filter(Column("project_id") == nil && Column("category_id") != nil)
            case .recent: break
            case .project(let id): request = request.filter(Column("project_id") == id)
            case .client(let id):
                request = request.filter(
                    sql: "project_id IN (SELECT id FROM project WHERE client_id = ? AND deleted_at IS NULL)",
                    arguments: [id])
            case .stream(let id):
                request = request.filter(
                    sql: "id IN (SELECT item_id FROM item_stream WHERE stream_id = ?)", arguments: [id])
            case .category(let id): request = request.filter(Column("category_id") == id)
            case .tag(let id):
                request = request.filter(sql: "id IN (SELECT item_id FROM item_tag WHERE tag_id = ?)", arguments: [id])
            }
            return try Self.summarize(try request.order(Column("occurred_at").desc).fetchAll(db), db)
        }
    }

    /// Items with this category (if any) and every one of these tags: «Categorie e tag» (ADR-0090). With neither,
    /// every item that has a category or a tag.
    public func summaries(categoryID: String?, tagIDs: Set<String>) throws -> [ItemSummary] {
        try database.writer.read { db in
            var request = Item.filter(Column("deleted_at") == nil && Column("trashed_at") == nil)
            if let categoryID { request = request.filter(Column("category_id") == categoryID) }
            if categoryID == nil, tagIDs.isEmpty {
                request = request.filter(
                    sql: "category_id IS NOT NULL OR id IN (SELECT item_id FROM item_tag)")
            }
            for tagID in tagIDs {
                request = request.filter(
                    sql: "id IN (SELECT item_id FROM item_tag WHERE tag_id = ?)", arguments: [tagID])
            }
            return try Self.summarize(try request.order(Column("occurred_at").desc).fetchAll(db), db)
        }
    }

    private static func summarize(_ items: [Item], _ db: Database) throws -> [ItemSummary] {
        let projects = Dictionary(uniqueKeysWithValues: try Project.fetchAll(db).map { ($0.id, $0.name) })
        let categories = Dictionary(uniqueKeysWithValues: try Category.fetchAll(db).map { ($0.id, $0.name) })
        return try items.map { item in
            let kinds = try String.fetchAll(
                db, sql: "SELECT kind FROM asset WHERE item_id = ? AND deleted_at IS NULL AND trashed_at IS NULL",
                arguments: [item.id])
            let tags = try String.fetchAll(
                db,
                sql: """
                    SELECT tag.name FROM tag JOIN item_tag ON item_tag.tag_id = tag.id
                    WHERE item_tag.item_id = ? AND tag.deleted_at IS NULL ORDER BY tag.normalized
                    """, arguments: [item.id])
            let activeJobs =
                try Int.fetchOne(
                    db, sql: "SELECT count(*) FROM job WHERE item_id = ? AND status IN ('queued', 'running')",
                    arguments: [item.id]) ?? 0
            let streamIDs = try String.fetchAll(
                db, sql: "SELECT stream_id FROM item_stream WHERE item_id = ?", arguments: [item.id])
            let linkCount =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT count(*) FROM item_link WHERE deleted_at IS NULL
                        AND (from_item_id = ? OR to_item_id = ?)
                        """, arguments: [item.id, item.id]) ?? 0
            let email = item.type == .email ? try EmailMeta.fetchOne(db, key: item.id) : nil
            return ItemSummary(
                item: item, projectName: item.projectId.flatMap { projects[$0] },
                categoryName: item.categoryId.flatMap { categories[$0] }, tags: tags, streamIDs: streamIDs,
                linkCount: linkCount, email: email,
                hasAudio: kinds.contains { Asset.Kind(rawValue: $0)?.isAudio == true },
                hasTranscript: kinds.contains(Asset.Kind.transcriptJSON.rawValue), hasActiveJob: activeJobs > 0)
        }
    }

    /// Fires after every committed change to the database, so views can reload.
    public func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        let observation = DatabaseRegionObservation(tracking: .fullDatabase)
        let cancellable = observation.start(
            in: database.writer, onError: { _ in continuation.finish() }, onChange: { _ in continuation.yield() })
        continuation.onTermination = { _ in cancellable.cancel() }
        return stream
    }

    /// SQLite's `data_version` on the writer connection: it changes only when another process commits, e.g. the
    /// MCP server writing through Claude (ADR-0044). Poll it to reload views; `changes()` sees only this process.
    public func externalChangeCounter() throws -> Int {
        try database.writer.writeWithoutTransaction { db in
            try Int.fetchOne(db, sql: "PRAGMA data_version") ?? 0
        }
    }

    public func updateCategory(_ id: String, _ change: @Sendable (inout Category) -> Void) throws {
        let writer = self.writer
        try database.writer.write { db in
            var category = try Self.require(Category.fetchOne(db, key: id), id)
            change(&category)
            try writer.save(&category, db)
        }
    }

    @discardableResult
    public func createCategory(name: String) throws -> Category {
        let writer = self.writer
        return try database.writer.write { db in
            let order = (try Int.fetchOne(db, sql: "SELECT max(sort_order) FROM category") ?? 0) + 1
            var category = Category(id: newID(at: writer.now), name: name, sortOrder: order)
            try writer.save(&category, db)
            return category
        }
    }

    // MARK: Project management (Settings › Progetti)

    public func renameProject(_ id: String, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try updateProject(id) { $0.name = trimmed }
    }

    /// Archived projects disappear from the sidebar and the pickers; their items stay untouched.
    public func setProjectArchived(_ id: String, _ archived: Bool) throws {
        try updateProject(id) { $0.archived = archived }
    }

    func updateProject(_ id: String, _ change: @Sendable (inout Project) -> Void) throws {
        let writer = self.writer
        try database.writer.write { db in
            var project = try Self.require(Project.fetchOne(db, key: id), id)
            change(&project)
            try writer.save(&project, db)
        }
    }

    public struct ProjectStats: Sendable, Equatable {
        public var items: Int
        public var transcripts: Int
        public var notes: Int
    }

    /// What deleting a project would destroy (shown in the first warning).
    public func projectStats(_ id: String) throws -> ProjectStats {
        try database.writer.read { db in
            let items =
                try Int.fetchOne(
                    db, sql: "SELECT count(*) FROM item WHERE project_id = ? AND deleted_at IS NULL", arguments: [id])
                ?? 0
            let transcripts =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT count(*) FROM asset JOIN item ON item.id = asset.item_id
                        WHERE item.project_id = ? AND item.deleted_at IS NULL AND asset.kind = 'transcript_json' AND asset.deleted_at IS NULL
                        """, arguments: [id]) ?? 0
            let notes =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT count(*) FROM note WHERE deleted_at IS NULL
                        AND (project_id = ? OR item_id IN (SELECT id FROM item WHERE project_id = ? AND deleted_at IS NULL))
                        """, arguments: [id, id]) ?? 0
            return ProjectStats(items: items, transcripts: transcripts, notes: notes)
        }
    }

    /// Deletes a project and everything in it for good (items with their files, transcripts and notes,
    /// project notes): crypto-shredding as for single items (spec 9.3). Not reversible.
    public func deleteProject(_ id: String) throws {
        let itemIDs = try database.writer.read { db in
            try String.fetchAll(
                db, sql: "SELECT id FROM item WHERE project_id = ? AND deleted_at IS NULL", arguments: [id])
        }
        for itemID in itemIDs { try purgeItem(itemID, notes: .delete) }
        // Originals kept by project notes, then the project key (crypto-shredding, ADR-0039).
        let projectAssets = try database.writer.read { db in
            try Asset.filter(Column("item_id") == id && Column("deleted_at") == nil).fetchAll(db)
        }
        for asset in projectAssets { try purgeAsset(asset.id) }
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM item_key WHERE item_id = ?", arguments: [id])
        }
        let folder = itemsRoot.appendingPathComponent(id, isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
        let writer = self.writer
        try database.writer.write { db in
            for var note in try Note.filter(Column("project_id") == id && Column("deleted_at") == nil).fetchAll(db) {
                note.body = ""
                try writer.tombstone(&note, db)
                try indexNote(note, db)
            }
            for var decision in try Decision.filter(Column("project_id") == id && Column("deleted_at") == nil)
                .fetchAll(db)
            {
                decision.text = ""
                decision.notes = nil
                decision.outcome = nil
                decision.estimate = nil
                try writer.tombstone(&decision, db)
                try db.execute(sql: "DELETE FROM decision_entity WHERE decision_id = ?", arguments: [decision.id])
                try db.execute(sql: "DELETE FROM decision_tag WHERE decision_id = ?", arguments: [decision.id])
                try Self.removeWork(decisionID: decision.id, writer: writer, db)
                try indexDecision(decision, db)
            }
            // The project's checklists go with it (ADR-0074).
            for var list in try Checklist.filter(Column("project_id") == id && Column("deleted_at") == nil).fetchAll(db)
            {
                for var line in try ChecklistItem.filter(
                    Column("checklist_id") == list.id && Column("deleted_at") == nil
                )
                .fetchAll(db) {
                    line.text = ""
                    try writer.tombstone(&line, db)
                }
                list.name = ""
                try writer.tombstone(&list, db)
            }
            for stream in try ProjectStream.filter(Column("project_id") == id && Column("deleted_at") == nil)
                .fetchAll(db)
            {
                try deleteStream(stream.id, writer: writer, db)
            }
            var project = try Self.require(Project.fetchOne(db, key: id), id)
            project.name = ""
            project.clientId = nil
            project.pinned = false
            try writer.tombstone(&project, db)
        }
    }
}
