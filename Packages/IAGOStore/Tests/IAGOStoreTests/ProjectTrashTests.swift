import Foundation
import Testing

@testable import IAGOStore

/// ADR-0099: a project in the trash disappears everywhere, comes back as it was, and is deleted for good after
/// 30 days.
@Suite struct ProjectTrashTests {
    @Test func trashedProjectDisappearsAndComesBack() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let client = try archive.createClient(name: "Cliente Test")
        let project = try archive.createProject(name: "Portale")
        try archive.setProjectClient(project.id, client.id)
        let stream = try archive.createStream(projectID: project.id, name: "Design")
        let item = try fixture.makeItem("Kickoff")
        try archive.updateItem(item.id) { $0.projectId = project.id }
        let alreadyTrashed = try fixture.makeItem("Bozza")
        try archive.updateItem(alreadyTrashed.id) { $0.projectId = project.id }
        try archive.trashItem(alreadyTrashed.id)
        _ = try archive.addNote(itemID: nil, projectID: project.id, body: "Nota sulla palette")
        _ = try archive.createDecision(
            Decision(
                text: "Palette approvata", decidedAt: Date(), projectId: project.id, sourceItemId: item.id,
                origin: .selection), streams: [stream.id])
        _ = try archive.createChecklist(projectID: project.id, name: "Lancio")

        try archive.trashProject(project.id)
        #expect(try archive.projects(includeArchived: true).isEmpty)
        #expect(try archive.trashedProjects().map(\.id) == [project.id])
        #expect(try archive.summaries(.recent).isEmpty)
        #expect(try archive.summaries(.client(client.id)).isEmpty)
        // Its items are not listed one by one in the trash: they go with the project.
        #expect(try archive.trashedItems().map(\.id) == [alreadyTrashed.id])
        #expect(try archive.streams().isEmpty)
        #expect(try archive.decisions().isEmpty)
        #expect(try archive.checklists().isEmpty)
        #expect(try archive.search("palette").isEmpty)
        #expect(try archive.collectProjectCount() == 0)

        try archive.restoreProject(project.id)
        #expect(try archive.projects().map(\.id) == [project.id])
        #expect(try archive.projects().first?.clientId == client.id)
        #expect(try archive.trashedProjects().isEmpty)
        #expect(try archive.summaries(.project(project.id)).map(\.id) == [item.id])
        // An item trashed on its own stays in the trash.
        #expect(try archive.trashedItems().map(\.id) == [alreadyTrashed.id])
        #expect(try archive.streams().map(\.id) == [stream.id])
        #expect(try archive.decisions().count == 1)
        #expect(try archive.checklists().count == 1)
        #expect(try archive.search("palette").count == 2)
    }

    @Test func itemRestoredWhileItsProjectIsInTheTrashLosesTheProject() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let item = try fixture.makeItem("Bozza")
        try archive.updateItem(item.id) { $0.projectId = project.id }
        try archive.trashItem(item.id)
        try archive.trashProject(project.id)

        try archive.restoreItem(item.id)
        #expect(try archive.summaries(.unclassified).map(\.id) == [item.id])
        try archive.restoreProject(project.id)
        #expect(try archive.summaries(.project(project.id)).isEmpty)
    }

    @Test func projectComesBackWithoutAClientDeletedMeanwhile() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let client = try archive.createClient(name: "Cliente Test")
        let project = try archive.createProject(name: "Portale")
        try archive.setProjectClient(project.id, client.id)
        try archive.trashProject(project.id)
        try archive.deleteClient(client.id)
        try archive.restoreProject(project.id)
        #expect(try archive.projects().first?.clientId == nil)
    }

    @Test func trashedProjectIsDeletedForGoodAfterThirtyDays() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let item = try fixture.makeItem("Kickoff")
        try archive.updateItem(item.id) { $0.projectId = project.id }
        try archive.trashProject(project.id)

        fixture.clock.advance(days: 29.9)
        #expect(try archive.purgeExpiredTrash() == 0)
        #expect(try archive.trashedProjects().count == 1)
        fixture.clock.advance(days: 0.2)
        #expect(try archive.purgeExpiredTrash() == 1)
        #expect(try archive.trashedProjects().isEmpty)
        #expect(try archive.item(item.id) == nil)
    }

    @Test func emptyingTheTrashDeletesTrashedProjects() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let kept = try archive.createProject(name: "Tenuto")
        let project = try archive.createProject(name: "Portale")
        try archive.trashProject(project.id)
        try archive.emptyTrash()
        #expect(try archive.trashedProjects().isEmpty)
        #expect(try archive.projects().map(\.id) == [kept.id])
    }

    @Test func streamStatsCountWhatLosesTheLabel() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let stream = try archive.createStream(projectID: project.id, name: "Design")
        let item = try fixture.makeItem()
        try archive.updateItem(item.id) { $0.projectId = project.id }
        try archive.setStreams([stream.id], itemID: item.id)
        _ = try archive.addNote(itemID: nil, projectID: project.id, body: "Nota", streams: [stream.id])
        #expect(try archive.streamStats(stream.id) == Archive.StreamStats(items: 1, decisions: 0, notes: 1))
    }
}
