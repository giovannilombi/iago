import Foundation
import Testing

@testable import IAGOStore

@Suite struct HierarchyTests {
    @Test func clientsGroupProjectsAndSurviveDeletion() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let client = try archive.createClient(name: " Ospedalia ")
        #expect(client.name == "Ospedalia")
        let portale = try archive.createProject(name: "Portale")
        let app = try archive.createProject(name: "App")
        let other = try archive.createProject(name: "Altro")
        try archive.setProjectClient(portale.id, client.id)
        try archive.setProjectClient(app.id, client.id)
        let a = try fixture.makeItem("Kickoff")
        let b = try fixture.makeItem("Demo")
        let c = try fixture.makeItem("Fuori")
        try archive.updateItem(a.id) { $0.projectId = portale.id }
        try archive.updateItem(b.id) { $0.projectId = app.id }
        try archive.updateItem(c.id) { $0.projectId = other.id }
        #expect(Set(try archive.summaries(.client(client.id)).map(\.id)) == [a.id, b.id])

        try archive.deleteClient(client.id)
        #expect(try archive.clients().isEmpty)
        #expect(try archive.projects().count == 3)
        #expect(try archive.projects().allSatisfy { $0.clientId == nil })
        #expect(try archive.summaries(.client(client.id)).isEmpty)
    }

    @Test func itemsAndDecisionsInSeveralStreams() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let design = try archive.createStream(projectID: project.id, name: "Design")
        let dev = try archive.createStream(projectID: project.id, name: "Sviluppo")
        let foreign = try archive.createStream(projectID: try archive.createProject(name: "B").id, name: "Legale")
        #expect(design.color != dev.color)
        let item = try fixture.makeItem()
        try archive.updateItem(item.id) { $0.projectId = project.id }
        try archive.setStreams([design.id, dev.id, foreign.id], itemID: item.id)
        #expect(Set(try archive.streamIDs(itemID: item.id)) == [design.id, dev.id])  // foreign ignored
        #expect(try archive.summaries(.stream(design.id)).map(\.id) == [item.id])
        #expect(Set(try archive.summaries(.project(project.id)).first?.streamIDs ?? []) == [design.id, dev.id])

        let decision = try archive.createDecision(
            Decision(
                text: "Palette approvata", decidedAt: Date(), projectId: project.id, sourceItemId: item.id,
                origin: .selection), streams: [design.id])
        #expect(try archive.decisions(DecisionQuery(scope: .stream(design.id))).map(\.id) == [decision.id])
        #expect(try archive.decisions(DecisionQuery(scope: .stream(dev.id))).isEmpty)
        #expect(try archive.search("palette", scope: .stream(design.id)).count == 1)
        #expect(try archive.search("palette", scope: .stream(dev.id)).isEmpty)

        // Deleting a stream only removes the label.
        try archive.deleteStream(dev.id)
        #expect(try archive.streamIDs(itemID: item.id) == [design.id])
        #expect(try archive.streams(projectID: project.id).map(\.name) == ["Design"])
    }

    @Test func movingToAnotherProjectDropsItsStreams() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let alfa = try archive.createProject(name: "Alfa")
        let beta = try archive.createProject(name: "Beta")
        let stream = try archive.createStream(projectID: alfa.id, name: "Design")
        let item = try fixture.makeItem()
        try archive.updateItem(item.id) { $0.projectId = alfa.id }
        try archive.setStreams([stream.id], itemID: item.id)
        let decision = try archive.createDecision(
            Decision(
                text: "Logo blu", decidedAt: Date(), projectId: alfa.id, sourceItemId: item.id, origin: .selection),
            streams: [stream.id])
        try archive.updateItem(item.id) { $0.projectId = beta.id }
        #expect(try archive.streamIDs(itemID: item.id).isEmpty)
        #expect(try archive.decisionSummary(decision.id)?.streamIDs.isEmpty == true)
    }

    @Test func searchByClientAndDeletingProjectRemovesStreams() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let client = try archive.createClient(name: "Enel")
        let project = try archive.createProject(name: "Rete")
        try archive.setProjectClient(project.id, client.id)
        let item = try fixture.makeItem()
        try archive.updateItem(item.id) { $0.projectId = project.id }
        try archive.addNote(itemID: item.id, body: "Cabina primaria da rifare")
        #expect(try archive.search("cabina", scope: .client(client.id)).count == 1)
        #expect(try archive.search("cabina", scope: .client("altro")).isEmpty)
        try archive.createStream(projectID: project.id, name: "Cantiere")
        try archive.deleteProject(project.id)
        #expect(try archive.streams().isEmpty)
    }
}
