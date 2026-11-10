import Foundation
import GRDB

/// Where a decision came from, as the UI shows it (FR-156: a deleted source is signalled, not hidden).
public enum DecisionSourceState: Sendable, Hashable {
    case none
    case available
    case trashed
    case deleted
}

/// A decision with what the register shows next to it.
public struct DecisionSummary: Sendable, Hashable, Identifiable {
    public var decision: Decision
    public var people: [String]
    public var tags: [String]
    public var projectName: String?
    /// Title of the source item (empty once the item is deleted for good).
    public var sourceTitle: String?
    public var sourceState: DecisionSourceState
    /// The most recent decision this one replaced, and the most recent that replaced it (FR-151).
    public var supersedes: Decision?
    public var supersededBy: Decision?
    /// ADR-0052: every entry this one supersedes, and every entry that supersedes it, most recent first.
    public var supersedesAll: [Decision] = []
    public var supersededByAll: [Decision] = []
    public var streamIDs: [String] = []
    /// Name the user gave to the chain this decision belongs to, if any.
    public var chainName: String?
    /// ADR-0074: owner and who it waits for, by name; what it depends on; its checklist (done, total).
    public var ownerName: String?
    public var waitingOnName: String?
    public var blockers: [Decision] = []
    public var checklist: (done: Int, total: Int) = (0, 0)
    /// The entry it was born from.
    public var derivedFrom: Decision?

    public var id: String { decision.id }

    public static func == (a: DecisionSummary, b: DecisionSummary) -> Bool {
        a.decision == b.decision && a.people == b.people && a.tags == b.tags && a.projectName == b.projectName
            && a.sourceTitle == b.sourceTitle && a.sourceState == b.sourceState && a.supersedesAll == b.supersedesAll
            && a.supersededByAll == b.supersededByAll && a.streamIDs == b.streamIDs && a.chainName == b.chainName
            && a.ownerName == b.ownerName && a.waitingOnName == b.waitingOnName && a.blockers == b.blockers
            && a.checklist == b.checklist && a.derivedFrom == b.derivedFrom
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(decision) }
}

/// What the "Decisioni" view lists (FR-153).
public struct DecisionQuery: Sendable, Hashable {
    public enum Scope: Sendable, Hashable {
        case all
        case project(String)
        case noProject
        case client(String)
        case stream(String)
        /// Several projects (ADR-0091).
        case projects([String])
    }

    public var scope: Scope
    public var statuses: Set<Decision.Status>
    /// Entity id of a person.
    public var personID: String?
    /// Normalized tag names; every one must be present.
    public var tags: Set<String>
    /// Kinds of key points (ADR-0046, ADR-0074); empty: every kind.
    public var kinds: Set<Decision.Kind>
    /// ADR-0074: only entries of this owner (a person entity).
    public var ownerID: String?

    /// What "attivi" means: valid decisions and milestones, and work still open.
    public static let current: Set<Decision.Status> = [.active, .inProgress, .waiting, .blocked]

    public init(
        scope: Scope = .all, statuses: Set<Decision.Status> = DecisionQuery.current, personID: String? = nil,
        tags: Set<String> = [], kinds: Set<Decision.Kind> = [], ownerID: String? = nil
    ) {
        self.scope = scope
        self.statuses = statuses
        self.personID = personID
        self.tags = tags
        self.kinds = kinds
        self.ownerID = ownerID
    }
}

public enum DecisionError: Error, Equatable {
    /// The chosen decision is already a later step of this decision's chain.
    case supersedeCycle
    case emptyText
}

/// Decision register (FR-150…157, ADR-0037).
extension Archive {
    // MARK: Writing

    /// Creates a decision. If it supersedes another, that one becomes `superseded` (FR-151); if it comes from a
    /// bookmark, the bookmark becomes `converted` (FR-152.1).
    @discardableResult
    public func createDecision(
        _ draft: Decision, people: [String] = [], tags: [String] = [], streams: [String] = [], markerID: String? = nil,
        supersedes: [String] = []
    ) throws -> Decision {
        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw DecisionError.emptyText }
        let writer = self.writer
        return try database.writer.write { db in
            var decision = draft
            decision.id = newID(at: writer.now)
            decision.text = text
            if !decision.status.isOpen || !decision.kind.isWork { decision.status = .active }
            Self.stampClosed(&decision, now: writer.now)
            try writer.save(&decision, db)
            try setPeople(people, decisionID: decision.id, writer: writer, db)
            try setDecisionTags(tags, decisionID: decision.id, writer: writer, db)
            try setDecisionStreams(streams, decisionID: decision.id, projectID: decision.projectId, db)
            // ADR-0052: any number of entries, of any kind.
            let targets = Array(Set(supersedes + [draft.supersedesId].compactMap { $0 })).filter { $0 != decision.id }
            if !targets.isEmpty {
                try setOlder(targets, for: &decision, writer: writer, db)
                try recomputeStatus(targets, writer: writer, db)
            }
            if let markerID, var marker = try Marker.fetchOne(db, key: markerID) {
                marker.status = .converted
                try writer.save(&marker, db)
            }
            try indexDecision(decision, db)
            return decision
        }
    }

    /// Edits a decision. `supersedes` replaces what it supersedes (ADR-0052); a closure that changes the old
    /// `supersedesId` means "supersedes only that one". Entries no longer superseded become active again.
    /// Superseding an entry that already comes later (directly or through others) throws `supersedeCycle`, unless
    /// `reorderingChain`: then this entry moves after it, and what superseded this entry supersedes what this entry
    /// superseded.
    @discardableResult
    public func updateDecision(
        _ id: String, people: [String]? = nil, tags: [String]? = nil, streams: [String]? = nil,
        supersedes: [String]? = nil, reorderingChain: Bool = false,
        _ change: @Sendable (inout Decision) throws -> Void = { _ in }
    ) throws -> Decision {
        let writer = self.writer
        return try database.writer.write { db in
            var decision = try Self.require(Decision.fetchOne(db, key: id), id)
            let legacyBefore = decision.supersedesId
            let statusBefore = decision.status
            let kindBefore = decision.kind
            let previous = try olderIDs(of: id, db)
            try change(&decision)
            decision.text = decision.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !decision.text.isEmpty else { throw DecisionError.emptyText }
            var wanted: [String]? = supersedes
            if wanted == nil, decision.supersedesId != legacyBefore {
                wanted = decision.supersedesId.map { [$0] } ?? []
            }
            var touched = Set([id] + previous)
            var chainName: String?
            if let wanted {
                let targets = Array(Set(wanted))
                for target in targets where !previous.contains(target) {
                    guard target != id else { throw DecisionError.supersedeCycle }
                    guard try reaches(target, id, db) else { continue }
                    guard reorderingChain else { throw DecisionError.supersedeCycle }
                    // Take this entry out of its place: what superseded it supersedes what it superseded.
                    chainName = try takeChainName(from: id, writer: writer, db)
                    for newer in try newerIDs(of: id, db) {
                        guard var follower = try Decision.fetchOne(db, key: newer) else { continue }
                        let olders = try olderIDs(of: newer, db).filter { $0 != id } + previous
                        try setOlder(Array(Set(olders)), for: &follower, writer: writer, db)
                        touched.insert(newer)
                    }
                    decision.chainName = nil
                }
                try setOlder(targets, for: &decision, writer: writer, db)
                touched.formUnion(targets)
            }
            Self.tidyWork(&decision, kindBefore: kindBefore)
            Self.stampClosed(&decision, now: writer.now)
            try writer.save(&decision, db)
            if kindBefore.isWork, !decision.kind.isWork {
                // Memory does not depend on anything, nor block anything.
                let dependents = try String.fetchAll(
                    db, sql: "SELECT blocked_id FROM decision_dependency WHERE blocker_id = ?", arguments: [id])
                try db.execute(
                    sql: "DELETE FROM decision_dependency WHERE blocked_id = ? OR blocker_id = ?", arguments: [id, id])
                try Self.recomputeBlocked(dependents, dependenciesRemoved: true, writer: writer, db)
            }
            if let chainName { try giveChainName(chainName, from: id, writer: writer, db) }
            if wanted != nil || decision.status != statusBefore {
                // A cancelled entry no longer supersedes; a reactivated one does again.
                try recomputeStatus(Array(touched.union(try olderIDs(of: id, db))), writer: writer, db)
                try Self.recomputeBlocked([id], writer: writer, db)
                for touchedID in touched { try Self.recomputeDependents(of: touchedID, writer: writer, db) }
            }
            if decision.status == .done, statusBefore != .done,
                let next = try Self.repeatIfNeeded(decision, writer: writer, db)
            {
                try indexDecision(next, db)
            }
            if let people { try setPeople(people, decisionID: id, writer: writer, db) }
            if let tags { try setDecisionTags(tags, decisionID: id, writer: writer, db) }
            if let streams {
                try setDecisionStreams(streams, decisionID: id, projectID: decision.projectId, db)
            } else {
                try dropForeignStreams(decisionID: id, projectID: decision.projectId, db)
            }
            try indexDecision(decision, db)
            return try Decision.fetchOne(db, key: id) ?? decision
        }
    }

    /// "Questa la supera" (ADR-0052): adds one link, keeping the others.
    public func addSupersede(newer: String, older: String) throws {
        let current = try database.writer.read { db in try olderIDs(of: newer, db) }
        guard !current.contains(older) else { return }
        try updateDecision(newer, supersedes: current + [older])
    }

    /// What an entry supersedes, ids only.
    public func supersededIDs(of id: String) throws -> [String] {
        try database.writer.read { db in try olderIDs(of: id, db) }
    }

    /// The links and states of the decisions of these chains, to put them back later (undo, ADR-0047).
    public func decisionLinks(ofChainsOf ids: [String]) throws -> [MCPPrevious.ChainLink] {
        var seen: Set<String> = []
        var links: [MCPPrevious.ChainLink] = []
        for id in ids {
            for decision in try decisionChain(of: id) where seen.insert(decision.id).inserted {
                links.append(
                    .init(
                        id: decision.id, supersedesId: decision.supersedesId, status: decision.status,
                        supersedes: try supersededIDs(of: decision.id)))
            }
        }
        return links
    }

    /// Puts links and states back as they were, without the usual supersede rules.
    public func restoreDecisionLinks(_ links: [MCPPrevious.ChainLink]) throws {
        let writer = self.writer
        try database.writer.write { db in
            for link in links {
                guard var decision = try Decision.fetchOne(db, key: link.id), decision.deletedAt == nil else {
                    continue
                }
                try setOlder(
                    link.supersedes ?? link.supersedesId.map { [$0] } ?? [], for: &decision, writer: writer, db)
                decision.status = link.status
                Self.stampClosed(&decision, now: writer.now)
                try writer.save(&decision, db)
                try Self.recomputeDependents(of: decision.id, writer: writer, db)
            }
        }
    }

    /// "Annulla" / "Riattiva" (FR-150). A superseded decision cannot be reactivated by hand: it follows its chain.
    public func setDecisionStatus(_ id: String, _ status: Decision.Status) throws {
        try updateDecision(id) { $0.status = status }
    }

    /// Deletes a decision for good: text erased, links removed, the decision it replaced becomes active again.
    public func deleteDecision(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            var decision = try Self.require(Decision.fetchOne(db, key: id), id)
            let olders = try olderIDs(of: id, db)
            let newers = try newerIDs(of: id, db)
            decision.text = ""
            decision.notes = nil
            decision.outcome = nil
            decision.estimate = nil
            decision.supersedesId = nil
            try writer.tombstone(&decision, db)
            try db.execute(
                sql: "DELETE FROM decision_supersede WHERE newer_id = ? OR older_id = ?", arguments: [id, id])
            try db.execute(sql: "DELETE FROM decision_entity WHERE decision_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM decision_tag WHERE decision_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM decision_stream WHERE decision_id = ?", arguments: [id])
            try Self.removeWork(decisionID: id, writer: writer, db)
            for newer in newers {
                guard var later = try Decision.fetchOne(db, key: newer) else { continue }
                try setOlder(try olderIDs(of: newer, db), for: &later, writer: writer, db)
            }
            try recomputeStatus(olders, writer: writer, db)
            try indexDecision(decision, db)
        }
    }

    // MARK: Reading

    public func decision(_ id: String) throws -> Decision? {
        try database.writer.read { db in
            try Decision.filter(key: id).filter(Column("deleted_at") == nil).fetchOne(db)
        }
    }

    /// The register, most recent first (FR-153).
    public func decisions(_ query: DecisionQuery = DecisionQuery()) throws -> [DecisionSummary] {
        try database.writer.read { db in
            let kinds = query.kinds.isEmpty ? Set(Decision.Kind.allCases) : query.kinds
            var request = Decision.filter(Column("deleted_at") == nil)
                .filter(kinds.map(\.rawValue).contains(Column("kind")))
                .filter(sql: Self.outsideTrashedProjects("project_id"))
            switch query.scope {
            case .all: break
            case .project(let id): request = request.filter(Column("project_id") == id)
            case .noProject: request = request.filter(Column("project_id") == nil)
            case .client(let id):
                request = request.filter(
                    sql: "project_id IN (SELECT id FROM project WHERE client_id = ? AND deleted_at IS NULL)",
                    arguments: [id])
            case .stream(let id):
                request = request.filter(
                    sql: "id IN (SELECT decision_id FROM decision_stream WHERE stream_id = ?)", arguments: [id])
            case .projects(let ids):
                request = request.filter(ids.contains(Column("project_id")))
            }
            if !query.statuses.isEmpty {
                request = request.filter(query.statuses.map(\.rawValue).contains(Column("status")))
            }
            if let owner = query.ownerID { request = request.filter(Column("owner_id") == owner) }
            let decisions = try request.order(Column("decided_at").desc).fetchAll(db)
            return try decisions.compactMap { decision in
                let summary = try summarize(decision, db)
                if let person = query.personID,
                    try !Bool(
                        Int.fetchOne(
                            db, sql: "SELECT count(*) FROM decision_entity WHERE decision_id = ? AND entity_id = ?",
                            arguments: [decision.id, person]) ?? 0 > 0)
                {
                    return nil
                }
                if !query.tags.isEmpty, !query.tags.isSubset(of: Set(summary.tags.map(TagNormalizer.normalize))) {
                    return nil
                }
                return summary
            }
        }
    }

    /// Decisions taken from an item (for its view and its timeline markers).
    public func decisions(sourceItemID: String) throws -> [DecisionSummary] {
        try database.writer.read { db in
            // Decisions promoted from a note of the item count as decisions of the item too.
            try Decision.filter(Column("deleted_at") == nil)
                .filter(
                    sql: "source_item_id = ? OR source_note_id IN (SELECT id FROM note WHERE item_id = ?)",
                    arguments: [sourceItemID, sourceItemID]
                )
                .order(Column("source_at_sec"), Column("decided_at"))
                .fetchAll(db).map { try summarize($0, db) }
        }
    }

    /// The decision each note became ("Promuovi a decisione"), the most recent when promoted more than once.
    public func promotedDecisions(noteIDs: [String]) throws -> [String: String] {
        guard !noteIDs.isEmpty else { return [:] }
        return try database.writer.read { db in
            var result: [String: String] = [:]
            for decision in try Decision.filter(noteIDs.contains(Column("source_note_id")))
                .filter(Column("deleted_at") == nil).order(Column("created_at")).fetchAll(db)
            {
                if let noteID = decision.sourceNoteId { result[noteID] = decision.id }
            }
            return result
        }
    }

    public func decisionSummary(_ id: String) throws -> DecisionSummary? {
        try database.writer.read { db in
            try Decision.filter(key: id).filter(Column("deleted_at") == nil).fetchOne(db).map { try summarize($0, db) }
        }
    }

    /// True if `candidate` already comes after `id` in its chain: superseding it means reordering the chain.
    public func comesLater(_ candidate: String, than id: String) throws -> Bool {
        try database.writer.read { db in try isLater(candidate, than: id, db) }
    }

    /// The whole evolution a decision belongs to, oldest first (FR-151): every entry linked to it, directly or
    /// through others, in either direction (ADR-0052).
    public func decisionChain(of id: String) throws -> [Decision] {
        try database.writer.read { db in try component(of: id, db) }
    }

    /// The name of the chain a decision belongs to: given by the user, kept on the first decision.
    public func chainName(of id: String) throws -> String? {
        try decisionChain(of: id).compactMap { $0.chainName?.isEmpty == false ? $0.chainName : nil }.first
    }

    /// Names a chain (nil or empty: no name). Stored on its first decision, removed from the others.
    public func setChainName(_ name: String?, decisionID: String) throws {
        let chain = try decisionChain(of: decisionID)
        guard let first = chain.first else { return }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed?.isEmpty == false ? trimmed : nil
        let writer = self.writer
        try database.writer.write { db in
            for decision in chain {
                let wanted = decision.id == first.id ? value : nil
                guard var current = try Decision.fetchOne(db, key: decision.id), current.chainName != wanted
                else { continue }
                current.chainName = wanted
                try writer.save(&current, db)
            }
        }
    }

    /// Other active decisions to compare with: those sharing a stream with the decision if it has streams,
    /// otherwise those of its project. The decision's own chain is left out. Most recent first.
    public func relatedDecisions(of id: String) throws -> [DecisionSummary] {
        guard let summary = try decisionSummary(id), let projectID = summary.decision.projectId else { return [] }
        let chain = Set(try decisionChain(of: id).map(\.id))
        var candidates = try decisions(DecisionQuery(scope: .project(projectID), statuses: DecisionQuery.current))
        if !summary.streamIDs.isEmpty {
            let streams = Set(summary.streamIDs)
            candidates = candidates.filter { !streams.isDisjoint(with: $0.streamIDs) }
        }
        return candidates.filter { !chain.contains($0.id) }
    }

    /// People already used on decisions, for autocomplete and the "persona" filter.
    public func people() throws -> [Entity] {
        try database.writer.read { db in
            try Entity.filter(Column("type") == Entity.Kind.person.rawValue && Column("deleted_at") == nil)
                .order(Column("normalized")).fetchAll(db)
        }
    }

    // MARK: Internals

    private func summarize(_ decision: Decision, _ db: Database) throws -> DecisionSummary {
        let people = try String.fetchAll(
            db,
            sql: """
                SELECT entity.name FROM entity JOIN decision_entity ON decision_entity.entity_id = entity.id
                WHERE decision_entity.decision_id = ? ORDER BY entity.normalized
                """, arguments: [decision.id])
        let tags = try String.fetchAll(
            db,
            sql: """
                SELECT tag.name FROM tag JOIN decision_tag ON decision_tag.tag_id = tag.id
                WHERE decision_tag.decision_id = ? AND tag.deleted_at IS NULL ORDER BY tag.normalized
                """, arguments: [decision.id])
        let projectName = try decision.projectId.flatMap {
            try String.fetchOne(
                db, sql: "SELECT name FROM project WHERE id = ? AND deleted_at IS NULL", arguments: [$0])
        }
        var sourceTitle: String?
        var state = DecisionSourceState.none
        if let itemID = decision.sourceItemId {
            if let item = try Item.fetchOne(db, key: itemID) {
                sourceTitle = item.title.isEmpty ? nil : item.title
                state = item.deletedAt != nil ? .deleted : item.trashedAt != nil ? .trashed : .available
            } else {
                state = .deleted
            }
        } else if let noteID = decision.sourceNoteId {
            let note = try Note.fetchOne(db, key: noteID)
            state = note == nil || note?.deletedAt != nil ? .deleted : .available
        }
        let supersedesAll = try olderIDs(of: decision.id, db).compactMap { try Decision.fetchOne(db, key: $0) }
            .filter { $0.deletedAt == nil }.sorted { $0.decidedAt > $1.decidedAt }
        let supersededByAll = try newerIDs(of: decision.id, db).compactMap { try Decision.fetchOne(db, key: $0) }
            .filter { $0.deletedAt == nil }.sorted { $0.decidedAt > $1.decidedAt }
        let streamIDs = try String.fetchAll(
            db, sql: "SELECT stream_id FROM decision_stream WHERE decision_id = ?", arguments: [decision.id])
        // The chain name lives on the oldest entry of the linked group.
        let root =
            supersedesAll.isEmpty && supersededByAll.isEmpty ? decision : try component(of: decision.id, db).first
        let chainName = root?.chainName?.isEmpty == false ? root?.chainName : nil
        var summary = DecisionSummary(
            decision: decision, people: people, tags: tags, projectName: projectName, sourceTitle: sourceTitle,
            sourceState: state, supersedes: supersedesAll.first, supersededBy: supersededByAll.first,
            supersedesAll: supersedesAll, supersededByAll: supersededByAll, streamIDs: streamIDs,
            chainName: chainName)
        func name(_ id: String?) throws -> String? {
            try id.flatMap { try String.fetchOne(db, sql: "SELECT name FROM entity WHERE id = ?", arguments: [$0]) }
        }
        summary.ownerName = try name(decision.ownerId)
        summary.waitingOnName = try name(decision.waitingOnId)
        summary.blockers = try Decision.fetchAll(
            db,
            sql: """
                SELECT decision.* FROM decision JOIN decision_dependency ON decision.id = blocker_id
                WHERE blocked_id = ? AND decision.deleted_at IS NULL ORDER BY decision.decided_at
                """, arguments: [decision.id])
        if let row = try Row.fetchOne(
            db,
            sql: """
                SELECT coalesce(sum(done), 0) AS done, count(*) AS total FROM checklist_item
                WHERE decision_id = ? AND deleted_at IS NULL
                """, arguments: [decision.id])
        {
            summary.checklist = (row["done"], row["total"])
        }
        summary.derivedFrom = try decision.derivedFromId.flatMap {
            try Decision.filter(key: $0).filter(Column("deleted_at") == nil).fetchOne(db)
        }
        return summary
    }

    // MARK: Links (ADR-0052)

    func olderIDs(of id: String, _ db: Database) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
                SELECT older_id FROM decision_supersede JOIN decision ON decision.id = older_id
                WHERE newer_id = ? AND decision.deleted_at IS NULL
                """, arguments: [id])
    }

    func newerIDs(of id: String, _ db: Database) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
                SELECT newer_id FROM decision_supersede JOIN decision ON decision.id = newer_id
                WHERE older_id = ? AND decision.deleted_at IS NULL
                """, arguments: [id])
    }

    /// Replaces what `decision` supersedes; the old column keeps the most recent one, for older versions of IAGO.
    private func setOlder(_ ids: [String], for decision: inout Decision, writer: SyncWriter, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM decision_supersede WHERE newer_id = ?", arguments: [decision.id])
        let now = writer.now
        var newest: Decision?
        for id in Set(ids) where id != decision.id {
            guard let older = try Decision.fetchOne(db, key: id), older.deletedAt == nil else { continue }
            try db.execute(
                sql: "INSERT INTO decision_supersede (newer_id, older_id, created_at) VALUES (?, ?, ?)",
                arguments: [decision.id, id, now])
            if newest.map({ older.decidedAt > $0.decidedAt }) ?? true { newest = older }
        }
        if decision.supersedesId != newest?.id {
            decision.supersedesId = newest?.id
            try writer.save(&decision, db)
        }
    }

    /// Superseded when an entry that is neither cancelled nor deleted supersedes it; otherwise active again. An
    /// activity done stays done.
    private func recomputeStatus(_ ids: [String], writer: SyncWriter, _ db: Database) throws {
        for id in Set(ids) {
            guard var decision = try Decision.fetchOne(db, key: id), decision.deletedAt == nil else { continue }
            let superseding =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT count(*) FROM decision_supersede JOIN decision ON decision.id = newer_id
                        WHERE older_id = ? AND decision.deleted_at IS NULL AND decision.status != 'cancelled'
                        """, arguments: [id]) ?? 0
            let wanted: Decision.Status
            if superseding > 0 {
                guard decision.status != .done, decision.status != .cancelled else { continue }
                wanted = .superseded
            } else {
                guard decision.status == .superseded else { continue }
                wanted = .active
            }
            if decision.status != wanted {
                decision.status = wanted
                Self.stampClosed(&decision, now: writer.now)
                try writer.save(&decision, db)
                try Self.recomputeDependents(of: id, writer: writer, db)
            }
        }
    }

    /// True if `from` supersedes `to`, directly or through other entries.
    private func reaches(_ from: String, _ to: String, _ db: Database) throws -> Bool {
        var stack = [from]
        var seen: Set<String> = []
        while let current = stack.popLast() {
            for older in try olderIDs(of: current, db) {
                if older == to { return true }
                if seen.insert(older).inserted { stack.append(older) }
            }
        }
        return false
    }

    /// Every entry linked to `id`, in either direction, oldest first.
    private func component(of id: String, _ db: Database) throws -> [Decision] {
        guard let start = try Decision.fetchOne(db, key: id) else { return [] }
        var seen: Set<String> = [id]
        var queue = [id]
        var result = [start]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for next in try olderIDs(of: current, db) + newerIDs(of: current, db) where seen.insert(next).inserted {
                guard let decision = try Decision.fetchOne(db, key: next), decision.deletedAt == nil else { continue }
                result.append(decision)
                queue.append(next)
            }
        }
        // Oldest first along the links; the date only breaks ties between entries not linked to each other.
        var olders: [String: Set<String>] = [:]
        for decision in result { olders[decision.id] = Set(try olderIDs(of: decision.id, db)).intersection(seen) }
        var pending = result.sorted { ($0.decidedAt, $0.id) < ($1.decidedAt, $1.id) }
        var ordered: [Decision] = []
        var placed: Set<String> = []
        while !pending.isEmpty {
            let index = pending.firstIndex { olders[$0.id, default: []].isSubset(of: placed) } ?? 0
            let next = pending.remove(at: index)
            ordered.append(next)
            placed.insert(next.id)
        }
        return ordered
    }

    /// Removes the chain name from the first decision of `id`'s chain and returns it.
    private func takeChainName(from id: String, writer: SyncWriter, _ db: Database) throws -> String? {
        var root = try chainRoot(of: id, db)
        guard let name = root?.chainName, !name.isEmpty else { return nil }
        root?.chainName = nil
        if var root { try writer.save(&root, db) }
        return name
    }

    /// Puts the chain name back on the first decision of `id`'s chain.
    private func giveChainName(_ name: String, from id: String, writer: SyncWriter, _ db: Database) throws {
        guard var root = try chainRoot(of: id, db) else { return }
        root.chainName = name
        try writer.save(&root, db)
    }

    private func chainRoot(of id: String, _ db: Database) throws -> Decision? {
        try component(of: id, db).first
    }

    /// True if `candidate` already comes after `id` (superseding it would make a loop).
    private func isLater(_ candidate: String, than id: String, _ db: Database) throws -> Bool {
        try reaches(candidate, id, db)
    }

    private func setPeople(_ names: [String], decisionID: String, writer: SyncWriter, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM decision_entity WHERE decision_id = ?", arguments: [decisionID])
        var seen: Set<String> = []
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = TagNormalizer.normalize(trimmed)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            var entity: Entity
            if let existing = try Entity.filter(
                Column("type") == Entity.Kind.person.rawValue && Column("normalized") == normalized
            ).fetchOne(db) {
                entity = existing
                if entity.deletedAt != nil {
                    entity.deletedAt = nil
                    try writer.save(&entity, db)
                }
            } else {
                entity = Entity(id: newID(at: writer.now), type: .person, name: trimmed, normalized: normalized)
                try writer.save(&entity, db)
            }
            try db.execute(
                sql: "INSERT INTO decision_entity (decision_id, entity_id) VALUES (?, ?)",
                arguments: [decisionID, entity.id])
        }
    }

    private func setDecisionTags(_ names: [String], decisionID: String, writer: SyncWriter, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM decision_tag WHERE decision_id = ?", arguments: [decisionID])
        var seen: Set<String> = []
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = TagNormalizer.normalize(trimmed)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            var tag: Tag
            if let existing = try Tag.filter(Column("normalized") == normalized).fetchOne(db) {
                tag = existing
                if tag.deletedAt != nil {
                    tag.deletedAt = nil
                    tag.name = trimmed
                    try writer.save(&tag, db)
                }
            } else {
                tag = Tag(id: newID(at: writer.now), name: trimmed, normalized: normalized)
                try writer.save(&tag, db)
            }
            try db.execute(
                sql: "INSERT INTO decision_tag (decision_id, tag_id) VALUES (?, ?)", arguments: [decisionID, tag.id])
        }
    }

    /// Decisions follow their source item when it moves to another project, unless they were moved by hand.
    func moveDecisions(ofItem itemID: String, from old: String?, to new: String?, writer: SyncWriter, _ db: Database)
        throws
    {
        // Decisions promoted from the item's notes follow the item too.
        for var decision in try Decision.filter(Column("deleted_at") == nil)
            .filter(
                sql: "source_item_id = ? OR source_note_id IN (SELECT id FROM note WHERE item_id = ?)",
                arguments: [itemID, itemID]
            )
            .fetchAll(db) where decision.projectId == old
        {
            decision.projectId = new
            try writer.save(&decision, db)
            try dropForeignStreams(decisionID: decision.id, projectID: new, db)
            try indexDecision(decision, db)
        }
    }

    /// Decisions are indexed without `item_id`: they stay searchable when their source is deleted (FR-156).
    func indexDecision(_ decision: Decision, _ db: Database) throws {
        try db.execute(
            sql: "DELETE FROM search_index WHERE source = 'decision' AND source_id = ?", arguments: [decision.id])
        guard decision.deletedAt == nil, !decision.text.isEmpty else { return }
        try db.execute(
            sql:
                "INSERT INTO search_index (project_id, source, source_id, at_sec, text) VALUES (?, 'decision', ?, ?, ?)",
            arguments: [
                decision.projectId, decision.id, decision.sourceAtSec,
                [decision.text, decision.notes ?? ""].filter { !$0.isEmpty }.joined(separator: "\n"),
            ])
    }
}
