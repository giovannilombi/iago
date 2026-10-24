import Foundation
import GRDB

/// One write made by the user through Claude (ADR-0044): what was created or changed, and the values before a
/// change, so it can be undone from IAGO.
public struct MCPChange: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable, Identifiable {
    public enum Entity: String, Codable, Sendable { case note, decision, item }
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
        chainName: String? = nil, streamIDs: [String]? = nil, chain: [ChainLink]? = nil
    ) {
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
                }
                try setChainName(previous.chainName, decisionID: change.entityId)
            }
        case (.item, .update): break
        }
        let now = self.now()
        try database.writer.write { db in
            try db.execute(sql: "UPDATE mcp_change SET undone_at = ? WHERE id = ?", arguments: [now, id])
        }
    }
}
