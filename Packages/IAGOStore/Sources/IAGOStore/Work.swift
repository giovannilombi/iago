import Foundation
import GRDB

/// How much work management the user sees (ADR-0074): the same data, two views of it.
public enum WorkMode: String, Codable, Sendable, CaseIterable {
    /// "Traccia": open, waiting, done, cancelled; owner, due date, waiting for, checklist.
    case track
    /// "Gestisci": every state and field, the kanban, the full overview.
    case manage
}

/// A named list of a project, pinned at the top of its overview (ADR-0074).
public struct Checklist: SyncRecord, Identifiable, Hashable {
    public static let databaseTableName = "checklist"
    public var id: String
    public var projectId: String
    public var name: String
    public var pinned = true
    public var sortOrder = 0
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

/// One line to tick: of an activity (`decisionId`) or of a project's list (`checklistId`).
public struct ChecklistItem: SyncRecord, Identifiable, Hashable {
    public static let databaseTableName = "checklist_item"
    public var id: String
    public var decisionId: String?
    public var checklistId: String?
    public var text: String
    public var done = false
    public var sortOrder = 0
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

/// A free column of a board, after the fixed ones: it groups entries without changing their state.
public struct BoardColumn: SyncRecord, Identifiable, Hashable {
    public static let databaseTableName = "board_column"
    public var id: String
    /// `BoardScope.key`.
    public var scope: String
    public var name: String
    public var sortOrder = 0
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

/// Which board: every project, or one project, client or stream.
public enum BoardScope: Sendable, Hashable {
    case all
    case project(String)
    case client(String)
    case stream(String)

    public var key: String {
        switch self {
        case .all: "all"
        case .project(let id): "project:\(id)"
        case .client(let id): "client:\(id)"
        case .stream(let id): "stream:\(id)"
        }
    }

    public var query: DecisionQuery.Scope {
        switch self {
        case .all: .all
        case .project(let id): .project(id)
        case .client(let id): .client(id)
        case .stream(let id): .stream(id)
        }
    }
}

public enum WorkError: Error, Equatable {
    /// The entry would depend on itself, directly or through others.
    case dependencyCycle
}

/// Open work (ADR-0074): mode, people, dependencies, checklists, boards, repeating entries.
extension Archive {
    public static let workModeKey = "work.mode"
    /// The kanban is shown in "Gestisci" unless the user turns it off.
    public static let boardEnabledKey = "work.board"
    /// "Mostra tutte" on the archived column of the board, remembered.
    public static let boardShowArchivedKey = "work.board.show_archived"
    /// Entries closed for longer than this leave the "Fatta" column (until "Mostra tutte").
    public static let boardArchiveDays = 14

    // MARK: Mode

    public func workMode() -> WorkMode {
        ((try? setting(Self.workModeKey)) ?? nil).flatMap(WorkMode.init(rawValue:)) ?? .track
    }

    public func setWorkMode(_ mode: WorkMode) throws {
        try setSetting(Self.workModeKey, mode == .track ? nil : mode.rawValue)
    }

    /// The mode a project is shown in: the app's, unless the project is kept in "Traccia".
    public func workMode(projectID: String?) -> WorkMode {
        let app = workMode()
        guard app == .manage, let projectID,
            let mode = try? database.writer.read({ db in
                try String.fetchOne(db, sql: "SELECT work_mode FROM project WHERE id = ?", arguments: [projectID])
            })
        else { return app }
        return WorkMode(rawValue: mode) ?? app
    }

    public func setProjectWorkMode(_ projectID: String, _ mode: WorkMode?) throws {
        try updateProject(projectID) { $0.workMode = mode }
    }

    // MARK: People

    /// The person entity with this name, created if needed ("persone già note + nuove al volo").
    public func person(named name: String) throws -> Entity? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = TagNormalizer.normalize(trimmed)
        guard !normalized.isEmpty else { return nil }
        let writer = self.writer
        return try database.writer.write { db in
            if var existing = try Entity.filter(
                Column("type") == Entity.Kind.person.rawValue && Column("normalized") == normalized
            ).fetchOne(db) {
                if existing.deletedAt != nil {
                    existing.deletedAt = nil
                    try writer.save(&existing, db)
                }
                return existing
            }
            var entity = Entity(id: newID(at: writer.now), type: .person, name: trimmed, normalized: normalized)
            try writer.save(&entity, db)
            return entity
        }
    }

    /// Known people whose name looks like `name` but is not it: "Intendi Marco Rossi?" before creating a new one.
    public func similarPeople(to name: String) throws -> [Entity] {
        let wanted = TagNormalizer.normalize(name)
        guard !wanted.isEmpty else { return [] }
        let words = Set(wanted.split(separator: " ").map(String.init))
        return try people().filter { person in
            guard person.normalized != wanted else { return false }
            let theirs = Set(person.normalized.split(separator: " ").map(String.init))
            // One name inside the other ("Marco" / "Marco Rossi"), or a typo ("Marco Rosi").
            if !words.isDisjoint(with: theirs), words.isSubset(of: theirs) || theirs.isSubset(of: words) {
                return true
            }
            return Self.distance(person.normalized, wanted) <= max(1, min(wanted.count, person.normalized.count) / 6)
        }
    }

    public func personName(_ id: String?) throws -> String? {
        guard let id else { return nil }
        return try database.writer.read { db in
            try String.fetchOne(db, sql: "SELECT name FROM entity WHERE id = ?", arguments: [id])
        }
    }

    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }

    // MARK: Dependencies ("Dipende da")

    public func blockers(of id: String) throws -> [Decision] {
        try database.writer.read { db in
            try Decision.fetchAll(
                db,
                sql: """
                    SELECT decision.* FROM decision JOIN decision_dependency ON decision.id = blocker_id
                    WHERE blocked_id = ? AND decision.deleted_at IS NULL ORDER BY decision.decided_at
                    """, arguments: [id])
        }
    }

    /// Replaces what an entry depends on. It becomes "Bloccata" while one of them is open, and goes back to "Da
    /// fare" when they are all closed.
    public func setBlockers(_ blockers: [String], of id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            for blocker in Set(blockers) {
                if try blocker == id || Self.dependsOn(blocker, id, db) { throw WorkError.dependencyCycle }
            }
            let had =
                try Int.fetchOne(
                    db, sql: "SELECT count(*) FROM decision_dependency WHERE blocked_id = ?", arguments: [id])
                ?? 0
            try db.execute(sql: "DELETE FROM decision_dependency WHERE blocked_id = ?", arguments: [id])
            for blocker in Set(blockers) {
                try db.execute(
                    sql: "INSERT INTO decision_dependency (blocked_id, blocker_id, created_at) VALUES (?, ?, ?)",
                    arguments: [id, blocker, writer.now])
            }
            try Self.recomputeBlocked([id], dependenciesRemoved: had > 0 && blockers.isEmpty, writer: writer, db)
        }
    }

    /// True if `from` depends on `to`, directly or through other entries.
    static func dependsOn(_ from: String, _ to: String, _ db: Database) throws -> Bool {
        var stack = [from]
        var seen: Set<String> = []
        while let current = stack.popLast() {
            for next in try String.fetchAll(
                db, sql: "SELECT blocker_id FROM decision_dependency WHERE blocked_id = ?", arguments: [current])
            {
                if next == to { return true }
                if seen.insert(next).inserted { stack.append(next) }
            }
        }
        return false
    }

    /// Entries with an open blocker become blocked; entries whose blockers are all closed go back to "Da fare". A
    /// state set by hand on an entry without dependencies is left alone, unless `dependenciesRemoved`: its last
    /// dependency was just taken away, so the block came from it.
    static func recomputeBlocked(
        _ ids: [String], dependenciesRemoved: Bool = false, writer: SyncWriter, _ db: Database
    ) throws {
        for id in Set(ids) {
            guard var decision = try Decision.fetchOne(db, key: id), decision.deletedAt == nil, decision.kind.isWork
            else { continue }
            let blockers = try Decision.fetchAll(
                db,
                sql: """
                    SELECT decision.* FROM decision JOIN decision_dependency ON decision.id = blocker_id
                    WHERE blocked_id = ? AND decision.deleted_at IS NULL
                    """, arguments: [id])
            guard !blockers.isEmpty || decision.status == .blocked else { continue }
            // A valid decision is "active" but is not work to wait for.
            let open = blockers.contains { $0.kind.isWork && $0.status.isOpen }
            if open, decision.status == .active || decision.status == .inProgress {
                decision.status = .blocked
                try writer.save(&decision, db)
            } else if !open, !blockers.isEmpty || dependenciesRemoved, decision.status == .blocked {
                decision.status = .active
                try writer.save(&decision, db)
            }
        }
    }

    /// After `id` changed state: what it blocks may be blocked or free now.
    static func recomputeDependents(of id: String, writer: SyncWriter, _ db: Database) throws {
        let dependents = try String.fetchAll(
            db, sql: "SELECT blocked_id FROM decision_dependency WHERE blocker_id = ?", arguments: [id])
        try recomputeBlocked(dependents, writer: writer, db)
    }

    // MARK: Checklists

    /// The sub-items of an activity, or the lines of a project's list, in order.
    public func checklistItems(decisionID: String? = nil, checklistID: String? = nil) throws -> [ChecklistItem] {
        try database.writer.read { db in
            var request = ChecklistItem.filter(Column("deleted_at") == nil)
            if let decisionID { request = request.filter(Column("decision_id") == decisionID) }
            if let checklistID { request = request.filter(Column("checklist_id") == checklistID) }
            return try request.order(Column("sort_order"), Column("created_at")).fetchAll(db)
        }
    }

    @discardableResult
    public func addChecklistItem(_ text: String, decisionID: String? = nil, checklistID: String? = nil) throws
        -> ChecklistItem
    {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DecisionError.emptyText }
        let writer = self.writer
        return try database.writer.write { db in
            let last =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT max(sort_order) FROM checklist_item
                        WHERE deleted_at IS NULL AND (decision_id IS ? AND checklist_id IS ?)
                        """, arguments: [decisionID, checklistID]) ?? -1
            var item = ChecklistItem(
                id: newID(at: writer.now), decisionId: decisionID, checklistId: checklistID, text: trimmed,
                sortOrder: last + 1)
            try writer.save(&item, db)
            return item
        }
    }

    public func updateChecklistItem(_ id: String, _ change: (inout ChecklistItem) -> Void) throws {
        let writer = self.writer
        try database.writer.write { db in
            var item = try Self.require(ChecklistItem.fetchOne(db, key: id), id)
            change(&item)
            item.text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.text.isEmpty else { throw DecisionError.emptyText }
            try writer.save(&item, db)
        }
    }

    public func deleteChecklistItem(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            guard var item = try ChecklistItem.fetchOne(db, key: id) else { return }
            item.text = ""
            try writer.tombstone(&item, db)
        }
    }

    /// New order of the lines of one list.
    public func reorderChecklist(_ ids: [String]) throws {
        let writer = self.writer
        try database.writer.write { db in
            for (index, id) in ids.enumerated() {
                guard var item = try ChecklistItem.fetchOne(db, key: id), item.sortOrder != index else { continue }
                item.sortOrder = index
                try writer.save(&item, db)
            }
        }
    }

    /// Replaces the whole checklist of an entry (Claude, and undoing Claude's change): lines with the same text keep
    /// their item, the others are added or removed.
    public func replaceChecklist(_ lines: [MCPPrevious.ChecklistLine], decisionID: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            var existing = try ChecklistItem.filter(Column("decision_id") == decisionID && Column("deleted_at") == nil)
                .order(Column("sort_order"), Column("created_at")).fetchAll(db)
            for (index, line) in lines.enumerated() {
                let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                if let position = existing.firstIndex(where: { $0.text == text }) {
                    var item = existing.remove(at: position)
                    guard item.done != line.done || item.sortOrder != index else { continue }
                    item.done = line.done
                    item.sortOrder = index
                    try writer.save(&item, db)
                } else {
                    var item = ChecklistItem(
                        id: newID(at: writer.now), decisionId: decisionID, text: text, done: line.done,
                        sortOrder: index)
                    try writer.save(&item, db)
                }
            }
            for var item in existing {
                item.text = ""
                try writer.tombstone(&item, db)
            }
        }
    }

    /// Done and total lines of each activity's checklist, for the badges of lists and boards.
    public func checklistProgress(decisionIDs: [String]) throws -> [String: (done: Int, total: Int)] {
        guard !decisionIDs.isEmpty else { return [:] }
        return try database.writer.read { db in
            var result: [String: (done: Int, total: Int)] = [:]
            for row in try Row.fetchAll(
                db,
                sql: """
                    SELECT decision_id, sum(done) AS done, count(*) AS total FROM checklist_item
                    WHERE deleted_at IS NULL AND decision_id IN (\(decisionIDs.map { _ in "?" }.joined(separator: ",")))
                    GROUP BY decision_id
                    """, arguments: StatementArguments(decisionIDs))
            {
                result[row["decision_id"]] = (row["done"], row["total"])
            }
            return result
        }
    }

    public func checklists(projectID: String? = nil, pinnedOnly: Bool = false) throws -> [Checklist] {
        try database.writer.read { db in
            var request = Checklist.filter(Column("deleted_at") == nil)
            if let projectID { request = request.filter(Column("project_id") == projectID) }
            if pinnedOnly { request = request.filter(Column("pinned") == true) }
            return try request.order(Column("sort_order"), Column("created_at")).fetchAll(db)
        }
    }

    @discardableResult
    public func createChecklist(projectID: String, name: String) throws -> Checklist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DecisionError.emptyText }
        let writer = self.writer
        return try database.writer.write { db in
            let count =
                try Int.fetchOne(
                    db, sql: "SELECT count(*) FROM checklist WHERE project_id = ? AND deleted_at IS NULL",
                    arguments: [projectID]) ?? 0
            var list = Checklist(id: newID(at: writer.now), projectId: projectID, name: trimmed, sortOrder: count)
            try writer.save(&list, db)
            return list
        }
    }

    public func updateChecklist(_ id: String, _ change: (inout Checklist) -> Void) throws {
        let writer = self.writer
        try database.writer.write { db in
            var list = try Self.require(Checklist.fetchOne(db, key: id), id)
            change(&list)
            try writer.save(&list, db)
        }
    }

    public func deleteChecklist(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            guard var list = try Checklist.fetchOne(db, key: id) else { return }
            for var item in try ChecklistItem.filter(Column("checklist_id") == id && Column("deleted_at") == nil)
                .fetchAll(db)
            {
                item.text = ""
                try writer.tombstone(&item, db)
            }
            list.name = ""
            try writer.tombstone(&list, db)
        }
    }

    // MARK: Boards

    public func boardColumns(_ scope: BoardScope) throws -> [BoardColumn] {
        try database.writer.read { db in
            try BoardColumn.filter(Column("scope") == scope.key && Column("deleted_at") == nil)
                .order(Column("sort_order"), Column("created_at")).fetchAll(db)
        }
    }

    @discardableResult
    public func addBoardColumn(_ scope: BoardScope, name: String) throws -> BoardColumn {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DecisionError.emptyText }
        let writer = self.writer
        return try database.writer.write { db in
            let count =
                try Int.fetchOne(
                    db, sql: "SELECT count(*) FROM board_column WHERE scope = ? AND deleted_at IS NULL",
                    arguments: [scope.key]) ?? 0
            var column = BoardColumn(id: newID(at: writer.now), scope: scope.key, name: trimmed, sortOrder: count)
            try writer.save(&column, db)
            return column
        }
    }

    public func renameBoardColumn(_ id: String, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DecisionError.emptyText }
        let writer = self.writer
        try database.writer.write { db in
            var column = try Self.require(BoardColumn.fetchOne(db, key: id), id)
            column.name = trimmed
            try writer.save(&column, db)
        }
    }

    /// Removes a free column: its entries go back to the column of their state.
    public func deleteBoardColumn(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            guard var column = try BoardColumn.fetchOne(db, key: id) else { return }
            try db.execute(sql: "DELETE FROM board_place WHERE column_id = ?", arguments: [id])
            try writer.tombstone(&column, db)
        }
    }

    public func reorderBoardColumns(_ ids: [String]) throws {
        let writer = self.writer
        try database.writer.write { db in
            for (index, id) in ids.enumerated() {
                guard var column = try BoardColumn.fetchOne(db, key: id), column.sortOrder != index else { continue }
                column.sortOrder = index
                try writer.save(&column, db)
            }
        }
    }

    /// Entry → free column of this board. Entries not listed are in the column of their state.
    public func boardPlaces(_ scope: BoardScope) throws -> [String: String] {
        try database.writer.read { db in
            Dictionary(
                uniqueKeysWithValues: try Row.fetchAll(
                    db, sql: "SELECT decision_id, column_id FROM board_place WHERE scope = ?", arguments: [scope.key]
                ).map { ($0["decision_id"], $0["column_id"]) })
        }
    }

    /// Puts an entry in a free column (nil: back to the column of its state). Its state does not change.
    public func placeOnBoard(_ decisionID: String, column columnID: String?, scope: BoardScope) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "DELETE FROM board_place WHERE scope = ? AND decision_id = ?", arguments: [scope.key, decisionID])
            if let columnID {
                try db.execute(
                    sql: "INSERT INTO board_place (scope, decision_id, column_id) VALUES (?, ?, ?)",
                    arguments: [scope.key, decisionID, columnID])
            }
        }
    }

    // MARK: Inside the register

    /// An entry deleted for good: its dependencies, board places and checklist go; what it blocked is freed.
    static func removeWork(decisionID id: String, writer: SyncWriter, _ db: Database) throws {
        let dependents = try String.fetchAll(
            db, sql: "SELECT blocked_id FROM decision_dependency WHERE blocker_id = ?", arguments: [id])
        try db.execute(
            sql: "DELETE FROM decision_dependency WHERE blocked_id = ? OR blocker_id = ?", arguments: [id, id])
        try db.execute(sql: "DELETE FROM board_place WHERE decision_id = ?", arguments: [id])
        for var item in try ChecklistItem.filter(Column("decision_id") == id && Column("deleted_at") == nil).fetchAll(
            db)
        {
            item.text = ""
            try writer.tombstone(&item, db)
        }
        try recomputeBlocked(dependents, dependenciesRemoved: true, writer: writer, db)
    }

    /// After an edit: an open entry has no outcome; one no longer waiting waits for nobody; a memory entry has no
    /// work fields.
    static func tidyWork(_ decision: inout Decision, kindBefore: Decision.Kind) {
        if decision.status.isOpen {
            decision.outcome = nil
            decision.outcomeKind = nil
        }
        if decision.status != .waiting {
            decision.waitingOnId = nil
            decision.waitingUntil = nil
        }
        if !decision.kind.isWork {
            if decision.status == .inProgress || decision.status == .waiting || decision.status == .blocked {
                decision.status = .active
            }
            if kindBefore.isWork {
                decision.ownerId = nil
                decision.dueAt = nil
                decision.priority = nil
                decision.startsAt = nil
                decision.estimate = nil
                decision.recurrence = nil
                decision.severity = nil
                decision.happenedAt = nil
            }
        }
    }

    /// Keeps `closedAt` in step with the state.
    static func stampClosed(_ decision: inout Decision, now: Date) {
        let closed =
            !decision.status.isOpen && decision.kind.isWork
            || decision.status == .superseded || decision.status == .cancelled
        if closed, decision.closedAt == nil { decision.closedAt = now }
        if !closed { decision.closedAt = nil }
    }

    /// A repeating entry just done: the next one, with the due date moved on and the checklist unticked. Only once per
    /// entry (done, reopened and done again does not make a second copy), and not when it was closed as rejected,
    /// irrelevant or turned into something else.
    @discardableResult
    static func repeatIfNeeded(_ done: Decision, writer: SyncWriter, _ db: Database) throws -> Decision? {
        guard let recurrence = done.recurrence, done.status == .done else { return nil }
        if let outcome = done.outcomeKind, outcome == .rejected || outcome == .irrelevant || outcome == .converted {
            return nil
        }
        let spawned =
            try Int.fetchOne(
                db,
                sql: "SELECT count(*) FROM decision WHERE derived_from_id = ? AND recurrence IS NOT NULL",
                arguments: [done.id]) ?? 0
        guard spawned == 0 else { return nil }
        let base = done.dueAt ?? writer.now
        let calendar = Calendar(identifier: .gregorian)
        let component: Calendar.Component =
            switch recurrence {
            case .daily: .day
            case .weekly: .weekOfYear
            case .monthly: .month
            case .yearly: .year
            }
        guard let nextDue = calendar.date(byAdding: component, value: 1, to: base) else { return nil }
        var next = done
        next.id = newID(at: writer.now)
        next.status = .active
        next.decidedAt = writer.now
        next.dueAt = nextDue
        next.startsAt = done.startsAt.flatMap { calendar.date(byAdding: component, value: 1, to: $0) }
        next.closedAt = nil
        next.outcome = nil
        next.outcomeKind = nil
        next.waitingOnId = nil
        next.waitingUntil = nil
        next.happenedAt = nil
        next.supersedesId = nil
        next.chainName = nil
        next.derivedFromId = done.id
        next.createdAt = .distantPast
        next.version = 0
        try writer.save(&next, db)
        for table in ["decision_entity", "decision_tag", "decision_stream"] {
            let column = table == "decision_entity" ? "entity_id" : table == "decision_tag" ? "tag_id" : "stream_id"
            try db.execute(
                sql:
                    "INSERT INTO \(table) (decision_id, \(column)) SELECT ?, \(column) FROM \(table) WHERE decision_id = ?",
                arguments: [next.id, done.id])
        }
        for item in try ChecklistItem.filter(Column("decision_id") == done.id && Column("deleted_at") == nil)
            .order(Column("sort_order")).fetchAll(db)
        {
            var copy = item
            copy.id = newID(at: writer.now)
            copy.decisionId = next.id
            copy.done = false
            copy.createdAt = .distantPast
            copy.version = 0
            try writer.save(&copy, db)
        }
        return next
    }
}
