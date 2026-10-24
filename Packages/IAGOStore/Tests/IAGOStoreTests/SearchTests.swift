import Foundation
import IAGOCore
import Testing

@testable import IAGOStore

@Suite struct SearchTests {
    func transcript(_ itemID: String, _ lines: [(Double, String)]) -> Transcript {
        Transcript(
            itemId: itemID, engine: .init(asr: "test", model: "x"), language: "it",
            speakers: [.init(id: "s1", label: "Mario", source: .system)],
            segments: lines.enumerated().map {
                .init(id: $0 + 1, speaker: "s1", start: $1.0, end: $1.0 + 2, text: $1.1)
            })
    }

    @Test func findsTranscriptPassagesIgnoringAccentsAndCase() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        try fixture.archive.indexTranscript(
            transcript(item.id, [(12, "Il budget è approvato"), (40, "Parliamo della città")]), itemID: item.id)
        let hits = try fixture.archive.search("citta")
        #expect(hits.map(\.atSec) == [40])
        #expect(hits.first?.snippet.contains("«città»") == true)
        #expect(try fixture.archive.search("BUDG").map(\.atSec) == [12])  // prefix
        #expect(try fixture.archive.search("budget città").isEmpty)  // every word in the same passage
    }

    @Test func notesAndDocumentsAreIndexedAndUpdated() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        let note = try fixture.archive.addNote(itemID: item.id, body: "Chiamare il fornitore")
        #expect(try fixture.archive.search("fornitore").map(\.source) == [.note])
        try fixture.archive.updateNote(note.id) { $0.body = "Chiamare il cliente" }
        #expect(try fixture.archive.search("fornitore").isEmpty)
        try fixture.archive.deleteNote(note.id)
        #expect(try fixture.archive.search("cliente").isEmpty)

        let doc = try fixture.archive.importDocument(
            try fixture.plainFile("x"), isImage: false, markdown: "# Offerta\n\nPrezzo concordato 12.000 euro",
            title: "Offerta",
            occurredAt: Date())
        #expect(try fixture.archive.search("prezzo").map(\.itemID) == [doc.id])
    }

    @Test func trashAndPurgeRemoveResults() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        try fixture.archive.indexTranscript(transcript(item.id, [(0, "roadmap del trimestre")]), itemID: item.id)
        try fixture.archive.trashItem(item.id)
        #expect(try fixture.archive.search("roadmap").isEmpty)
        try fixture.archive.restoreItem(item.id)
        #expect(try fixture.archive.search("roadmap").count == 1)
        try fixture.archive.purgeItem(item.id)
        #expect(
            try fixture.archive.database.writer.read { db in
                try Int.fetchOne(db, sql: "SELECT count(*) FROM search_index")
            } == 0)
    }

    @Test func projectFilterFollowsTheItem() throws {
        let fixture = try ArchiveFixture()
        let project = try fixture.archive.createProject(name: "Alfa")
        let item = try fixture.makeItem()
        try fixture.archive.indexTranscript(transcript(item.id, [(0, "consegna venerdì")]), itemID: item.id)
        #expect(try fixture.archive.search("consegna", scope: .project(project.id)).isEmpty)
        try fixture.archive.updateItem(item.id) { $0.projectId = project.id }
        #expect(try fixture.archive.search("consegna", scope: .project(project.id)).count == 1)
    }

    @Test func queryWithSymbolsDoesNotBreakFTS() throws {
        let fixture = try ArchiveFixture()
        #expect(try fixture.archive.search("\"AND* (NEAR").isEmpty)
        #expect(try fixture.archive.search("   ").isEmpty)
    }
}

@Suite struct EditableMarkdownTests {
    @Test func correctedTextKeepsTheAutomaticOneAndCanGoBack() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let doc = try archive.importDocument(
            try fixture.plainFile("x"), isImage: false, markdown: "Prezo concordato 12.000", title: "Offerta",
            occurredAt: Date())
        try archive.updateContentMarkdown("Prezzo concordato 12.000", itemID: doc.id)
        let kinds = try archive.assets(itemID: doc.id).map(\.kind)
        #expect(kinds.contains(.contentMDAuto))
        #expect(try archive.search("prezzo").count == 1)
        #expect(try archive.search("prezo").isEmpty)
        // A second correction keeps the first automatic version.
        try archive.updateContentMarkdown("Prezzo finale 11.500", itemID: doc.id)
        let auto = try #require(try archive.assets(itemID: doc.id).first { $0.kind == .contentMDAuto })
        #expect(String(decoding: try archive.readAssetData(auto), as: UTF8.self) == "Prezo concordato 12.000")
        try archive.restoreAutomaticMarkdown(itemID: doc.id)
        let content = try #require(try archive.assets(itemID: doc.id).first { $0.kind == .contentMD })
        #expect(String(decoding: try archive.readAssetData(content), as: UTF8.self) == "Prezo concordato 12.000")
        #expect(try !archive.assets(itemID: doc.id).map(\.kind).contains(.contentMDAuto))
    }
}
