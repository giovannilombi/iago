import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOIntelligence

@Suite struct StatusReportTests {
    func archive() throws -> Archive {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-status-\(UUID().uuidString)")
        return try Archive(
            database: try AppDatabase.inMemory(), itemsRoot: root.appendingPathComponent("Items"),
            keyStore: EphemeralMasterKeyStore())
    }

    @Test func factsKeepOpenWorkAndRecentMemoryWithTheirDetails() throws {
        let archive = try archive()
        let project = try archive.createProject(name: "Portale")
        let now = Date()
        let calendar = Calendar.current
        let old = calendar.date(byAdding: .day, value: -90, to: now)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let owner = try #require(try archive.person(named: "Marco Neri"))
        var late = Decision(text: "Preventivo", decidedAt: old, projectId: project.id, origin: .manual, kind: .action)
        late.ownerId = owner.id
        late.dueAt = yesterday
        try archive.createDecision(late)
        var risk = Decision(
            text: "Fornitore lento", decidedAt: now, projectId: project.id, origin: .manual, kind: .risk)
        risk.severity = .high
        try archive.createDecision(risk)
        try archive.createDecision(
            Decision(text: "Vecchia decisione", decidedAt: old, projectId: project.id, origin: .manual))
        try archive.createDecision(
            Decision(text: "Usiamo il cloud", decidedAt: now, projectId: project.id, origin: .manual))

        let entries = try archive.decisions(DecisionQuery(scope: .project(project.id), statuses: []))
        let facts = StatusReport.facts(entries, now: now)
        #expect(facts.map(\.number) == [1, 2, 3])
        #expect(facts[0].line.hasPrefix("Attività · da fare · responsabile Marco Neri · scadenza"))
        #expect(facts[0].line.contains("(in ritardo)"))
        #expect(facts[0].line.hasSuffix(": Preventivo"))
        #expect(facts.contains { $0.line.hasPrefix("Rischio · da fare · gravità alta") })
        #expect(facts.contains { $0.line.hasSuffix(": Usiamo il cloud") })
        #expect(!facts.contains { $0.line.contains("Vecchia decisione") })
    }

    @Test func linesWithoutExistingFactsAreDroppedAndNumbersRemoved() {
        let facts = [StatusReport.Fact(number: 1, line: "a"), StatusReport.Fact(number: 2, line: "b")]
        let answer = """
            <think>ragiono</think>
            **In breve**
            - Il progetto procede [1]
            Avanzamento
            - Consegna confermata [1, 2]
            - Firmato il contratto con Acme [7]
            Rischi e punti aperti
            - Tutto bene
            Prossimi passi
            - Chiudere il preventivo [2]
            """
        let result = StatusReport.verify(answer, facts: facts)
        #expect(result.dropped == ["- Firmato il contratto con Acme [7]", "- Tutto bene"])
        #expect(
            result.text == """
                In breve
                - Il progetto procede

                Avanzamento
                - Consegna confermata

                Prossimi passi
                - Chiudere il preventivo
                """)
        #expect(result.cited.contains("- Consegna confermata [1, 2]"))
    }

    @Test func theEngineIsAskedOnlyWithTheFacts() async throws {
        let engine = FakeEngine { _ in "In breve\n- Va tutto secondo i piani [1]" }
        let facts = [StatusReport.Fact(number: 1, line: "Tappa · valida · del 3 nov 2026: Kickoff")]
        let result = try await StatusReport.generate(scopeName: "Portale", facts: facts, now: Date(), with: engine)
        #expect(result.text == "In breve\n- Va tutto secondo i piani")
        #expect(engine.requests.first?.prompt.contains("[1] Tappa · valida · del 3 nov 2026: Kickoff") == true)
        #expect(engine.requests.first?.system.contains("«Portale»") == true)
    }
}
