import Foundation
import GRDB
import IAGOCore

/// One search result: a passage of a transcript, a note or a document (FR-71, ADR-0036).
public struct SearchHit: Sendable, Hashable, Identifiable {
    public enum Source: String, Sendable, CaseIterable { case transcript, note, document, decision, summary }

    public var itemID: String?
    public var projectID: String?
    public var source: Source
    public var sourceID: String
    /// Position in the audio for transcript passages.
    public var atSec: Double?
    /// Excerpt with matches wrapped in `«` and `»`.
    public var snippet: String
    /// Found by meaning (ADR-0049) and not by its words.
    public var byMeaning = false

    public var id: String { "\(source.rawValue)/\(sourceID)/\(atSec ?? -1)" }

    public init(
        itemID: String?, projectID: String?, source: Source, sourceID: String, atSec: Double?, snippet: String,
        byMeaning: Bool = false
    ) {
        self.itemID = itemID
        self.projectID = projectID
        self.source = source
        self.sourceID = sourceID
        self.atSec = atSec
        self.snippet = snippet
        self.byMeaning = byMeaning
    }
}

/// Where a search looks (ADR-0038).
public enum SearchScope: Sendable, Hashable {
    case all
    case client(String)
    case project(String)
    case stream(String)
}

/// Full-text index (FTS5, accents and case ignored). Texts are indexed in clear inside the database, which
/// is excluded from Time Machine (spec 9.3); crypto-shredding removes the rows with the item.
extension Archive {
    /// Replaces the transcript passages of an item: one row per segment, with its start time.
    public func indexTranscript(_ transcript: Transcript, itemID: String) throws {
        let projectID = try item(itemID)?.projectId
        let speakers = Dictionary(uniqueKeysWithValues: transcript.speakers.map { ($0.id, $0.label) })
        try database.writer.write { db in
            try db.execute(
                sql: "DELETE FROM search_index WHERE item_id = ? AND source = 'transcript'", arguments: [itemID])
            for segment in transcript.segments {
                try db.execute(
                    sql:
                        "INSERT INTO search_index (item_id, project_id, source, source_id, at_sec, text) VALUES (?, ?, 'transcript', ?, ?, ?)",
                    arguments: [
                        itemID, projectID, "\(itemID)#\(segment.id)", segment.start,
                        "\(speakers[segment.speaker] ?? ""): \(segment.text)",
                    ])
            }
            // The text of the screenshots is part of the call (ADR-0072).
            for shot in try Asset.filter(
                Column("item_id") == itemID && Column("kind") == Asset.Kind.screenshot.rawValue
                    && Column("deleted_at") == nil
            ).fetchAll(db) {
                try Self.indexScreenshot(shot, projectID: projectID, db)
            }
        }
    }

    /// Indexes the Markdown of a document by paragraph.
    public func indexDocument(_ markdown: String, itemID: String) throws {
        let projectID = try item(itemID)?.projectId
        let paragraphs = markdown.components(separatedBy: "\n\n").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        try database.writer.write { db in
            try db.execute(
                sql: "DELETE FROM search_index WHERE item_id = ? AND source = 'document'", arguments: [itemID])
            for (index, paragraph) in paragraphs.enumerated() {
                try db.execute(
                    sql:
                        "INSERT INTO search_index (item_id, project_id, source, source_id, text) VALUES (?, ?, 'document', ?, ?)",
                    arguments: [itemID, projectID, "\(itemID)#\(index)", paragraph])
            }
        }
    }

    func indexNote(_ note: Note, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM search_index WHERE source = 'note' AND source_id = ?", arguments: [note.id])
        guard note.deletedAt == nil, !note.body.isEmpty else { return }
        let projectID =
            try note.projectId
            ?? note.itemId.flatMap {
                try String.fetchOne(db, sql: "SELECT project_id FROM item WHERE id = ?", arguments: [$0])
            }
        try db.execute(
            sql: "INSERT INTO search_index (item_id, project_id, source, source_id, text) VALUES (?, ?, 'note', ?, ?)",
            arguments: [note.itemId, projectID, note.id, note.body])
    }

    func removeFromIndex(itemID: String, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM search_index WHERE item_id = ?", arguments: [itemID])
    }

    /// Keeps the project column of an item's rows in sync after it moves to another project.
    func reindexProject(of itemID: String, projectID: String?, _ db: Database) throws {
        try db.execute(sql: "UPDATE search_index SET project_id = ? WHERE item_id = ?", arguments: [projectID, itemID])
    }

    /// Passages matching `text` (every word, prefix match), best first. Items in the trash or deleted are
    /// left out.
    public func search(
        _ text: String, scope: SearchScope = .all, sources: Set<SearchHit.Source> = [], limit: Int = 200
    ) throws -> [SearchHit] {
        guard let pattern = Self.ftsPattern(text) else { return [] }
        return try database.writer.read { db in
            var sql = """
                SELECT search_index.item_id, search_index.project_id, search_index.source, search_index.source_id, search_index.at_sec,
                       snippet(search_index, 5, '«', '»', '…', 14) AS snippet
                FROM search_index
                LEFT JOIN item ON item.id = search_index.item_id
                WHERE search_index MATCH ?
                  AND (search_index.item_id IS NULL OR (item.deleted_at IS NULL AND item.trashed_at IS NULL))
                """
            var arguments: StatementArguments = [pattern]
            switch scope {
            case .all: break
            case .project(let id):
                sql += " AND search_index.project_id = ?"
                arguments += [id]
            case .client(let id):
                sql +=
                    " AND search_index.project_id IN (SELECT id FROM project WHERE client_id = ? AND deleted_at IS NULL)"
                arguments += [id]
            case .stream(let id):
                sql += """
                     AND (search_index.item_id IN (SELECT item_id FROM item_stream WHERE stream_id = ?)
                       OR (search_index.source = 'decision'
                           AND search_index.source_id IN (SELECT decision_id FROM decision_stream WHERE stream_id = ?))
                       OR (search_index.source = 'note'
                           AND search_index.source_id IN (SELECT note_id FROM note_stream WHERE stream_id = ?)))
                    """
                arguments += [id, id, id]
            }
            if !sources.isEmpty {
                sql += " AND search_index.source IN (\(sources.map { _ in "?" }.joined(separator: ",")))"
                for source in sources.map(\.rawValue).sorted() { arguments += [source] }
            }
            sql += " ORDER BY rank LIMIT ?"
            arguments += [limit]
            return try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
                SearchHit(
                    itemID: row["item_id"], projectID: row["project_id"],
                    source: SearchHit.Source(rawValue: row["source"]) ?? .note, sourceID: row["source_id"],
                    atSec: row["at_sec"], snippet: row["snippet"])
            }
        }
    }

    /// User text → FTS5 query: each word quoted (no syntax injection) and prefix-matched.
    static func ftsPattern(_ text: String) -> String? {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard !words.isEmpty else { return nil }
        return words.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    /// Rebuilds the index from the archive (first launch after the update, or on demand): decrypts
    /// every transcript and document Markdown. Returns the number of items indexed.
    @discardableResult
    public func rebuildSearchIndex() throws -> Int {
        try database.writer.write { db in try db.execute(sql: "DELETE FROM search_index") }
        var count = 0
        for item in try items() + trashedItems() {
            let assets = try assets(itemID: item.id)
            if let json = assets.first(where: { $0.kind == .transcriptJSON }),
                let transcript = try? Transcript.decode(from: readAssetData(json))
            {
                try indexTranscript(transcript, itemID: item.id)
                count += 1
            }
            if let md = assets.first(where: { $0.kind == .contentMD }), let data = try? readAssetData(md) {
                try indexDocument(String(decoding: data, as: UTF8.self), itemID: item.id)
                count += 1
            }
        }
        try database.writer.write { db in
            for note in try Note.filter(Column("deleted_at") == nil).fetchAll(db) { try indexNote(note, db) }
            for decision in try Decision.filter(Column("deleted_at") == nil).fetchAll(db) {
                try indexDecision(decision, db)
            }
        }
        return count
    }
}
