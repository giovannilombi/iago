import Foundation
import GRDB

/// Who produced a summary or a proposal (ADR-0070): the local engine on the Mac, or Claude through MCP.
public enum ResultOrigin: String, Codable, Sendable, Hashable { case engine, claude }

/// The summary of an item, written by the local engine with its category's template (ADR-0054), or by Claude through
/// MCP (ADR-0071). One per item; the user can edit it.
public struct ItemSummaryText: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "summary"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var itemId: String
    public var categoryId: String?
    public var templateId: String?
    public var markdown: String
    /// The engine that wrote it (catalog id), or for Claude the app it was used from.
    public var model: String?
    /// Changed by hand: regenerating asks first.
    public var edited: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var origin: ResultOrigin = .engine
}

/// A category of the library (ADR-0054): name, family (nil: main) and template.
public struct CategoryLibraryEntry: Sendable {
    public var name: String
    public var family: String?
    public var templateID: String
}

extension Category {
    /// Main categories first, then the families, which start switched off (ADR-0054).
    public static let library: [CategoryLibraryEntry] = [
        .init(name: "1to1", family: nil, templateID: "oneOnOne"),
        .init(name: "Kickoff", family: nil, templateID: "kickoff"),
        .init(name: "SAL", family: nil, templateID: "projectSync"),
        .init(name: "Workshop", family: nil, templateID: "brainstorming"),
        .init(name: "Review/Demo", family: nil, templateID: "designReview"),
        .init(name: "Client/Sales", family: nil, templateID: "clientSales"),
        .init(name: "Customer discovery", family: nil, templateID: "customerDiscovery"),
        .init(name: "Interna", family: nil, templateID: "standard"),
        .init(name: "Altro", family: nil, templateID: "standard"),
        .init(name: "Sprint planning", family: "Agile", templateID: "sprintPlanning"),
        .init(name: "Daily standup", family: "Agile", templateID: "dailyStandup"),
        .init(name: "Retrospective", family: "Agile", templateID: "retrospective"),
        .init(name: "Board meeting", family: "Direzione", templateID: "boardMeeting"),
        .init(name: "Executive briefing", family: "Direzione", templateID: "executiveBriefing"),
        .init(name: "Investor pitch", family: "Direzione", templateID: "investorPitch"),
        .init(name: "Performance review", family: "Persone", templateID: "performanceReview"),
        .init(name: "Incident postmortem", family: "Operazioni", templateID: "incidentPostmortem"),
    ]

    /// Families in the order they are shown.
    public static let families = ["Agile", "Direzione", "Persone", "Operazioni"]
}

extension Archive {
    static let libraryKey = "categories.library"

    /// Once: "Commerciale" becomes "Client/Sales", every category of the library gets its template, the new ones
    /// are added (main ones on, family ones off). Categories the user renamed or made are left alone.
    func seedCategoryLibrary() throws {
        guard try setting(Self.libraryKey) == nil else { return }
        let writer = self.writer
        try database.writer.write { db in
            let all = try Category.filter(Column("deleted_at") == nil).fetchAll(db)
            func existing(_ name: String) -> Category? {
                all.first { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            }
            if var commercial = existing("Commerciale"), commercial.isBuiltin, existing("Client/Sales") == nil {
                commercial.name = "Client/Sales"
                try writer.save(&commercial, db)
            }
            var order = (all.map(\.sortOrder).max() ?? 0) + 1
            for entry in Category.library {
                let current = try Category.filter(Column("deleted_at") == nil).fetchAll(db).first {
                    $0.name.compare(entry.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }
                if var category = current {
                    guard category.templateId == nil else { continue }
                    category.templateId = entry.templateID
                    try writer.save(&category, db)
                } else {
                    var category = Category(
                        id: newID(at: writer.now), name: entry.name, sortOrder: order, isBuiltin: true,
                        archived: entry.family != nil, family: entry.family, templateId: entry.templateID)
                    order += 1
                    try writer.save(&category, db)
                }
            }
            // Main categories of the library in the library's order, the user's own after them.
            let names = Category.library.filter { $0.family == nil }.map { $0.name.lowercased() }
            let main = try Category.filter(Column("deleted_at") == nil && Column("family") == nil)
                .order(Column("sort_order")).fetchAll(db)
            let sorted = main.sorted {
                (names.firstIndex(of: $0.name.lowercased()) ?? Int.max, $0.sortOrder)
                    < (names.firstIndex(of: $1.name.lowercased()) ?? Int.max, $1.sortOrder)
            }
            for (position, var category) in sorted.enumerated() where category.sortOrder != position {
                category.sortOrder = position
                try writer.save(&category, db)
            }
        }
        try setSetting(Self.libraryKey, "1")
    }

    // MARK: Categories (ADR-0054)

    /// Turns a family category on (shown in the pickers) or off.
    public func setCategoryActive(_ id: String, _ active: Bool) throws {
        try updateCategory(id) { $0.archived = !active }
    }

    /// The template a category uses: one of the library (`templateID`, nil for none) or the user's version.
    public func setCategoryTemplate(_ id: String, templateID: String?, customJSON: String?) throws {
        try updateCategory(id) {
            $0.templateId = templateID
            $0.templateJson = customJSON
        }
    }

    public func category(_ id: String) throws -> Category? {
        try database.writer.read { db in try Category.fetchOne(db, key: id) }
    }

    // MARK: Summaries

    public func summary(itemID: String) throws -> ItemSummaryText? {
        try database.writer.read { db in try ItemSummaryText.fetchOne(db, key: itemID) }
    }

    /// A summary written by the engine: replaces the previous one.
    public func saveSummary(
        itemID: String, categoryID: String?, templateID: String?, markdown: String, model: String?,
        origin: ResultOrigin = .engine
    ) throws {
        let now = self.now()
        try database.writer.write { db in
            let created = try ItemSummaryText.fetchOne(db, key: itemID)?.createdAt ?? now
            let summary = ItemSummaryText(
                itemId: itemID, categoryId: categoryID, templateId: templateID, markdown: markdown, model: model,
                edited: false, createdAt: created, updatedAt: now, origin: origin)
            try summary.save(db)
            try indexSummary(summary, db)
        }
    }

    /// Puts back a summary as it was (undoing a summary Claude wrote over it, ADR-0071).
    public func restoreSummary(_ summary: ItemSummaryText) throws {
        try database.writer.write { db in
            try summary.save(db)
            try indexSummary(summary, db)
        }
    }

    /// The user's edit.
    public func editSummary(itemID: String, markdown: String) throws {
        let now = self.now()
        try database.writer.write { db in
            guard var summary = try ItemSummaryText.fetchOne(db, key: itemID) else { return }
            summary.markdown = markdown
            summary.edited = true
            summary.updatedAt = now
            try summary.update(db)
            try indexSummary(summary, db)
        }
    }

    public func deleteSummary(itemID: String) throws {
        try database.writer.write { db in
            _ = try ItemSummaryText.deleteOne(db, key: itemID)
            try db.execute(
                sql: "DELETE FROM search_index WHERE item_id = ? AND source = 'summary'", arguments: [itemID])
        }
    }

    /// Items with a summary, for the list badges.
    public func summarizedItemIDs() throws -> Set<String> {
        try database.writer.read { db in Set(try String.fetchAll(db, sql: "SELECT item_id FROM summary")) }
    }

    private func indexSummary(_ summary: ItemSummaryText, _ db: Database) throws {
        try db.execute(
            sql: "DELETE FROM search_index WHERE item_id = ? AND source = 'summary'", arguments: [summary.itemId])
        let projectID = try String.fetchOne(
            db, sql: "SELECT project_id FROM item WHERE id = ?", arguments: [summary.itemId])
        let paragraphs = summary.markdown.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for (index, paragraph) in paragraphs.enumerated() {
            try db.execute(
                sql:
                    "INSERT INTO search_index (item_id, project_id, source, source_id, text) VALUES (?, ?, 'summary', ?, ?)",
                arguments: [summary.itemId, projectID, "\(summary.itemId)#summary\(index)", paragraph])
        }
    }
}

extension Archive {
    /// How many items (not in the trash) each category and each tag has: "Categorie e tag" (ADR-0054).
    public func labelCounts() throws -> (categories: [String: Int], tags: [String: Int]) {
        try database.writer.read { db in
            var categories: [String: Int] = [:]
            for row in try Row.fetchAll(
                db,
                sql: """
                    SELECT category_id, COUNT(*) AS n FROM item
                    WHERE deleted_at IS NULL AND trashed_at IS NULL AND category_id IS NOT NULL GROUP BY category_id
                    """)
            {
                categories[row["category_id"]] = row["n"]
            }
            var tags: [String: Int] = [:]
            for row in try Row.fetchAll(
                db,
                sql: """
                    SELECT item_tag.tag_id, COUNT(*) AS n FROM item_tag JOIN item ON item.id = item_tag.item_id
                    WHERE item.deleted_at IS NULL AND item.trashed_at IS NULL GROUP BY item_tag.tag_id
                    """)
            {
                tags[row["tag_id"]] = row["n"]
            }
            return (categories, tags)
        }
    }
}
