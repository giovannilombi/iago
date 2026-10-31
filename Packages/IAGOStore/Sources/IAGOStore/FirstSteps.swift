import Foundation
import GRDB

/// «Primi passi» of the introduction: what the user has already done once, read from the archive, so each step
/// ticks itself when it happens for real. The example projects (`ExampleArchive`) do not count.
public struct FirstSteps: Sendable, Equatable {
    public var recorded = false
    public var imported = false
    public var namedSpeaker = false
    public var filed = false
    public var confirmedProposal = false
    public var asked = false

    public init() {}

    /// The steps the introduction counts (Claude is optional and not among them).
    public var done: Int { [recorded, imported, namedSpeaker, filed, confirmedProposal, asked].filter { $0 }.count }
    public static let total = 6
    public var isComplete: Bool { done == Self.total }
}

extension Archive {
    public func firstSteps() throws -> FirstSteps {
        try database.writer.read { db in
            func exists(_ sql: String) throws -> Bool { try Bool.fetchOne(db, sql: "SELECT EXISTS(\(sql))") ?? false }
            var steps = FirstSteps()
            let mine = "deleted_at IS NULL AND (capture_meta IS NULL OR capture_meta != '\(ExampleArchive.marker)')"
            steps.recorded = try exists("SELECT 1 FROM item WHERE source = 'recording' AND \(mine)")
            steps.imported = try exists("SELECT 1 FROM item WHERE type IN ('email', 'document') AND \(mine)")
            steps.namedSpeaker = try String.fetchAll(
                db,
                sql: "SELECT DISTINCT label FROM item_speaker WHERE item_id IN (SELECT id FROM item WHERE \(mine))"
            ).contains(where: Self.isVoiceName)
            steps.filed = try exists("SELECT 1 FROM item WHERE project_id IS NOT NULL AND \(mine)")
            steps.confirmedProposal = try exists(
                "SELECT 1 FROM suggestion WHERE status = 'accepted' AND item_id IN (SELECT id FROM item WHERE \(mine))")
            steps.asked = try exists("SELECT 1 FROM conversation")
            return steps
        }
    }
}
