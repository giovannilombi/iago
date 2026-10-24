import Foundation
import GRDB
import Testing

@testable import IAGOStore

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_791_000_000)) { current = start }

    var now: Date { lock.withLock { current } }
    func advance(days: Double) { lock.withLock { current = current.addingTimeInterval(days * 86_400) } }
}

struct ArchiveFixture {
    let clock = TestClock()
    let root: URL
    let archive: Archive

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-archive-\(UUID().uuidString)")
        let clock = self.clock
        archive = try Archive(
            database: try AppDatabase.inMemory(), itemsRoot: root.appendingPathComponent("Items"),
            keyStore: EphemeralMasterKeyStore(), now: { clock.now })
    }

    func makeItem(_ title: String = "Call") throws -> Item {
        try archive.createItem(title: title, occurredAt: clock.now, source: .recording, status: .recorded)
    }

    func plainFile(_ text: String) throws -> URL {
        let url = root.appendingPathComponent("plain-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
        return url
    }

    func changeLog() throws -> [Row] {
        try archive.database.writer.read { db in try Row.fetchAll(db, sql: "SELECT * FROM change_log ORDER BY seq") }
    }
}

@Suite struct ArchiveTests {
    @Test func builtinCategoriesAreSeededOnce() throws {
        let database = try AppDatabase.inMemory()
        let first = try Archive(
            database: database, itemsRoot: FileManager.default.temporaryDirectory, keyStore: EphemeralMasterKeyStore())
        let second = try Archive(
            database: database, itemsRoot: FileManager.default.temporaryDirectory, keyStore: EphemeralMasterKeyStore())
        #expect(try second.categories().map(\.name) == Category.builtinNames)
        #expect(first.deviceID == second.deviceID)
    }

    @Test func writesBumpVersionAndChangeLog() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        #expect(item.version == 1)
        #expect(item.deviceId == fixture.archive.deviceID)
        let updated = try fixture.archive.updateItem(item.id) { $0.title = "Kickoff" }
        #expect(updated.version == 2)
        let log = try fixture.changeLog().filter { $0["table_name"] == "item" }
        #expect(log.map { $0["op"] as String } == ["insert", "update"])
        #expect(log.map { $0["version"] as Int } == [1, 2])
    }

    @Test func tagsAreNormalizedAndReused() throws {
        let fixture = try ArchiveFixture()
        let a = try fixture.makeItem()
        let b = try fixture.makeItem()
        try fixture.archive.setTags(["Design System", "roadmap"], for: a.id)
        try fixture.archive.setTags(["design  system", "Città"], for: b.id)
        #expect(try fixture.archive.allTags().map(\.normalized) == ["citta", "design system", "roadmap"])
        #expect(try fixture.archive.tags(for: b.id).map(\.name) == ["Città", "Design System"])
        try fixture.archive.setTags([], for: a.id)
        #expect(try fixture.archive.tags(for: a.id).isEmpty)
    }

    @Test func tagSuggestionsUsePrefixThenTypos() {
        let tags = ["kickoff", "kickoff cliente", "roadmap", "sal"].map {
            Tag(id: $0, name: $0, normalized: $0)
        }
        #expect(TagNormalizer.suggestions(for: "Kick", among: tags).map(\.name) == ["kickoff", "kickoff cliente"])
        #expect(TagNormalizer.suggestions(for: "rodmap", among: tags).map(\.name) == ["roadmap"])
        #expect(TagNormalizer.suggestions(for: "zzz", among: tags).isEmpty)
    }

    @Test func notesAreOrderedEditableAndDeletable() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        let base = fixture.clock.now
        let late = try fixture.archive.addNote(itemID: item.id, body: "terza", notedAt: base.addingTimeInterval(300))
        let early = try fixture.archive.addNote(itemID: item.id, body: "prima", notedAt: base.addingTimeInterval(100))
        let middle = try fixture.archive.addNote(
            itemID: item.id, body: "seconda", notedAt: base.addingTimeInterval(200))
        #expect(try fixture.archive.notes(itemID: item.id).map(\.body) == ["prima", "seconda", "terza"])
        try fixture.archive.updateNote(late.id) {
            $0.body = "zero"
            $0.notedAt = base
        }
        try fixture.archive.deleteNote(middle.id)
        #expect(try fixture.archive.notes(itemID: item.id).map(\.body) == ["zero", "prima"])
        let deleted = try fixture.archive.database.writer.read { db in try Note.fetchOne(db, key: middle.id) }
        #expect(deleted?.body == "" && deleted?.deletedAt != nil)
        _ = early
    }

    @Test func assetsAreEncryptedAndVerified() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        let asset = try fixture.archive.storeAsset(
            try fixture.plainFile("audio segreto"), itemID: item.id, kind: .audioMic, fileName: "mic.m4a")
        #expect(asset.relPath == "\(item.id)/mic.m4a.enc")
        let raw = try Data(contentsOf: fixture.archive.url(of: asset))
        #expect(raw.range(of: Data("segreto".utf8)) == nil)
        #expect(try fixture.archive.readAssetData(asset) == Data("audio segreto".utf8))

        // Storing the same kind again replaces the asset (re-transcription).
        let again = try fixture.archive.storeAsset(
            Data("{}".utf8), itemID: item.id, kind: .audioMic, fileName: "mic.m4a")
        #expect(again.id == asset.id)
        #expect(try fixture.archive.assets(itemID: item.id).count == 1)
    }

    @Test func trashedItemIsHiddenAndRestorable() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        try fixture.archive.trashItem(item.id)
        #expect(try fixture.archive.items().isEmpty)
        #expect(try fixture.archive.trashedItems().map(\.id) == [item.id])
        try fixture.archive.restoreItem(item.id)
        #expect(try fixture.archive.items().map(\.id) == [item.id])
    }

    @Test func purgeShredsKeyFilesAndText() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem("Riunione riservata")
        let asset = try fixture.archive.storeAsset(
            Data("testo".utf8), itemID: item.id, kind: .transcriptJSON, fileName: "transcript.json")
        let encryptedCopy = fixture.root.appendingPathComponent("backup.enc")
        try FileManager.default.copyItem(at: fixture.archive.url(of: asset), to: encryptedCopy)
        try fixture.archive.addNote(itemID: item.id, body: "nota")
        try fixture.archive.addMarker(itemID: item.id, atSec: 12, note: "decisione")
        try fixture.archive.setTags(["cliente"], for: item.id)

        try fixture.archive.purgeItem(item.id)

        #expect(try fixture.archive.item(item.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: fixture.archive.itemsRoot.appendingPathComponent(item.id).path))
        #expect(throws: ArchiveError.keyDeleted(item.id)) { try fixture.archive.itemKey(item.id) }
        let tombstone = try fixture.archive.database.writer.read { db in try Item.fetchOne(db, key: item.id) }
        #expect(tombstone?.title == "" && tombstone?.deletedAt != nil)
        let texts = try fixture.archive.database.writer.read { db in
            try String.fetchAll(db, sql: "SELECT body FROM note UNION ALL SELECT coalesce(note, '') FROM marker")
        }
        #expect(texts.allSatisfy { $0.isEmpty })
        #expect(try fixture.archive.tags(for: item.id).isEmpty)
        // A leftover encrypted copy (e.g. a backup) can no longer be opened: its key is gone.
        #expect(throws: ArchiveError.keyDeleted(item.id)) {
            try EncryptedFile.decryptData(
                encryptedCopy, key: try fixture.archive.itemKey(item.id), context: asset.relPath)
        }
    }

    @Test func purgeCanMoveNotesToProject() throws {
        let fixture = try ArchiveFixture()
        let project = try fixture.archive.createProject(name: "Alfa")
        let item = try fixture.makeItem()
        try fixture.archive.updateItem(item.id) { $0.projectId = project.id }
        let note = try fixture.archive.addNote(itemID: item.id, body: "da tenere")
        try fixture.archive.purgeItem(item.id, notes: .moveToProject)
        let moved = try fixture.archive.database.writer.read { db in try Note.fetchOne(db, key: note.id) }
        #expect(
            moved?.itemId == nil && moved?.projectId == project.id && moved?.body == "da tenere"
                && moved?.deletedAt == nil)
    }

    @Test func expiredTrashIsPurgedAfterThirtyDays() throws {
        let fixture = try ArchiveFixture()
        let old = try fixture.makeItem("vecchio")
        let kept = try fixture.makeItem("tenuto")
        let asset = try fixture.archive.storeAsset(
            Data("x".utf8), itemID: kept.id, kind: .audioMix, fileName: "mix.m4a")
        try fixture.archive.trashItem(old.id)
        fixture.clock.advance(days: 10)
        try fixture.archive.trashAsset(asset.id)

        fixture.clock.advance(days: 19.9)
        #expect(try fixture.archive.purgeExpiredTrash() == 0)
        fixture.clock.advance(days: 0.2)
        #expect(try fixture.archive.purgeExpiredTrash() == 1)
        #expect(try fixture.archive.item(old.id) == nil)
        #expect(try fixture.archive.trashedAssets().map(\.id) == [asset.id])
        fixture.clock.advance(days: 10)
        #expect(try fixture.archive.purgeExpiredTrash() == 1)
        #expect(!FileManager.default.fileExists(atPath: fixture.archive.url(of: asset).path))
        #expect(try fixture.archive.item(kept.id) != nil)
    }

    @Test func emptyTrashPurgesEverythingInIt() throws {
        let fixture = try ArchiveFixture()
        let a = try fixture.makeItem()
        let b = try fixture.makeItem()
        try fixture.archive.trashItem(a.id)
        try fixture.archive.emptyTrash()
        #expect(try fixture.archive.trashedItems().isEmpty)
        #expect(try fixture.archive.items().map(\.id) == [b.id])
    }

    @Test func speakersKeepUserLabels() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        try fixture.archive.setSpeakers([("me", "Io"), ("s1", "Speaker 1")], for: item.id)
        try fixture.archive.renameSpeaker("s1", of: item.id, to: "Mario Rossi")
        try fixture.archive.setSpeakers([("me", "Io"), ("s1", "Speaker 1"), ("s2", "Speaker 2")], for: item.id)
        #expect(
            try fixture.archive.speakers(itemID: item.id).map(\.label).sorted() == ["Io", "Mario Rossi", "Speaker 2"])
    }

    @Test func fileDatabaseUsesWALAndSecureDelete() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("iago-\(UUID().uuidString)/iago.sqlite")
        let database = try AppDatabase.open(at: url)
        let (mode, secure) = try database.writer.read { db in
            (try String.fetchOne(db, sql: "PRAGMA journal_mode"), try Int.fetchOne(db, sql: "PRAGMA secure_delete"))
        }
        #expect(mode == "wal")
        #expect(secure == 1)
    }

    @Test func auditLogRecordsActions() throws {
        let fixture = try ArchiveFixture()
        try fixture.archive.audit(.modelDownload, action: "download", detail: "ggml-large-v3-turbo.bin")
        #expect(try fixture.archive.auditEntries().map(\.actor) == ["model_download"])
    }
}

@Suite struct LibraryTests {
    @Test func scopesFilterItems() throws {
        let fixture = try ArchiveFixture()
        let project = try fixture.archive.createProject(name: "Alfa")
        let a = try fixture.makeItem("a")
        let b = try fixture.makeItem("b")
        let c = try fixture.makeItem("c")
        try fixture.archive.updateItem(a.id) { $0.projectId = project.id }
        try fixture.archive.setTags(["roadmap"], for: b.id)
        try fixture.archive.trashItem(c.id)
        try fixture.archive.storeAsset(Data("x".utf8), itemID: a.id, kind: .audioMix, fileName: "mix.m4a")

        #expect(Set(try fixture.archive.summaries(.recent).map(\.item.title)) == ["a", "b"])
        #expect(try fixture.archive.summaries(.unclassified).map(\.item.title) == ["b"])  // a has a project
        let inProject = try fixture.archive.summaries(.project(project.id))
        #expect(inProject.map(\.projectName) == ["Alfa"])
        #expect(inProject.first?.hasAudio == true && inProject.first?.hasTranscript == false)
        let tag = try fixture.archive.allTags()[0]
        #expect(try fixture.archive.summaries(.tag(tag.id)).map(\.tags) == [["roadmap"]])
    }
}

@Suite struct ProjectNameMatcherTests {
    @Test(arguments: [
        ("Progetto Alfa", "progetto alfa"), ("Progetto Alfa", "Progeto Alfa"), ("Progetto Alfa", "Progetto Alfa-Nord"),
        ("Progeto Alfa", "Progetto Alfa Nord"), ("Portale Clienti", "portale-clienti"), ("Città Studi", "Citta studi"),
    ])
    func similarNames(a: String, b: String) {
        #expect(ProjectNameMatcher.isSimilar(a, b))
    }

    @Test(arguments: [
        ("Cliente Uno", "Fornitore Due"), ("Alfa", "Beta"), ("Portale Clienti", "App Interna"), ("SAL", "Sales"),
    ])
    func differentNames(a: String, b: String) {
        #expect(!ProjectNameMatcher.isSimilar(a, b))
    }
}

@Suite struct DiscardTests {
    @Test func discardedRecordingIsPurgedAfterOneHour() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        let trashed = try fixture.makeItem()
        try fixture.archive.discardItem(item.id)
        try fixture.archive.trashItem(trashed.id)
        #expect(try fixture.archive.discardedItems().map(\.id) == [item.id])
        #expect(try fixture.archive.trashedItems().map(\.id) == [trashed.id])
        #expect(try fixture.archive.items().isEmpty)

        fixture.clock.advance(days: 50.0 / 1440)
        #expect(try fixture.archive.purgeExpiredTrash() == 0)
        fixture.clock.advance(days: 11.0 / 1440)
        #expect(try fixture.archive.purgeExpiredTrash() == 1)
        #expect(try fixture.archive.item(item.id) == nil)
        #expect(try fixture.archive.trashedItems().map(\.id) == [trashed.id])
    }

    @Test func discardedRecordingCanBeRestored() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        try fixture.archive.discardItem(item.id)
        try fixture.archive.restoreItem(item.id)
        #expect(try fixture.archive.items().map(\.id) == [item.id])
        #expect(try fixture.archive.item(item.id)?.trashReason == nil)
    }
}

@Suite struct ProjectOrderTests {
    @Test func pinnedFirstThenMostRecentlyUsed() throws {
        let fixture = try ArchiveFixture()
        let a = try fixture.archive.createProject(name: "Alfa")
        let b = try fixture.archive.createProject(name: "Beta")
        let c = try fixture.archive.createProject(name: "Gamma")
        try fixture.archive.touchProject(a.id)
        fixture.clock.advance(days: 1)
        try fixture.archive.touchProject(b.id)
        try fixture.archive.setProjectPinned(c.id, true)
        #expect(try fixture.archive.projects().map(\.name) == ["Gamma", "Beta", "Alfa"])
    }
}

@Suite struct AttachmentTests {
    @Test func noteAttachmentsAreKeptApartAndDeletedWithTheNote() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        let note = try fixture.archive.addNote(itemID: item.id, body: "gantt")
        let a = try fixture.archive.storeAttachment(
            try fixture.plainFile("png"), itemID: item.id, noteID: note.id, originalName: "gantt.png")
        try fixture.archive.storeAttachment(
            try fixture.plainFile("pdf"), itemID: item.id, noteID: note.id, originalName: "offerta.pdf")
        #expect(try fixture.archive.attachments(noteID: note.id).map(\.originalName) == ["gantt.png", "offerta.pdf"])
        #expect(try fixture.archive.assets(itemID: item.id).isEmpty)
        #expect(try fixture.archive.readAssetData(a) == Data("png".utf8))

        try fixture.archive.deleteNote(note.id)
        #expect(try fixture.archive.attachments(noteID: note.id).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fixture.archive.url(of: a).path))
    }
}

@Suite struct CreateTagTests {
    @Test func createTagReusesNormalizedName() throws {
        let fixture = try ArchiveFixture()
        let a = try fixture.archive.createTag(name: "Design System")
        let b = try fixture.archive.createTag(name: "design  system ")
        #expect(a.id == b.id)
        #expect(try fixture.archive.allTags().count == 1)
    }
}

@Suite struct ProjectManagementTests {
    @Test func renameKeepsItemsAndArchiveHidesProject() throws {
        let fixture = try ArchiveFixture()
        let project = try fixture.archive.createProject(name: "Progetto Alfa")
        let item = try fixture.makeItem()
        try fixture.archive.updateItem(item.id) { $0.projectId = project.id }
        try fixture.archive.renameProject(project.id, to: "Progetto Alfa Nord")
        #expect(try fixture.archive.summaries(.project(project.id)).map(\.projectName) == ["Progetto Alfa Nord"])
        try fixture.archive.setProjectArchived(project.id, true)
        #expect(try fixture.archive.projects().isEmpty)
        #expect(try fixture.archive.projects(includeArchived: true).map(\.archived) == [true])
        #expect(try fixture.archive.summaries(.project(project.id)).count == 1)
    }

    @Test func undefinedProjectHoldsClassifiedItemsWithoutProject() throws {
        let fixture = try ArchiveFixture()
        let category = try fixture.archive.categories()[0]
        let a = try fixture.makeItem("classificato")
        _ = try fixture.makeItem("da classificare")
        try fixture.archive.updateItem(a.id) { $0.categoryId = category.id }
        #expect(try fixture.archive.summaries(.undefinedProject).map(\.item.title) == ["classificato"])
        #expect(
            Set(try fixture.archive.summaries(.unclassified).map(\.item.title)) == ["classificato", "da classificare"])
    }

    @Test func deleteProjectDestroysEverythingInIt() throws {
        let fixture = try ArchiveFixture()
        let project = try fixture.archive.createProject(name: "Alfa")
        let other = try fixture.makeItem("fuori")
        let item = try fixture.makeItem("dentro")
        try fixture.archive.updateItem(item.id) { $0.projectId = project.id }
        try fixture.archive.storeAsset(
            Data("{}".utf8), itemID: item.id, kind: .transcriptJSON, fileName: "transcript.json")
        try fixture.archive.addNote(itemID: item.id, body: "nota")
        try fixture.archive.addNote(itemID: nil, projectID: project.id, body: "nota di progetto")
        #expect(try fixture.archive.projectStats(project.id) == .init(items: 1, transcripts: 1, notes: 2))

        try fixture.archive.deleteProject(project.id)

        #expect(try fixture.archive.items().map(\.id) == [other.id])
        #expect(try fixture.archive.projects(includeArchived: true).isEmpty)
        #expect(try fixture.archive.projectStats(project.id) == .init(items: 0, transcripts: 0, notes: 0))
        #expect(!FileManager.default.fileExists(atPath: fixture.archive.itemsRoot.appendingPathComponent(item.id).path))
    }
}
