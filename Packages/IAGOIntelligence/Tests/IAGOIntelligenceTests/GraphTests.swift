import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOIntelligence

@Suite struct GraphTests {
    func archive() throws -> Archive {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-graph-\(UUID().uuidString)")
        return try Archive(
            database: try AppDatabase.inMemory(), itemsRoot: root.appendingPathComponent("Items"),
            keyStore: EphemeralMasterKeyStore())
    }

    @Test func projectionLinksItemsPeopleTagsDecisionsAndClients() throws {
        let archive = try archive()
        let client = try archive.createClient(name: "Poldo")
        let project = try archive.createProject(name: "Portale")
        let other = try archive.createProject(name: "Altro")
        try archive.setProjectClient(project.id, client.id)
        try archive.setUserEmailAddresses(["io@studio.it"])
        let t0 = Date(timeIntervalSince1970: 1_791_000_000)

        let call = try archive.createItem(
            title: "Kickoff", occurredAt: t0, source: .recording, status: .transcribed)
        try archive.setSpeakers([("me", "Io"), ("s1", "Mario Rossi"), ("s2", "Speaker 2")], for: call.id)
        try archive.setTags(["design"], for: call.id)
        let email = try archive.importEmail(
            EmailInput(
                from: .init(name: "Mario Rossi", address: "mario@poldo.it"),
                to: [.init(name: "Io", address: "io@studio.it")], subject: "Offerta",
                sentAt: t0.addingTimeInterval(86_400), bodyMarkdown: "Prezzo."), original: nil)
        let hidden = try archive.createItem(
            title: "Altrove", occurredAt: t0, source: .recording, status: .recorded)
        for id in [call.id, email.id] { try archive.updateItem(id) { $0.projectId = project.id } }
        try archive.updateItem(hidden.id) { $0.projectId = other.id }
        try archive.addLink(from: email.id, to: call.id, kind: .followUpOf, origin: .manual)
        let first = try archive.createDecision(
            Decision(
                text: "Logo blu", decidedAt: t0, projectId: project.id, sourceItemId: call.id, origin: .selection),
            people: ["Mario Rossi"])
        let second = try archive.createDecision(
            Decision(
                text: "Logo verde", decidedAt: t0.addingTimeInterval(2 * 86_400), projectId: project.id,
                supersedesId: first.id, origin: .manual))
        try archive.addNote(itemID: call.id, body: "Richiamare", notedAt: t0)

        let graph = try GraphBuilder.build(.project(project.id), archive: archive)
        #expect(graph.nodes["item:\(hidden.id)"] == nil)
        #expect(graph.nodes["client:\(client.id)"]?.kind == .client)
        // "Mario Rossi" is one person: the speaker, the email sender and the decision's person meet.
        let people = graph.nodes.values.filter { $0.kind == .person }
        #expect(people.map(\.label) == ["Mario Rossi"])
        let mario = try #require(people.first).id
        #expect(graph.neighbors(of: mario) == ["item:\(call.id)", "item:\(email.id)", "decision:\(first.id)"])
        #expect(graph.edges.contains(GraphEdge(from: "item:\(email.id)", to: "item:\(call.id)", kind: .linked)))
        #expect(
            graph.edges.contains(
                GraphEdge(from: "decision:\(second.id)", to: "decision:\(first.id)", kind: .supersedes)))
        #expect(graph.nodes["decision:\(first.id)"]?.inactive == true)
        #expect(graph.nodes.values.contains { $0.kind == .tag && $0.label == "#design" })
        #expect(graph.nodes.values.contains { $0.kind == .note })

        // As it was on day one: the email and the later decision did not exist yet.
        let early = graph.asOf(t0.addingTimeInterval(3_600))
        #expect(early.nodes["item:\(email.id)"] == nil && early.nodes["decision:\(second.id)"] == nil)
        #expect(early.nodes["item:\(call.id)"] != nil && early.nodes[mario] != nil)
    }

    @Test func largeGraphsDropNotesThenGroupOldItemsByMonth() {
        var nodes: [String: GraphNode] = [:]
        var edges: [GraphEdge] = []
        nodes["project:p"] = GraphNode(id: "project:p", kind: .project, label: "P")
        for index in 0..<20 {
            let id = "item:\(index)"
            nodes[id] = GraphNode(
                id: id, kind: .call, label: "\(index)", date: Date(timeIntervalSince1970: Double(index) * 86_400 * 20))
            edges.append(GraphEdge(from: id, to: "project:p", kind: .inProject))
            nodes["note:\(index)"] = GraphNode(id: "note:\(index)", kind: .note, label: "n", date: nil)
        }
        let graph = Graph(nodes: nodes, edges: edges)
        #expect(graph.limited(to: 30).nodes.values.allSatisfy { $0.kind != .note })
        let small = graph.limited(to: 10)
        #expect(small.nodes.count <= 10)
        #expect(small.nodes.values.contains { $0.kind == .group })
        #expect(small.edges.allSatisfy { small.nodes[$0.from] != nil && small.nodes[$0.to] != nil })
    }
}
