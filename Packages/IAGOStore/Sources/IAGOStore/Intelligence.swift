import Foundation
import GRDB

/// A piece of an item or note for the search by meaning (ADR-0049, spec 10.1): its text, where it is, and its vector
/// computed by `model`. Derived data: rebuilt when the text or the model changes, never synced.
public struct Chunk: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable, Identifiable {
    public enum Source: String, Codable, Sendable { case transcript, email, document, note }

    public static let databaseTableName = "chunk"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    /// The item it belongs to; for a note on an item, that item too.
    public var itemId: String?
    public var noteId: String?
    public var source: Source
    public var startSec: Double?
    public var endSec: Double?
    /// Names of who speaks in it, comma separated.
    public var speakers: String?
    public var text: String
    public var model: String
    /// `float32` values, L2-normalised.
    public var vector: Data
    public var createdAt: Date

    public init(
        id: String, itemId: String?, noteId: String?, source: Source, startSec: Double? = nil, endSec: Double? = nil,
        speakers: String? = nil, text: String, model: String, vector: [Float], createdAt: Date = Date()
    ) {
        self.id = id
        self.itemId = itemId
        self.noteId = noteId
        self.source = source
        self.startSec = startSec
        self.endSec = endSec
        self.speakers = speakers
        self.text = text
        self.model = model
        self.vector = vector.withUnsafeBufferPointer { Data(buffer: $0) }
        self.createdAt = createdAt
    }

    public var values: [Float] {
        vector.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}

/// A proposal of the local engine waiting for the user (ADR-0049, FR-111): never applied without confirmation.
public struct Suggestion: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable, Identifiable {
    /// ADR-0074 adds the open work kinds: a point to clear up, a risk, a request of the client.
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case decision, activity, person, tag, project, link, question, risk, request
    }
    public enum Status: String, Codable, Sendable { case pending, accepted, rejected, merged }

    public static let databaseTableName = "suggestion"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var itemId: String
    public var kind: Kind
    /// JSON of `SuggestionPayload`.
    public var payload: String
    public var status: Status
    /// Kind and normalised text: a proposal the user already answered is not proposed again for the same item.
    public var fingerprint: String
    /// Catalog id of the model that proposed it, or for Claude the app it was used from.
    public var model: String
    public var createdAt: Date
    public var updatedAt: Date
    /// The local engine or Claude (ADR-0070).
    public var origin: ResultOrigin = .engine

    public var content: SuggestionPayload {
        (try? JSONDecoder().decode(SuggestionPayload.self, from: Data(payload.utf8))) ?? SuggestionPayload(text: "")
    }
}

/// What a suggestion proposes; which fields count depends on the kind.
public struct SuggestionPayload: Codable, Sendable, Hashable {
    /// Decision or activity title, person name, tag, project name, or title of the item to link.
    public var text: String
    /// The verbatim passage it comes from, checked against the text.
    public var quote: String?
    public var atSec: Double?
    /// Who does it (activity).
    public var owner: String?
    /// "high" or "medium".
    public var confidence: String?
    /// Decision it may supersede (decision).
    public var supersedesID: String?
    /// Existing person, tag or project to use, or the item to link.
    public var targetID: String?
    /// Why it is proposed (project, link).
    public var reason: String?
    /// A tag that does not exist yet.
    public var isNew: Bool?
    /// ADR-0074: due date ("yyyy-MM-dd"), who it waits for, and a risk's severity ("high", "medium", "low").
    public var due: String?
    public var waitingOn: String?
    public var severity: String?

    public init(
        text: String, quote: String? = nil, atSec: Double? = nil, owner: String? = nil, confidence: String? = nil,
        supersedesID: String? = nil, targetID: String? = nil, reason: String? = nil, isNew: Bool? = nil,
        due: String? = nil, waitingOn: String? = nil, severity: String? = nil
    ) {
        self.text = text
        self.quote = quote
        self.atSec = atSec
        self.owner = owner
        self.confidence = confidence
        self.supersedesID = supersedesID
        self.targetID = targetID
        self.reason = reason
        self.isNew = isNew
        self.due = due
        self.waitingOn = waitingOn
        self.severity = severity
    }

    /// `due` as a date, at noon so the day does not change with the time zone.
    public var dueDate: Date? {
        guard let due else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: due + " 12:00")
    }
}

extension Archive {
    // MARK: Chunks

    /// Replaces the chunks of an item (`noteID` nil) or of a note.
    public func replaceChunks(itemID: String?, noteID: String?, with chunks: [Chunk]) throws {
        let now = self.now()
        try database.writer.write { db in
            if let noteID {
                try db.execute(sql: "DELETE FROM chunk WHERE note_id = ?", arguments: [noteID])
            } else if let itemID {
                try db.execute(sql: "DELETE FROM chunk WHERE item_id = ? AND note_id IS NULL", arguments: [itemID])
            }
            for var chunk in chunks {
                chunk.createdAt = now
                try chunk.insert(db)
            }
        }
    }

    /// Chunks computed by `model` in a scope, without deleted or trashed content.
    public func chunks(_ scope: SearchScope, model: String) throws -> [Chunk] {
        try database.writer.read { db in
            var sql = """
                SELECT chunk.* FROM chunk
                LEFT JOIN item ON item.id = chunk.item_id
                LEFT JOIN note ON note.id = chunk.note_id
                WHERE chunk.model = ?
                  AND (chunk.item_id IS NULL OR (item.deleted_at IS NULL AND item.trashed_at IS NULL))
                  AND (chunk.note_id IS NULL OR note.deleted_at IS NULL)
                """
            var arguments: StatementArguments = [model]
            let project = "COALESCE(item.project_id, note.project_id)"
            switch scope {
            case .all: break
            case .project(let id):
                sql += " AND \(project) = ?"
                arguments += [id]
            case .client(let id):
                sql += " AND \(project) IN (SELECT id FROM project WHERE client_id = ? AND deleted_at IS NULL)"
                arguments += [id]
            case .stream(let id):
                sql += """
                     AND (chunk.item_id IN (SELECT item_id FROM item_stream WHERE stream_id = ?)
                       OR chunk.note_id IN (SELECT note_id FROM note_stream WHERE stream_id = ?))
                    """
                arguments += [id, id]
            case .projects(let ids):
                sql += " AND \(project) IN (\(SearchScope.placeholders(ids.count)))"
                for id in ids { arguments += [id] }
            }
            return try Chunk.fetchAll(db, sql: sql, arguments: arguments)
        }
    }

    /// Items with text (a transcript, an email or a document) and notes without chunks from `model`, or whose text
    /// changed after them (a new transcription, an edited note).
    public func unindexed(model: String) throws -> (items: [String], notes: [String]) {
        try database.writer.read { db in
            let items = try String.fetchAll(
                db,
                sql: """
                    SELECT item.id FROM item
                    WHERE item.deleted_at IS NULL AND item.trashed_at IS NULL
                      AND EXISTS (SELECT 1 FROM asset WHERE asset.item_id = item.id AND asset.deleted_at IS NULL
                                  AND asset.kind IN ('transcript_json', 'content_md'))
                      AND COALESCE(
                            (SELECT max(chunk.created_at) FROM chunk WHERE chunk.item_id = item.id
                               AND chunk.note_id IS NULL AND chunk.model = ?), '')
                          < (SELECT max(asset.updated_at) FROM asset WHERE asset.item_id = item.id
                               AND asset.deleted_at IS NULL AND asset.kind IN ('transcript_json', 'content_md'))
                      AND COALESCE(
                            (SELECT value FROM setting WHERE key = 'chunk.empty.' || ? || '.' || item.id), '')
                          < (SELECT max(asset.updated_at) FROM asset WHERE asset.item_id = item.id
                               AND asset.deleted_at IS NULL AND asset.kind IN ('transcript_json', 'content_md'))
                    ORDER BY item.occurred_at DESC
                    """, arguments: [model, model])
            let notes = try String.fetchAll(
                db,
                sql: """
                    SELECT note.id FROM note WHERE note.deleted_at IS NULL AND note.body != ''
                      AND COALESCE(
                            (SELECT max(chunk.created_at) FROM chunk WHERE chunk.note_id = note.id AND chunk.model = ?),
                            '') < note.updated_at
                    ORDER BY note.noted_at DESC
                    """, arguments: [model])
            return (items, notes)
        }
    }

    /// An item that gives nothing to index (no text, or it failed): skipped until its text changes, so the indexer
    /// does not try it again at every round (the "Attività" entry flickered).
    public func markNothingToIndex(itemID: String, model: String) throws {
        try database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO setting (key, value)
                    SELECT 'chunk.empty.' || ? || '.' || ?, max(updated_at) FROM asset
                    WHERE item_id = ? AND deleted_at IS NULL AND kind IN ('transcript_json', 'content_md')
                    HAVING max(updated_at) IS NOT NULL
                    """, arguments: [model, itemID, itemID])
        }
    }

    /// Chunks of another model are useless once the model changes.
    public func deleteChunks(notFrom model: String) throws {
        try database.writer.write { db in try db.execute(sql: "DELETE FROM chunk WHERE model != ?", arguments: [model])
        }
    }

    public func chunkCount(model: String) throws -> Int {
        try database.writer.read { db in try Chunk.filter(Column("model") == model).fetchCount(db) }
    }

    func removeIntelligence(itemID: String, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM chunk WHERE item_id = ?", arguments: [itemID])
        try db.execute(sql: "DELETE FROM suggestion WHERE item_id = ?", arguments: [itemID])
    }

    // MARK: Suggestions

    public static func fingerprint(_ kind: Suggestion.Kind, _ text: String) -> String {
        kind.rawValue + ":"
            + text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }

    /// Records new proposals for an item. Pending ones from an earlier run of the same origin go away (the engine
    /// does not remove Claude's, nor the other way round); one the user already accepted or rejected is not proposed
    /// again. Returns what was added.
    @discardableResult
    public func replacePendingSuggestions(
        itemID: String, model: String, origin: ResultOrigin = .engine,
        _ proposals: [(kind: Suggestion.Kind, payload: SuggestionPayload)]
    ) throws -> [Suggestion] {
        let now = self.now()
        let writer = self.writer
        return try database.writer.write { db in
            try db.execute(
                sql: "DELETE FROM suggestion WHERE item_id = ? AND status = 'pending' AND origin = ?",
                arguments: [itemID, origin.rawValue])
            let answered = Set(
                try String.fetchAll(
                    db, sql: "SELECT fingerprint FROM suggestion WHERE item_id = ?", arguments: [itemID]))
            var added: [Suggestion] = []
            var seen = answered
            for proposal in proposals {
                let fingerprint = Self.fingerprint(proposal.kind, proposal.payload.text)
                guard seen.insert(fingerprint).inserted else { continue }
                let payload = String(decoding: try JSONEncoder().encode(proposal.payload), as: UTF8.self)
                let suggestion = Suggestion(
                    id: newID(at: writer.now), itemId: itemID, kind: proposal.kind, payload: payload, status: .pending,
                    fingerprint: fingerprint, model: model, createdAt: now, updatedAt: now, origin: origin)
                try suggestion.insert(db)
                added.append(suggestion)
            }
            return added
        }
    }

    public func suggestions(itemID: String, status: Suggestion.Status? = .pending) throws -> [Suggestion] {
        try database.writer.read { db in
            var request = Suggestion.filter(Column("item_id") == itemID)
            if let status { request = request.filter(Column("status") == status.rawValue) }
            return try request.order(Column("created_at")).fetchAll(db)
        }
    }

    /// Removes proposals still waiting for an answer; confirmed or dismissed ones stay (undo of ADR-0071).
    public func deletePendingSuggestions(_ ids: [String]) throws {
        guard !ids.isEmpty else { return }
        try database.writer.write { db in
            _ = try Suggestion.filter(ids.contains(Column("id"))).filter(Column("status") == "pending").deleteAll(db)
        }
    }

    public func suggestion(_ id: String) throws -> Suggestion? {
        try database.writer.read { db in try Suggestion.fetchOne(db, key: id) }
    }

    /// Pending proposals per item, for the marks in lists and timelines.
    public func pendingSuggestionCounts() throws -> [String: Int] {
        try database.writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT suggestion.item_id, count(*) AS n FROM suggestion
                    JOIN item ON item.id = suggestion.item_id
                    WHERE suggestion.status = 'pending' AND item.deleted_at IS NULL AND item.trashed_at IS NULL
                    GROUP BY suggestion.item_id
                    """)
            return Dictionary(uniqueKeysWithValues: rows.map { ($0["item_id"] as String, $0["n"] as Int) })
        }
    }

    /// Pending key points of a scope ("Da confermare" in Punti chiave): decisions, activities, points to clear up,
    /// risks and requests (ADR-0074), most recent item first.
    public func pendingKeyPointSuggestions(_ scope: DecisionQuery.Scope) throws -> [Suggestion] {
        try database.writer.read { db in
            var sql = """
                SELECT suggestion.* FROM suggestion JOIN item ON item.id = suggestion.item_id
                WHERE suggestion.status = 'pending'
                  AND suggestion.kind IN ('decision', 'activity', 'question', 'risk', 'request')
                  AND item.deleted_at IS NULL AND item.trashed_at IS NULL
                """
            var arguments: StatementArguments = []
            switch scope {
            case .all: break
            case .project(let id):
                sql += " AND item.project_id = ?"
                arguments += [id]
            case .noProject: sql += " AND item.project_id IS NULL"
            case .client(let id):
                sql += " AND item.project_id IN (SELECT id FROM project WHERE client_id = ? AND deleted_at IS NULL)"
                arguments += [id]
            case .stream(let id):
                sql += " AND item.id IN (SELECT item_id FROM item_stream WHERE stream_id = ?)"
                arguments += [id]
            case .projects(let ids):
                sql += " AND item.project_id IN (\(SearchScope.placeholders(ids.count)))"
                for id in ids { arguments += [id] }
            }
            sql += " ORDER BY item.occurred_at DESC, suggestion.created_at"
            return try Suggestion.fetchAll(db, sql: sql, arguments: arguments)
        }
    }

    public func setSuggestionStatus(_ id: String, _ status: Suggestion.Status) throws {
        let now = self.now()
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE suggestion SET status = ?, updated_at = ? WHERE id = ?",
                arguments: [status.rawValue, now, id])
        }
    }
}

// MARK: - Conversations

/// A "Chiedi" conversation (ADR-0049, amended 2026-10-19): temporary for 48 hours unless the user keeps or pins it.
public struct Conversation: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable, Identifiable {
    public static let databaseTableName = "conversation"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    /// "all", "project", "client" or "stream", and its id.
    public var scopeKind: String
    public var scopeId: String?
    /// The first question, shortened.
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    /// Kept by the user: never deleted automatically.
    public var keep: Bool
    public var pinned: Bool
    /// When a temporary conversation goes away.
    public var expiresAt: Date?

    public var scope: SearchScope {
        switch scopeKind {
        case "project": scopeId.map { .project($0) } ?? .all
        case "client": scopeId.map { .client($0) } ?? .all
        case "stream": scopeId.map { .stream($0) } ?? .all
        case "projects": .chosen(scopeId?.split(separator: ",").map(String.init) ?? [])
        default: .all
        }
    }

    static func parts(_ scope: SearchScope) -> (String, String?) {
        switch scope {
        case .all: ("all", nil)
        case .project(let id): ("project", id)
        case .client(let id): ("client", id)
        case .stream(let id): ("stream", id)
        case .projects(let ids): ("projects", ids.joined(separator: ","))
        }
    }
}

/// One question and its answer, with the sources it cited (JSON) and the model that wrote it.
public struct ConversationTurn: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable, Identifiable {
    public static let databaseTableName = "conversation_turn"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var conversationId: String
    public var question: String
    public var answer: String
    public var sources: String
    public var model: String
    public var askedAt: Date
}

extension Archive {
    public static let conversationLifetime: TimeInterval = 48 * 3_600

    /// Starts a conversation with its first turn; it expires in 48 hours.
    @discardableResult
    public func startConversation(
        scope: SearchScope, question: String, answer: String, sources: String, model: String
    ) throws -> Conversation {
        let now = self.now()
        let writer = self.writer
        let (kind, id) = Conversation.parts(scope)
        let title = question.count > 80 ? String(question.prefix(80)) + "…" : question
        var conversation = Conversation(
            id: newID(at: writer.now), scopeKind: kind, scopeId: id, title: title, createdAt: now, updatedAt: now,
            keep: false, pinned: false, expiresAt: now.addingTimeInterval(Self.conversationLifetime))
        try database.writer.write { db in
            try conversation.insert(db)
            try ConversationTurn(
                id: newID(at: writer.now), conversationId: conversation.id, question: question, answer: answer,
                sources: sources, model: model, askedAt: now
            ).insert(db)
        }
        conversation.updatedAt = now
        return conversation
    }

    /// Adds a turn; a temporary conversation lives 48 hours from its last question.
    public func addTurn(
        to conversationID: String, question: String, answer: String, sources: String, model: String
    ) throws {
        let now = self.now()
        let writer = self.writer
        try database.writer.write { db in
            guard var conversation = try Conversation.fetchOne(db, key: conversationID) else {
                throw ArchiveError.notFound(conversationID)
            }
            try ConversationTurn(
                id: newID(at: writer.now), conversationId: conversationID, question: question, answer: answer,
                sources: sources, model: model, askedAt: now
            ).insert(db)
            conversation.updatedAt = now
            if !conversation.keep { conversation.expiresAt = now.addingTimeInterval(Self.conversationLifetime) }
            try conversation.update(db)
        }
    }

    /// Pinned first, then the most recent.
    public func conversations() throws -> [Conversation] {
        try database.writer.read { db in
            try Conversation.order(Column("pinned").desc, Column("updated_at").desc).fetchAll(db)
        }
    }

    public func conversationTurns(_ conversationID: String) throws -> [ConversationTurn] {
        try database.writer.read { db in
            try ConversationTurn.filter(Column("conversation_id") == conversationID).order(Column("asked_at"))
                .fetchAll(db)
        }
    }

    /// "Conserva": kept until deleted. Pinning keeps it too.
    public func setConversationKept(_ id: String, keep: Bool, pinned: Bool? = nil) throws {
        let now = self.now()
        try database.writer.write { db in
            guard var conversation = try Conversation.fetchOne(db, key: id) else { throw ArchiveError.notFound(id) }
            if let pinned { conversation.pinned = pinned }
            conversation.keep = keep || conversation.pinned
            conversation.expiresAt = conversation.keep ? nil : now.addingTimeInterval(Self.conversationLifetime)
            try conversation.update(db)
        }
    }

    public func deleteConversation(_ id: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM conversation_turn WHERE conversation_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM conversation WHERE id = ?", arguments: [id])
        }
    }

    /// Temporary conversations past their 48 hours go away. Returns how many.
    @discardableResult
    public func purgeExpiredConversations() throws -> Int {
        let now = self.now()
        return try database.writer.write { db in
            let ids = try String.fetchAll(
                db, sql: "SELECT id FROM conversation WHERE keep = 0 AND expires_at <= ?", arguments: [now])
            for id in ids {
                try db.execute(sql: "DELETE FROM conversation_turn WHERE conversation_id = ?", arguments: [id])
                try db.execute(sql: "DELETE FROM conversation WHERE id = ?", arguments: [id])
            }
            return ids.count
        }
    }

    /// Items, notes and decisions of a scope added or changed after `date`: "Nuovo materiale aggiunto".
    public func changedSince(_ date: Date, scope: SearchScope) throws -> (items: [String], notes: Int, decisions: Int) {
        try database.writer.read { db in
            var itemFilter = "item.deleted_at IS NULL AND item.trashed_at IS NULL AND item.updated_at > ?"
            var arguments: StatementArguments = [date]
            var noteFilter = "note.deleted_at IS NULL AND note.updated_at > ?"
            var noteArguments: StatementArguments = [date]
            var decisionFilter = "decision.deleted_at IS NULL AND decision.updated_at > ?"
            var decisionArguments: StatementArguments = [date]
            switch scope {
            case .all: break
            case .project(let id):
                itemFilter += " AND item.project_id = ?"
                arguments += [id]
                noteFilter +=
                    " AND (note.project_id = ? OR note.item_id IN (SELECT id FROM item WHERE project_id = ?))"
                noteArguments += [id, id]
                decisionFilter += " AND decision.project_id = ?"
                decisionArguments += [id]
            case .client(let id):
                let projects = "(SELECT id FROM project WHERE client_id = ? AND deleted_at IS NULL)"
                itemFilter += " AND item.project_id IN \(projects)"
                arguments += [id]
                noteFilter +=
                    " AND (note.project_id IN \(projects) OR note.item_id IN (SELECT id FROM item WHERE project_id IN \(projects)))"
                noteArguments += [id, id]
                decisionFilter += " AND decision.project_id IN \(projects)"
                decisionArguments += [id]
            case .stream(let id):
                itemFilter += " AND item.id IN (SELECT item_id FROM item_stream WHERE stream_id = ?)"
                arguments += [id]
                noteFilter += " AND note.id IN (SELECT note_id FROM note_stream WHERE stream_id = ?)"
                noteArguments += [id]
                decisionFilter += " AND decision.id IN (SELECT decision_id FROM decision_stream WHERE stream_id = ?)"
                decisionArguments += [id]
            case .projects(let ids):
                let list = "(\(SearchScope.placeholders(ids.count)))"
                itemFilter += " AND item.project_id IN \(list)"
                noteFilter +=
                    " AND (note.project_id IN \(list) OR note.item_id IN (SELECT id FROM item WHERE project_id IN \(list)))"
                decisionFilter += " AND decision.project_id IN \(list)"
                for id in ids {
                    arguments += [id]
                    decisionArguments += [id]
                }
                for id in ids + ids { noteArguments += [id] }
            }
            let items = try String.fetchAll(db, sql: "SELECT id FROM item WHERE \(itemFilter)", arguments: arguments)
            let notes =
                try Int.fetchOne(db, sql: "SELECT count(*) FROM note WHERE \(noteFilter)", arguments: noteArguments)
                ?? 0
            let decisions =
                try Int.fetchOne(
                    db, sql: "SELECT count(*) FROM decision WHERE \(decisionFilter)", arguments: decisionArguments) ?? 0
            return (items, notes, decisions)
        }
    }
}
