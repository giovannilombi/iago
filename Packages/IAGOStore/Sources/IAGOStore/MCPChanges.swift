import Foundation
import GRDB

/// One write made by the user through Claude (ADR-0044): what was created or changed, and the values before a
/// change, so it can be undone from IAGO.
public struct MCPChange: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable, Identifiable {
    /// `summary` and `suggestion` (ADR-0071): `entityId` is the item's.
    public enum Entity: String, Codable, Sendable { case note, decision, item, summary, suggestion }
    public enum Action: String, Codable, Sendable { case create, update }

    public static let databaseTableName = "mcp_change"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: Int64?
    public var at: Date
    public var entity: Entity
    public var entityId: String
    public var action: Action
    /// JSON of the values before an update.
    public var previous: String?
    public var undoneAt: Date?
}

/// Values of a note or decision before Claude changed them.
public struct MCPPrevious: Codable, Sendable, Equatable {
    public var body: String?
    public var text: String?
    public var notes: String?
    public var status: Decision.Status?
    public var chainName: String?
    /// Streams of the decision before (ADR-0047).
    public var streamIDs: [String]?
    /// Links and states of the chains touched by a change of "supersedes" (ADR-0047).
    public var chain: [ChainLink]?
    /// The summary Claude replaced (ADR-0071).
    public var summary: ItemSummaryText?
    /// The proposals Claude added (ADR-0071).
    public var suggestionIDs: [String]?
    /// ADR-0074: the open work fields before the change; what the entry depended on and its checklist, when the
    /// change replaced them.
    public var work: Work?
    public var blockerIDs: [String]?
    public var checklist: [ChecklistLine]?

    /// Kind and open work fields of a decision (ADR-0074).
    public struct Work: Codable, Sendable, Equatable {
        public var kind: Decision.Kind
        public var ownerId: String?
        public var dueAt: Date?
        public var waitingOnId: String?
        public var waitingUntil: Date?
        public var priority: Int?
        public var startsAt: Date?
        public var estimate: String?
        public var severity: Decision.Severity?
        public var happenedAt: Date?
        public var outcome: String?
        public var outcomeKind: Decision.Outcome?
        public var derivedFromId: String?
        public var recurrence: Decision.Recurrence?

        public init(_ decision: Decision) {
            kind = decision.kind
            ownerId = decision.ownerId
            dueAt = decision.dueAt
            waitingOnId = decision.waitingOnId
            waitingUntil = decision.waitingUntil
            priority = decision.priority
            startsAt = decision.startsAt
            estimate = decision.estimate
            severity = decision.severity
            happenedAt = decision.happenedAt
            outcome = decision.outcome
            outcomeKind = decision.outcomeKind
            derivedFromId = decision.derivedFromId
            recurrence = decision.recurrence
        }

        public func apply(to decision: inout Decision) {
            decision.kind = kind
            decision.ownerId = ownerId
            decision.dueAt = dueAt
            decision.waitingOnId = waitingOnId
            decision.waitingUntil = waitingUntil
            decision.priority = priority
            decision.startsAt = startsAt
            decision.estimate = estimate
            decision.severity = severity
            decision.happenedAt = happenedAt
            decision.outcome = outcome
            decision.outcomeKind = outcomeKind
            decision.derivedFromId = derivedFromId
            decision.recurrence = recurrence
        }
    }

    /// One line of an activity's checklist.
    public struct ChecklistLine: Codable, Sendable, Equatable {
        public var text: String
        public var done: Bool

        public init(text: String, done: Bool) {
            self.text = text
            self.done = done
        }
    }

    public struct ChainLink: Codable, Sendable, Equatable {
        public var id: String
        /// Before ADR-0052: the single entry superseded.
        public var supersedesId: String?
        public var status: Decision.Status
        /// ADR-0052: every entry superseded.
        public var supersedes: [String]?

        public init(id: String, supersedesId: String?, status: Decision.Status, supersedes: [String]? = nil) {
            self.id = id
            self.supersedesId = supersedesId
            self.status = status
            self.supersedes = supersedes
        }
    }

    public init(
        body: String? = nil, text: String? = nil, notes: String? = nil, status: Decision.Status? = nil,
        chainName: String? = nil, streamIDs: [String]? = nil, chain: [ChainLink]? = nil,
        summary: ItemSummaryText? = nil, suggestionIDs: [String]? = nil, work: Work? = nil,
        blockerIDs: [String]? = nil, checklist: [ChecklistLine]? = nil
    ) {
        self.work = work
        self.blockerIDs = blockerIDs
        self.checklist = checklist
        self.summary = summary
        self.suggestionIDs = suggestionIDs
        self.body = body
        self.text = text
        self.notes = notes
        self.status = status
        self.chainName = chainName
        self.streamIDs = streamIDs
        self.chain = chain
    }
}

public enum MCPChangeError: Error, Equatable {
    case alreadyUndone
    /// What Claude wrote has been changed or replaced since (a summary rewritten): undoing would lose that work.
    case changedSince
}

extension Archive {
    @discardableResult
    public func recordMCPChange(
        _ entity: MCPChange.Entity, id: String, action: MCPChange.Action, previous: MCPPrevious? = nil
    ) throws -> MCPChange {
        var change = MCPChange(
            at: now(), entity: entity, entityId: id, action: action,
            previous: try previous.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) })
        try database.writer.write { db in try change.insert(db) }
        change.id = try database.writer.read { db in try Int64.fetchOne(db, sql: "SELECT MAX(id) FROM mcp_change") }
        return change
    }

    /// Most recent first.
    public func mcpChanges(limit: Int = 100) throws -> [MCPChange] {
        try database.writer.read { db in
            try MCPChange.order(Column("id").desc).limit(limit).fetchAll(db)
        }
    }

    /// How each of these objects came through Claude: created there, or changed later. Undone writes don't count.
    public func mcpProvenance(_ entity: MCPChange.Entity, ids: [String]) throws -> [String: MCPChange.Action] {
        guard !ids.isEmpty else { return [:] }
        return try database.writer.read { db in
            var result: [String: MCPChange.Action] = [:]
            for change in try MCPChange.filter(Column("entity") == entity.rawValue)
                .filter(ids.contains(Column("entity_id"))).filter(Column("undone_at") == nil)
                .order(Column("id")).fetchAll(db)
            where result[change.entityId] != .create {
                result[change.entityId] = change.action
            }
            return result
        }
    }

    /// Undoes one write: a creation is removed (items go to the trash), a change goes back to the values before.
    public func undoMCPChange(_ id: Int64) throws {
        guard
            let change = try database.writer.read({ db in try MCPChange.fetchOne(db, key: id) })
        else { throw ArchiveError.notFound("\(id)") }
        guard change.undoneAt == nil else { throw MCPChangeError.alreadyUndone }
        let previous = try change.previous.map { try JSONDecoder().decode(MCPPrevious.self, from: Data($0.utf8)) }
        switch (change.entity, change.action) {
        case (.note, .create): try deleteNote(change.entityId)
        case (.decision, .create): try deleteDecision(change.entityId)
        case (.item, .create): try trashItem(change.entityId)
        case (.note, .update):
            if let body = previous?.body { try updateNote(change.entityId) { $0.body = body } }
        case (.decision, .update):
            if let previous {
                if let chain = previous.chain { try restoreDecisionLinks(chain) }
                try updateDecision(change.entityId, streams: previous.streamIDs) { decision in
                    if let text = previous.text { decision.text = text }
                    decision.notes = previous.notes
                    if let status = previous.status, decision.status != .superseded { decision.status = status }
                    previous.work?.apply(to: &decision)
                }
                try setChainName(previous.chainName, decisionID: change.entityId)
                if let blockers = previous.blockerIDs { try setBlockers(blockers, of: change.entityId) }
                if let lines = previous.checklist { try replaceChecklist(lines, decisionID: change.entityId) }
            }
        case (.item, .update): break
        case (.summary, .create), (.summary, .update):
            // Only Claude's summary as written is undone; one rewritten since (by Claude, the engine or by hand) stays.
            let current = try summary(itemID: change.entityId)
            guard current?.origin == .claude, current?.markdown == previous?.body else {
                throw MCPChangeError.changedSince
            }
            if change.action == .create {
                try deleteSummary(itemID: change.entityId)
            } else if let summary = previous?.summary {
                try restoreSummary(summary)
            }
        case (.suggestion, _): try deletePendingSuggestions(previous?.suggestionIDs ?? [])
        }
        let now = self.now()
        try database.writer.write { db in
            try db.execute(sql: "UPDATE mcp_change SET undone_at = ? WHERE id = ?", arguments: [now, id])
        }
    }
}
