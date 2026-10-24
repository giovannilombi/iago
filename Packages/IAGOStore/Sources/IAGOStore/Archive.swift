import CryptoKit
import Foundation
import GRDB

/// The encrypted archive: database rows plus per-item encrypted files (spec 8, 9). Every mutation
/// goes through `SyncWriter` (versions, `change_log`). Thread-safe: GRDB serializes writes.
public final class Archive: Sendable {
    public let database: AppDatabase
    /// `Items/`: one folder per item, named by ID, never renamed (spec 9.1).
    public let itemsRoot: URL
    public let deviceID: String
    let keyring: ItemKeyring
    let now: @Sendable () -> Date

    /// Days an item or asset stays in the trash before it is deleted for good (ADR-0030).
    public static let trashRetention: TimeInterval = 30 * 24 * 3600
    /// "Scartate temporanee": recordings discarded while recording are kept for one hour (ADR-0032).
    public static let discardRetention: TimeInterval = 3600
    static let discardedReason = "discarded"

    /// `readOnly`: the MCP server's view of the archive (ADR-0043). Nothing is written: no device ID, no
    /// folders, no built-in categories; every mutation fails on the read-only connection.
    public init(
        database: AppDatabase, itemsRoot: URL, keyStore: any MasterKeyStore,
        now: @escaping @Sendable () -> Date = { Date() }, readOnly: Bool = false
    ) throws {
        self.database = database
        self.itemsRoot = itemsRoot
        self.keyring = ItemKeyring(master: try keyStore.masterKey())
        self.now = now
        if readOnly {
            self.deviceID =
                try database.writer.read { db in
                    try String.fetchOne(db, sql: "SELECT value FROM setting WHERE key = 'device_id'")
                } ?? ""
            return
        }
        self.deviceID = try database.writer.write { db in
            if let existing = try String.fetchOne(db, sql: "SELECT value FROM setting WHERE key = 'device_id'") {
                return existing
            }
            let id = UUID().uuidString.lowercased()
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('device_id', ?)", arguments: [id])
            return id
        }
        try FileManager.default.createDirectory(at: itemsRoot, withIntermediateDirectories: true)
        try seedBuiltinCategories()
        try seedCategoryLibrary()
    }

    var writer: SyncWriter { SyncWriter(deviceID: deviceID, now: now()) }

    /// Excludes `url` from Time Machine (spec 9.3: the archive is excluded by default).
    public static func setExcludedFromBackup(_ url: URL, excluded: Bool = true) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = excluded
        var url = url
        try url.setResourceValues(values)
    }

    // MARK: Items

    /// Creates an item and its encryption key in one transaction.
    @discardableResult
    public func createItem(
        id: String? = nil, type: Item.Kind = .call, title: String, occurredAt: Date, source: Item.Source,
        status: Item.Status, durationSec: Double? = nil, captureMeta: String? = nil
    ) throws -> Item {
        let writer = self.writer
        var item = Item(
            id: id ?? newID(at: occurredAt), type: type, title: title, occurredAt: occurredAt, durationSec: durationSec,
            source: source, status: status, captureMeta: captureMeta)
        let wrapped = try keyring.newWrappedKey(for: item.id).wrapped
        try database.writer.write { db in
            try writer.save(&item, db)
            try db.execute(
                sql: "INSERT INTO item_key (item_id, wrapped_key) VALUES (?, ?)", arguments: [item.id, wrapped])
        }
        return item
    }

    @discardableResult
    public func updateItem(_ id: String, _ change: @Sendable (inout Item) throws -> Void) throws -> Item {
        let writer = self.writer
        return try database.writer.write { db in
            var item = try Self.require(Item.fetchOne(db, key: id), id)
            let previousProject = item.projectId
            try change(&item)
            try writer.save(&item, db)
            if item.projectId != previousProject {
                try reindexProject(of: id, projectID: item.projectId, db)
                try dropForeignStreams(itemID: id, projectID: item.projectId, db)
                try moveDecisions(ofItem: id, from: previousProject, to: item.projectId, writer: writer, db)
            }
            return item
        }
    }

    public func item(_ id: String) throws -> Item? {
        try database.writer.read { db in try Item.filter(key: id).filter(Column("deleted_at") == nil).fetchOne(db) }
    }

    /// Items not deleted and not in the trash, most recent first.
    public func items() throws -> [Item] {
        try database.writer.read { db in
            try Item.filter(Column("deleted_at") == nil && Column("trashed_at") == nil)
                .order(Column("occurred_at").desc).fetchAll(db)
        }
    }

    // MARK: Projects and categories

    @discardableResult
    public func createProject(name: String, color: String? = nil) throws -> Project {
        let writer = self.writer
        var project = Project(id: newID(at: writer.now), name: name, color: color)
        try database.writer.write { db in try writer.save(&project, db) }
        return project
    }

    /// Pinned first, then by last use (most recent first), then by name. Archived projects are left out
    /// unless asked for (Settings › Progetti).
    public func projects(includeArchived: Bool = false) throws -> [Project] {
        try database.writer.read { db in
            var request = Project.filter(Column("deleted_at") == nil)
            if !includeArchived { request = request.filter(Column("archived") == false) }
            return
                try request
                .order(
                    Column("pinned").desc, Column("last_used_at").desc,
                    Column("name").collating(.localizedCaseInsensitiveCompare)
                )
                .fetchAll(db)
        }
    }

    /// "Consultabile da Claude" (FR-131): only these projects are visible to the MCP server.
    public func setProjectClaudeAccessible(_ id: String, _ accessible: Bool) throws {
        let writer = self.writer
        try database.writer.write { db in
            var project = try Self.require(Project.fetchOne(db, key: id), id)
            guard project.claudeAccessible != accessible else { return }
            project.claudeAccessible = accessible
            try writer.save(&project, db)
        }
    }

    /// "Claude può anche scrivere" (ADR-0044).
    public func setProjectClaudeWritable(_ id: String, _ writable: Bool) throws {
        let writer = self.writer
        try database.writer.write { db in
            var project = try Self.require(Project.fetchOne(db, key: id), id)
            guard project.claudeWritable != writable else { return }
            project.claudeWritable = writable
            try writer.save(&project, db)
        }
    }

    public func setProjectPinned(_ id: String, _ pinned: Bool) throws {
        let writer = self.writer
        try database.writer.write { db in
            var project = try Self.require(Project.fetchOne(db, key: id), id)
            project.pinned = pinned
            try writer.save(&project, db)
        }
    }

    /// Marks a project as just used (opened or assigned an item). Local ordering only: not logged for sync.
    public func touchProject(_ id: String) throws {
        let now = self.now()
        try database.writer.write { db in
            try db.execute(sql: "UPDATE project SET last_used_at = ? WHERE id = ?", arguments: [now, id])
        }
    }

    public func categories(includeArchived: Bool = false) throws -> [Category] {
        try database.writer.read { db in
            var request = Category.filter(Column("deleted_at") == nil)
            if !includeArchived { request = request.filter(Column("archived") == false) }
            return try request.order(Column("sort_order")).fetchAll(db)
        }
    }

    private func seedBuiltinCategories() throws {
        let writer = self.writer
        try database.writer.write { db in
            guard try Category.filter(Column("is_builtin") == true).fetchCount(db) == 0 else { return }
            for (index, name) in Category.builtinNames.enumerated() {
                var category = Category(id: newID(at: writer.now), name: name, sortOrder: index, isBuiltin: true)
                try writer.save(&category, db)
            }
        }
    }

    // MARK: Tags

    /// Replaces the item's tags. Names are matched by normalized form: an existing (or deleted) tag
    /// is reused, so "Kickoff" and "kickoff " are the same tag.
    public func setTags(_ names: [String], for itemID: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            var wanted: [String: Tag] = [:]
            for name in names {
                let normalized = TagNormalizer.normalize(name)
                guard !normalized.isEmpty, wanted[normalized] == nil else { continue }
                if var tag = try Tag.filter(Column("normalized") == normalized).fetchOne(db) {
                    if tag.deletedAt != nil {
                        tag.deletedAt = nil
                        tag.name = name.trimmingCharacters(in: .whitespaces)
                        try writer.save(&tag, db)
                    }
                    wanted[normalized] = tag
                } else {
                    var tag = Tag(
                        id: newID(at: writer.now), name: name.trimmingCharacters(in: .whitespaces),
                        normalized: normalized)
                    try writer.save(&tag, db)
                    wanted[normalized] = tag
                }
            }
            let current = Set(
                try String.fetchAll(db, sql: "SELECT tag_id FROM item_tag WHERE item_id = ?", arguments: [itemID]))
            let target = Set(wanted.values.map(\.id))
            for tagID in current.subtracting(target) {
                try db.execute(
                    sql: "DELETE FROM item_tag WHERE item_id = ? AND tag_id = ?", arguments: [itemID, tagID])
                try ChangeLog.append(
                    db, table: "item_tag", rowID: "\(itemID)/\(tagID)", op: .delete, version: 0, at: writer.now)
            }
            for tagID in target.subtracting(current) {
                try db.execute(
                    sql: "INSERT INTO item_tag (item_id, tag_id, created_at) VALUES (?, ?, ?)",
                    arguments: [itemID, tagID, writer.now])
                try ChangeLog.append(
                    db, table: "item_tag", rowID: "\(itemID)/\(tagID)", op: .insert, version: 0, at: writer.now)
            }
        }
    }

    public func tags(for itemID: String) throws -> [Tag] {
        try database.writer.read { db in
            try Tag.fetchAll(
                db,
                sql: """
                    SELECT tag.* FROM tag JOIN item_tag ON item_tag.tag_id = tag.id
                    WHERE item_tag.item_id = ? AND tag.deleted_at IS NULL ORDER BY tag.normalized
                    """, arguments: [itemID])
        }
    }

    /// Creates a tag (or revives a deleted one with the same normalized name).
    @discardableResult
    public func createTag(name: String) throws -> Tag {
        let writer = self.writer
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let normalized = TagNormalizer.normalize(trimmed)
        return try database.writer.write { db in
            if var tag = try Tag.filter(Column("normalized") == normalized).fetchOne(db) {
                if tag.deletedAt != nil {
                    tag.deletedAt = nil
                    tag.name = trimmed
                    try writer.save(&tag, db)
                }
                return tag
            }
            var tag = Tag(id: newID(at: writer.now), name: trimmed, normalized: normalized)
            try writer.save(&tag, db)
            return tag
        }
    }

    public func allTags() throws -> [Tag] {
        try database.writer.read { db in
            try Tag.filter(Column("deleted_at") == nil).order(Column("normalized")).fetchAll(db)
        }
    }

    /// Autocomplete for the tag field (FR-101, textual part).
    public func tagSuggestions(for input: String, limit: Int = 8) throws -> [Tag] {
        TagNormalizer.suggestions(for: input, among: try allTags(), limit: limit)
    }

    // MARK: Notes (FR-170…176)

    @discardableResult
    public func addNote(
        itemID: String?, projectID: String? = nil, body: String, notedAt: Date? = nil, kind: Note.Kind = .note,
        input: Note.Input = .typed, streams: [String] = []
    ) throws -> Note {
        let writer = self.writer
        var note = Note(
            id: newID(at: writer.now), itemId: itemID, projectId: projectID, kind: kind, input: input, body: body,
            notedAt: notedAt ?? writer.now)
        try database.writer.write { db in
            try writer.save(&note, db)
            if !streams.isEmpty { try setNoteStreams(streams, note: note, db) }
            try indexNote(note, db)
        }
        return note
    }

    @discardableResult
    public func updateNote(_ id: String, _ change: @Sendable (inout Note) throws -> Void) throws -> Note {
        let writer = self.writer
        return try database.writer.write { db in
            var note = try Self.require(Note.fetchOne(db, key: id), id)
            try change(&note)
            try writer.save(&note, db)
            try indexNote(note, db)
            return note
        }
    }

    /// Deletes a single note: tombstone, body erased (no trash for single notes, ADR-0030).
    public func deleteNote(_ id: String) throws {
        let writer = self.writer
        try database.writer.write { db in
            var note = try Self.require(Note.fetchOne(db, key: id), id)
            note.body = ""
            try writer.tombstone(&note, db)
            try db.execute(sql: "DELETE FROM note_stream WHERE note_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM chunk WHERE note_id = ?", arguments: [id])
            try indexNote(note, db)
        }
        for attachment in try attachments(noteID: id) { try purgeAsset(attachment.id) }
    }

    /// Keeps the original of a file attached to a note (always a new asset; a note can have many). The owner
    /// is the note's item or, for a project note, its project (ADR-0039).
    @discardableResult
    public func storeAttachment(_ source: URL, itemID: String, noteID: String, originalName: String) throws -> Asset {
        try storeAttachment(source, ownerID: itemID, noteID: noteID, originalName: originalName)
    }

    @discardableResult
    public func storeAttachment(_ source: URL, ownerID itemID: String, noteID: String, originalName: String) throws
        -> Asset
    {
        if try isProject(itemID) { try ensureProjectKey(itemID) }
        let id = newID(at: now())
        let safeName = originalName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let relPath = "\(itemID)/attachments/\(id)-\(safeName).enc"
        let result = try EncryptedFile.encrypt(
            source, to: itemsRoot.appendingPathComponent(relPath), key: try itemKey(itemID), context: relPath)
        let writer = self.writer
        return try database.writer.write { db in
            var asset = Asset(id: id, itemId: itemID, kind: .noteAttachment, relPath: relPath)
            asset.sizeBytes = result.size
            asset.sha256 = result.sha256
            asset.noteId = noteID
            asset.originalName = originalName
            try writer.save(&asset, db)
            return asset
        }
    }

    public func attachments(noteID: String) throws -> [Asset] {
        try database.writer.read { db in
            try Asset.filter(Column("note_id") == noteID && Column("deleted_at") == nil).order(Column("created_at"))
                .fetchAll(db)
        }
    }

    public func note(_ id: String) throws -> Note? {
        try database.writer.read { db in try Note.filter(key: id).filter(Column("deleted_at") == nil).fetchOne(db) }
    }

    /// Project notes (FR-172): notes of the project that are not attached to an item, by `noted_at`.
    public func notes(projectID: String) throws -> [Note] {
        try database.writer.read { db in
            try Note.filter(
                Column("project_id") == projectID && Column("item_id") == nil && Column("deleted_at") == nil
            )
            .order(Column("noted_at")).fetchAll(db)
        }
    }

    /// Every note at its date for a project timeline (FR-175): project notes and notes of the given items.
    public func notes(projectID: String?, itemIDs: [String]) throws -> [Note] {
        try database.writer.read { db in
            var request = Note.filter(Column("deleted_at") == nil)
            if let projectID {
                request = request.filter(
                    (Column("project_id") == projectID && Column("item_id") == nil)
                        || itemIDs.contains(Column("item_id")))
            } else {
                request = request.filter(itemIDs.contains(Column("item_id")))
            }
            return try request.order(Column("noted_at").desc).fetchAll(db)
        }
    }

    private func isProject(_ id: String) throws -> Bool {
        try database.writer.read { db in try Project.filter(key: id).fetchCount(db) > 0 }
    }

    /// Projects get a key only when a project note keeps its first original (stored in `item_key`, ADR-0039).
    private func ensureProjectKey(_ projectID: String) throws {
        let exists = try database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM item_key WHERE item_id = ?", arguments: [projectID]) ?? 0
        }
        guard exists == 0 else { return }
        let wrapped = try keyring.newWrappedKey(for: projectID).wrapped
        try database.writer.write { db in
            try db.execute(
                sql: "INSERT INTO item_key (item_id, wrapped_key) VALUES (?, ?)", arguments: [projectID, wrapped])
        }
    }

    /// Notes of a stream's timeline (ADR-0047): notes put in the stream and notes of the given items.
    public func notes(streamID: String, itemIDs: [String]) throws -> [Note] {
        try database.writer.read { db in
            try Note.filter(Column("deleted_at") == nil)
                .filter(
                    sql:
                        "(id IN (SELECT note_id FROM note_stream WHERE stream_id = ?) OR item_id IN (SELECT value FROM json_each(?)))",
                    arguments: [streamID, String(decoding: try JSONEncoder().encode(itemIDs), as: UTF8.self)]
                )
                .order(Column("noted_at").desc).fetchAll(db)
        }
    }

    /// Notes of an item, ordered by `noted_at` (FR-171).
    public func notes(itemID: String) throws -> [Note] {
        try database.writer.read { db in
            try Note.filter(Column("item_id") == itemID && Column("deleted_at") == nil).order(Column("noted_at"))
                .fetchAll(db)
        }
    }

    // MARK: Markers ("Segna momento")

    @discardableResult
    public func addMarker(itemID: String, atSec: Double, note: String?) throws -> Marker {
        let writer = self.writer
        var marker = Marker(id: newID(at: writer.now), itemId: itemID, atSec: atSec, note: note)
        try database.writer.write { db in try writer.save(&marker, db) }
        return marker
    }

    public func setMarkerStatus(_ id: String, _ status: Marker.Status) throws {
        let writer = self.writer
        try database.writer.write { db in
            var marker = try Self.require(Marker.fetchOne(db, key: id), id)
            marker.status = status
            try writer.save(&marker, db)
        }
    }

    public func markers(itemID: String) throws -> [Marker] {
        try database.writer.read { db in
            try Marker.filter(Column("item_id") == itemID && Column("deleted_at") == nil).order(Column("at_sec"))
                .fetchAll(db)
        }
    }

    // MARK: Speakers (FR-41)

    /// Sets the speakers of a transcript, keeping labels the user already chose.
    public func setSpeakers(_ speakers: [(id: String, label: String)], for itemID: String) throws {
        try database.writer.write { db in
            for speaker in speakers {
                try db.execute(
                    sql:
                        "INSERT INTO item_speaker (item_id, speaker_id, label) VALUES (?, ?, ?) ON CONFLICT DO NOTHING",
                    arguments: [itemID, speaker.id, speaker.label])
            }
        }
    }

    public func renameSpeaker(_ speakerID: String, of itemID: String, to label: String) throws {
        let now = self.now()
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE item_speaker SET label = ? WHERE item_id = ? AND speaker_id = ?",
                arguments: [label, itemID, speakerID])
            try ChangeLog.append(
                db, table: "item_speaker", rowID: "\(itemID)/\(speakerID)", op: .update, version: 0, at: now)
        }
    }

    public func speakers(itemID: String) throws -> [ItemSpeaker] {
        try database.writer.read { db in try ItemSpeaker.filter(Column("item_id") == itemID).fetchAll(db) }
    }

    // MARK: Encrypted assets

    func itemKey(_ itemID: String) throws -> SymmetricKey {
        let wrapped = try database.writer.read { db in
            try Data.fetchOne(db, sql: "SELECT wrapped_key FROM item_key WHERE item_id = ?", arguments: [itemID])
        }
        guard let wrapped else { throw ArchiveError.keyDeleted(itemID) }
        return try keyring.unwrap(wrapped, for: itemID)
    }

    public func url(of asset: Asset) -> URL { itemsRoot.appendingPathComponent(asset.relPath) }

    /// Encrypts `source` into the item's folder as `<fileName>.enc` and records the asset. The source
    /// is left in place: the caller deletes it once the asset is stored.
    @discardableResult
    public func storeAsset(
        _ source: URL, itemID: String, kind: Asset.Kind, fileName: String, originalName: String? = nil
    )
        throws -> Asset
    {
        let relPath = "\(itemID)/\(fileName).enc"
        let result = try EncryptedFile.encrypt(
            source, to: itemsRoot.appendingPathComponent(relPath), key: try itemKey(itemID), context: relPath)
        return try recordAsset(itemID: itemID, kind: kind, relPath: relPath, result: result, originalName: originalName)
    }

    @discardableResult
    public func storeAsset(
        _ data: Data, itemID: String, kind: Asset.Kind, fileName: String, originalName: String? = nil
    ) throws
        -> Asset
    {
        let relPath = "\(itemID)/\(fileName).enc"
        let result = try EncryptedFile.encrypt(
            data, to: itemsRoot.appendingPathComponent(relPath), key: try itemKey(itemID), context: relPath)
        return try recordAsset(itemID: itemID, kind: kind, relPath: relPath, result: result, originalName: originalName)
    }

    /// One live asset per kind: storing a kind again replaces the previous file (e.g. re-transcription).
    private func recordAsset(
        itemID: String, kind: Asset.Kind, relPath: String, result: EncryptedFile.Result, originalName: String? = nil
    ) throws
        -> Asset
    {
        let writer = self.writer
        return try database.writer.write { db in
            var asset =
                try Asset.filter(
                    Column("item_id") == itemID && Column("kind") == kind.rawValue && Column("deleted_at") == nil
                )
                .fetchOne(db) ?? Asset(id: newID(at: writer.now), itemId: itemID, kind: kind, relPath: relPath)
            asset.relPath = relPath
            asset.sizeBytes = result.size
            asset.sha256 = result.sha256
            asset.trashedAt = nil
            if let originalName { asset.originalName = originalName }
            try writer.save(&asset, db)
            return asset
        }
    }

    /// Decrypts an asset to `destination` and checks it against the recorded SHA-256.
    @discardableResult
    public func readAsset(_ asset: Asset, to destination: URL) throws -> EncryptedFile.Result {
        let result = try EncryptedFile.decrypt(
            url(of: asset), to: destination, key: try itemKey(asset.itemId), context: asset.relPath)
        if let expected = asset.sha256, expected != result.sha256 { throw ArchiveError.checksumMismatch(asset.id) }
        return result
    }

    public func readAssetData(_ asset: Asset) throws -> Data {
        let data = try EncryptedFile.decryptData(url(of: asset), key: try itemKey(asset.itemId), context: asset.relPath)
        if let expected = asset.sha256, expected != EncryptedFile.hex(SHA256.hash(data: data)) {
            throw ArchiveError.checksumMismatch(asset.id)
        }
        return data
    }

    public func assets(itemID: String, includeTrashed: Bool = false) throws -> [Asset] {
        try database.writer.read { db in
            // Note attachments are listed with their note, not among the item's files.
            var request = Asset.filter(
                Column("item_id") == itemID && Column("deleted_at") == nil
                    && Column("kind") != Asset.Kind.noteAttachment.rawValue)
            if !includeTrashed { request = request.filter(Column("trashed_at") == nil) }
            return try request.order(Column("kind")).fetchAll(db)
        }
    }

    // MARK: Trash (ADR-0030)

    public func trashItem(_ id: String) throws {
        try updateItem(id) { [now] in $0.trashedAt = now() }
    }

    public func restoreItem(_ id: String) throws {
        try updateItem(id) {
            $0.trashedAt = nil
            $0.trashReason = nil
        }
    }

    /// "Scarta" (ADR-0032): to the temporary discards, deleted for good after `discardRetention`.
    public func discardItem(_ id: String) throws {
        try updateItem(id) { [now] in
            $0.trashedAt = now()
            $0.trashReason = Self.discardedReason
        }
    }

    public func discardedItems() throws -> [Item] {
        try database.writer.read { db in
            try Item.filter(
                Column("deleted_at") == nil && Column("trashed_at") != nil
                    && Column("trash_reason") == Self.discardedReason
            )
            .order(Column("trashed_at").desc).fetchAll(db)
        }
    }

    public func trashAsset(_ id: String) throws {
        try updateAsset(id) { [now] in $0.trashedAt = now() }
    }

    public func restoreAsset(_ id: String) throws {
        try updateAsset(id) { $0.trashedAt = nil }
    }

    private func updateAsset(_ id: String, _ change: @Sendable (inout Asset) -> Void) throws {
        let writer = self.writer
        try database.writer.write { db in
            var asset = try Self.require(Asset.fetchOne(db, key: id), id)
            change(&asset)
            try writer.save(&asset, db)
        }
    }

    public func trashedItems() throws -> [Item] {
        try database.writer.read { db in
            try Item.filter(Column("deleted_at") == nil && Column("trashed_at") != nil && Column("trash_reason") == nil)
                .order(Column("trashed_at").desc)
                .fetchAll(db)
        }
    }

    /// Assets in the trash whose item is not (an item in the trash carries its assets with it).
    public func trashedAssets() throws -> [Asset] {
        try database.writer.read { db in
            try Asset.fetchAll(
                db,
                sql: """
                    SELECT asset.* FROM asset JOIN item ON item.id = asset.item_id
                    WHERE asset.deleted_at IS NULL AND asset.trashed_at IS NOT NULL AND item.trashed_at IS NULL
                    ORDER BY asset.trashed_at DESC
                    """)
        }
    }

    /// When an item or asset trashed at `trashedAt` is deleted for good.
    public func purgeDate(forTrashedAt trashedAt: Date) -> Date { trashedAt.addingTimeInterval(Self.trashRetention) }

    public func purgeDate(forDiscardedAt discardedAt: Date) -> Date {
        discardedAt.addingTimeInterval(Self.discardRetention)
    }

    /// What happens to an item's notes when it is deleted for good (FR-176).
    public enum NoteDisposition: Sendable {
        case delete
        /// Moves them to the item's project; falls back to deleting if the item has none.
        case moveToProject
    }

    /// Deletes an item for good (crypto-shredding, spec 9.3): the key goes first, then the files, then
    /// the text in the database. The row stays as a tombstone for the future sync.
    public func purgeItem(_ id: String, notes disposition: NoteDisposition = .delete) throws {
        let writer = self.writer
        try database.writer.write { db in
            var item = try Self.require(Item.fetchOne(db, key: id), id)
            try db.execute(sql: "DELETE FROM item_key WHERE item_id = ?", arguments: [id])
            try removeFromIndex(itemID: id, db)
            try db.execute(sql: "DELETE FROM item_tag WHERE item_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM item_speaker WHERE item_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM item_stream WHERE item_id = ?", arguments: [id])
            try removeIntelligence(itemID: id, db)
            try removeLinks(itemID: id, writer: writer, db)
            for var asset in try Asset.filter(Column("item_id") == id && Column("deleted_at") == nil).fetchAll(db) {
                asset.sha256 = nil
                try writer.tombstone(&asset, db)
            }
            for var marker in try Marker.filter(Column("item_id") == id && Column("deleted_at") == nil).fetchAll(db) {
                marker.note = nil
                try writer.tombstone(&marker, db)
            }
            for var note in try Note.filter(Column("item_id") == id && Column("deleted_at") == nil).fetchAll(db) {
                if disposition == .moveToProject, let projectID = item.projectId {
                    note.itemId = nil
                    note.projectId = projectID
                    try writer.save(&note, db)
                    try indexNote(note, db)
                } else {
                    note.body = ""
                    try writer.tombstone(&note, db)
                }
            }
            item.title = ""
            item.captureMeta = nil
            item.trashedAt = nil
            try writer.tombstone(&item, db)
        }
        let folder = itemsRoot.appendingPathComponent(id, isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    }

    /// Deletes one asset for good: file removed, row tombstoned.
    public func purgeAsset(_ id: String) throws {
        let writer = self.writer
        let relPath = try database.writer.write { db in
            var asset = try Self.require(Asset.fetchOne(db, key: id), id)
            asset.sha256 = nil
            try writer.tombstone(&asset, db)
            return asset.relPath
        }
        let file = itemsRoot.appendingPathComponent(relPath)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    /// "Svuota cestino".
    public func emptyTrash() throws {
        for item in try trashedItems() + discardedItems() { try purgeItem(item.id) }
        for asset in try trashedAssets() { try purgeAsset(asset.id) }
    }

    /// Deletes for good what has been in the trash longer than `trashRetention`. Run at launch and
    /// once a day. Returns the number of items and assets deleted.
    @discardableResult
    public func purgeExpiredTrash() throws -> Int {
        let cutoff = now().addingTimeInterval(-Self.trashRetention)
        let discardCutoff = now().addingTimeInterval(-Self.discardRetention)
        let items =
            try trashedItems().filter { $0.trashedAt! <= cutoff }
            + discardedItems().filter { $0.trashedAt! <= discardCutoff }
        let assets = try trashedAssets().filter { $0.trashedAt! <= cutoff }
        for item in items { try purgeItem(item.id) }
        for asset in assets { try purgeAsset(asset.id) }
        return items.count + assets.count
    }

    // MARK: Settings and audit log

    public func setting(_ key: String) throws -> String? {
        try database.writer.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM setting WHERE key = ?", arguments: [key])
        }
    }

    public func setSetting(_ key: String, _ value: String?) throws {
        try database.writer.write { db in
            if let value {
                try db.execute(
                    sql:
                        "INSERT INTO setting (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                    arguments: [key, value])
            } else {
                try db.execute(sql: "DELETE FROM setting WHERE key = ?", arguments: [key])
            }
        }
    }

    public enum AuditActor: String, Sendable {
        case modelDownload = "model_download"
        case mcp, llm, sync
        /// Content leaving the encrypted archive at the user's request (export, audio, Obsidian, backup).
        case export, backup
        /// The update check and download from GitHub Releases (ADR-0056).
        case update
    }

    /// Records every network exit and every MCP access (spec 4.2, 5.2). Never transcript content.
    public func audit(_ actor: AuditActor, action: String, detail: String? = nil) throws {
        let now = self.now()
        try database.writer.write { db in
            try db.execute(
                sql: "INSERT INTO audit_log (at, actor, action, detail) VALUES (?, ?, ?, ?)",
                arguments: [now, actor.rawValue, action, detail])
        }
    }

    /// Appends to the audit log of the database at `url` from another process (the MCP server, whose archive
    /// is read-only): a short connection opened only for this insert, no migrations (ADR-0043).
    public static func appendAudit(
        databaseAt url: URL, _ actor: AuditActor, action: String, detail: String? = nil, at date: Date = Date()
    ) throws {
        var configuration = Configuration()
        configuration.busyMode = .timeout(5)
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO audit_log (at, actor, action, detail) VALUES (?, ?, ?, ?)",
                arguments: [date, actor.rawValue, action, detail])
        }
        try queue.close()
    }

    public func auditEntries(limit: Int = 200) throws -> [AuditEntry] {
        try database.writer.read { db in
            try AuditEntry.fetchAll(db, sql: "SELECT * FROM audit_log ORDER BY id DESC LIMIT ?", arguments: [limit])
        }
    }

    // MARK: Helpers

    static func require<T>(_ value: T?, _ id: String) throws -> T {
        guard let value else { throw ArchiveError.notFound(id) }
        return value
    }
}

public enum ArchiveError: Error, Sendable, Equatable, CustomStringConvertible {
    case notFound(String)
    case keyDeleted(String)
    case checksumMismatch(String)
    /// An email with this Message-ID is already in the archive.
    case duplicateEmail(String)

    public var description: String {
        switch self {
        case .notFound(let id): "No row with id \(id)"
        case .keyDeleted(let id): "The key of item \(id) has been deleted"
        case .checksumMismatch(let id): "Asset \(id) does not match its checksum"
        case .duplicateEmail: "Email già in archivio"
        }
    }
}
