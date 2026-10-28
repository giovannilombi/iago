import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOMCP

/// Open work through Claude (ADR-0074): new kinds, states and fields in add_decision, update_decision and
/// list_decisions, with the same preview and undo as before.
extension IAGOToolsTests {
    @Test func claudeWritesOpenWorkWithOwnerDueDateChecklistAndLinks() throws {
        let fixture = try Fixture()
        let clock = Clock()
        let (tools, project, _) = try writable(fixture, clock: clock)
        let app = fixture.app
        _ = try app.person(named: "Marco Bianchi")
        func entry(_ text: String) throws -> DecisionSummary {
            try #require(try app.decisions(DecisionQuery(statuses: [])).first { $0.decision.text == text })
        }

        _ = try write(tools, "add_decision", arguments: ["text": "Login SSO", "kind": "request"])
        let request = try entry("Login SSO")
        #expect(request.decision.kind == .request)

        // The preview names known and new people, and asks about similar names.
        let preview = try tools.call(
            "add_decision",
            arguments: [
                "text": "Preventivo SSO", "kind": "action", "owner": "Marco Bianchi", "waiting_on": "Marco Bianci",
            ])
        #expect(preview.contains("Responsabile: Marco Bianchi"))
        #expect(preview.contains("In attesa di: Marco Bianci (persona nuova in IAGO)"))
        #expect(preview.contains("se intende «Marco Bianchi»"))
        #expect(!(try app.people().contains { $0.name == "Marco Bianci" }))  // the preview created nobody

        let arguments: JSON = [
            "text": "Preventivo SSO", "kind": "action", "status": "waiting", "owner": "Marco Bianchi",
            "due": "2026-11-10", "waiting_on": "Anna Verdi", "waiting_until": "2026-11-05", "priority": "high",
            "derived_from_id": .string(request.id), "checklist": ["Raccogliere i requisiti", "[x] Bozza"],
        ]
        let reply = try write(tools, "add_decision", arguments: arguments)
        #expect(reply.contains("Attività registrata"))
        let task = try entry("Preventivo SSO")
        #expect(task.decision.status == .waiting && task.decision.priority == 1)
        #expect(task.ownerName == "Marco Bianchi" && task.waitingOnName == "Anna Verdi")
        #expect(task.derivedFrom?.id == request.id)
        #expect(task.checklist == (1, 2))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let due = calendar.dateComponents([.year, .month, .day], from: try #require(task.decision.dueAt))
        #expect([due.year, due.month, due.day] == [2026, 11, 10])

        // Work fields do not fit memory kinds or the wrong kind; outcomes come only when closing.
        #expect(throws: ToolError.self) {
            try tools.call("add_decision", arguments: ["text": "Usiamo Azure", "owner": "Marco Bianchi"])
        }
        #expect(throws: ToolError.self) {
            try tools.call("add_decision", arguments: ["text": "Preparare", "kind": "action", "severity": "high"])
        }
        #expect(throws: ToolError.self) {
            try tools.call("add_decision", arguments: ["text": "Chi?", "kind": "open_question", "outcome": "Io"])
        }
        #expect(throws: ToolError.self) {
            try tools.call("add_decision", arguments: ["text": "Preparare", "kind": "action", "due": "10/11/2026"])
        }

        _ = try write(
            tools, "add_decision", arguments: ["text": "Ritardo fornitore", "kind": "risk", "severity": "high"])
        let risk = try entry("Ritardo fornitore")
        #expect(risk.decision.severity == .high)

        // Dependencies and checklist replaced; undo puts everything back.
        let update: JSON = [
            "decision_id": .string(task.id), "status": "in_progress", "blocked_by_ids": [.string(risk.id)],
            "checklist": ["Bozza", "Inviare il documento"], "due": "",
        ]
        let updatePreview = try tools.call("update_decision", arguments: update)
        #expect(
            updatePreview.contains("Dipende da: «Ritardo fornitore» (finché una è aperta la voce risulta Bloccata)"))
        #expect(updatePreview.contains("Checklist: ☑ Bozza; ☐ Inviare il documento"))
        #expect(updatePreview.contains("Scadenza: tolta"))
        _ = try write(tools, "update_decision", arguments: update)
        var changed = try entry("Preventivo SSO")
        #expect(changed.decision.status == .blocked)
        #expect(changed.blockers.map(\.id) == [risk.id])
        #expect(changed.checklist == (1, 2) && changed.decision.dueAt == nil)
        #expect(try app.checklistItems(decisionID: task.id).map(\.text) == ["Bozza", "Inviare il documento"])
        #expect(throws: ToolError.self) {
            try tools.call(
                "update_decision", arguments: ["decision_id": .string(risk.id), "blocked_by_ids": [.string(task.id)]])
        }

        try app.undoMCPChange(try #require(try app.mcpChanges().first?.id))
        changed = try entry("Preventivo SSO")
        #expect(changed.decision.status == .waiting && changed.blockers.isEmpty)
        #expect(changed.decision.dueAt == task.decision.dueAt)
        #expect(try app.checklistItems(decisionID: task.id).map(\.text) == ["Raccogliere i requisiti", "Bozza"])

        // list_decisions: open work, by owner, with ids and details.
        let open = try tools.call("list_decisions", arguments: ["status": "open", "kind": "work"])
        #expect(open.contains("[Richiesta · Aperta]") && open.contains("[Rischio · alta · Aperto]"))
        #expect(open.contains("decision_id `\(task.id)`"))
        #expect(open.contains("responsabile: Marco Bianchi") && open.contains("nata da: «Login SSO»"))
        #expect(open.contains("  - ☑ Bozza"))
        let mine = try tools.call("list_decisions", arguments: ["owner": "Marco Bianchi"])
        #expect(mine.contains("Preventivo SSO") && !mine.contains("Ritardo fornitore"))
        #expect(try tools.call("list_decisions", arguments: ["owner": "Nessuno"]).contains("Nessuna persona"))
        _ = project
    }

    @Test func claudeClosesWorkWithAnOutcomeAndUndoReopensIt() throws {
        let fixture = try Fixture()
        let clock = Clock()
        let (tools, _, _) = try writable(fixture, clock: clock)
        let app = fixture.app
        _ = try write(tools, "add_decision", arguments: ["text": "Quale provider SSO?", "kind": "open_question"])
        let question = try #require(try app.decisions().first { $0.decision.kind == .openQuestion })

        #expect(throws: ToolError.self) {
            try tools.call(
                "update_decision", arguments: ["decision_id": .string(question.id), "outcome_kind": "accepted"])
        }
        let closing: JSON = [
            "decision_id": .string(question.id), "outcome_kind": "answered", "outcome": "Usiamo Azure AD",
        ]
        let preview = try tools.call("update_decision", arguments: closing)
        #expect(preview.contains("Stato: done (Chiarito)") && preview.contains("Esito: Chiarito"))
        _ = try write(tools, "update_decision", arguments: closing)
        let closed = try #require(try app.decision(question.id))
        #expect(closed.status == .done && closed.outcomeKind == .answered && closed.outcome == "Usiamo Azure AD")
        let listed = try tools.call("list_decisions", arguments: ["kind": "open_question", "status": "done"])
        #expect(
            listed.contains("[Punto da chiarire · Chiarito]")
                && listed.contains("Quale provider SSO? → Usiamo Azure AD"))

        try app.undoMCPChange(try #require(try app.mcpChanges().first?.id))
        let reopened = try #require(try app.decision(question.id))
        #expect(reopened.status == .active && reopened.outcomeKind == nil && reopened.outcome == nil)

        // A request turned into an activity: the kind changes, undo brings it back.
        _ = try write(tools, "add_decision", arguments: ["text": "Report mensile", "kind": "request"])
        let request = try #require(try app.decisions().first { $0.decision.kind == .request })
        _ = try write(tools, "update_decision", arguments: ["decision_id": .string(request.id), "kind": "activity"])
        #expect(try app.decision(request.id)?.kind == .action)
        try app.undoMCPChange(try #require(try app.mcpChanges().first?.id))
        #expect(try app.decision(request.id)?.kind == .request)
    }
}
