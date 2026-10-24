import Foundation
import Testing

@testable import IAGOStore

@Suite struct ProjectNotesTests {
    @Test func notesBelongToStreams() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let other = try archive.createProject(name: "Altro")
        let design = try archive.createStream(projectID: project.id, name: "Design")
        let foreign = try archive.createStream(projectID: other.id, name: "Legale")
        let note = try archive.addNote(
            itemID: nil, projectID: project.id, body: "Palette approvata", streams: [design.id, foreign.id])
        // Only streams of the note's project stick.
        #expect(try archive.streamIDs(noteID: note.id) == [design.id])
        #expect(try archive.notes(streamID: design.id, itemIDs: []).map(\.id) == [note.id])
        #expect(try archive.search("palette", scope: .stream(design.id)).map(\.source) == [.note])

        // An item note follows its item's project streams; the stream timeline also gets notes of its items.
        let item = try fixture.makeItem()
        try archive.updateItem(item.id) { $0.projectId = project.id }
        let itemNote = try archive.addNote(itemID: item.id, body: "Sulla call")
        try archive.setStreams([design.id], noteID: itemNote.id)
        #expect(try archive.streamIDs(noteID: itemNote.id) == [design.id])
        let plain = try archive.addNote(itemID: item.id, body: "Senza stream")
        #expect(
            Set(try archive.notes(streamID: design.id, itemIDs: [item.id]).map(\.id))
                == [note.id, itemNote.id, plain.id])

        try archive.deleteStream(design.id)
        #expect(try archive.streamIDs(noteID: note.id).isEmpty)
        try archive.deleteNote(itemNote.id)
        #expect(try archive.streamIDs(noteID: itemNote.id).isEmpty)
    }

    @Test func projectNotesWithEncryptedAttachments() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let note = try archive.addNote(
            itemID: nil, projectID: project.id, body: "Il cliente ha cambiato referente",
            notedAt: Date(timeIntervalSince1970: 5_000))
        #expect(try archive.notes(projectID: project.id).map(\.id) == [note.id])
        #expect(try archive.search("referente", scope: .project(project.id)).map(\.source) == [.note])

        let gantt = try fixture.plainFile("gantt")
        let asset = try archive.storeAttachment(gantt, ownerID: project.id, noteID: note.id, originalName: "gantt.png")
        #expect(try archive.attachments(noteID: note.id).map(\.id) == [asset.id])
        #expect(String(decoding: try archive.readAssetData(asset), as: UTF8.self) == "gantt")
        let file = archive.url(of: asset)
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(!(try Data(contentsOf: file)).contains(Data("gantt".utf8)))  // stored encrypted

        // The timeline gets project notes and notes of the project's items.
        let item = try fixture.makeItem()
        try archive.updateItem(item.id) { $0.projectId = project.id }
        let itemNote = try archive.addNote(itemID: item.id, body: "Nota sulla call")
        #expect(Set(try archive.notes(projectID: project.id, itemIDs: [item.id]).map(\.id)) == [note.id, itemNote.id])

        // Deleting the project shreds the project key and the attachment.
        try archive.deleteProject(project.id)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(throws: (any Error).self) { try archive.readAssetData(asset) }
        #expect(try archive.notes(projectID: project.id).isEmpty)
    }

    @Test func itemAttachmentsStillWorkAfterTheAssetRebuild() throws {
        let fixture = try ArchiveFixture()
        let item = try fixture.makeItem()
        let note = try fixture.archive.addNote(itemID: item.id, body: "x")
        let asset = try fixture.archive.storeAttachment(
            try fixture.plainFile("allegato"), itemID: item.id, noteID: note.id, originalName: "a.txt")
        #expect(String(decoding: try fixture.archive.readAssetData(asset), as: UTF8.self) == "allegato")
        try fixture.archive.deleteNote(note.id)
        #expect(try fixture.archive.attachments(noteID: note.id).isEmpty)
    }
}
