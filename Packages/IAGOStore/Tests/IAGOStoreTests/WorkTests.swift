import Foundation
import Testing

@testable import IAGOStore

@Suite struct WorkTests {
    func entry(
        _ archive: Archive, _ text: String, _ kind: Decision.Kind = .action, project: String? = nil,
        at date: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) throws -> Decision {
        try archive.createDecision(
            Decision(text: text, decidedAt: date, projectId: project, origin: .manual, kind: kind))
    }

    @Test func newKindsAndOpenStatesAreCurrentByDefault() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let question = try entry(archive, "Quale provider SSO?", .openQuestion)
        let risk = try entry(archive, "Ritardo fornitore", .risk)
        let request = try entry(archive, "Login SSO", .request)
        try archive.updateDecision(risk.id) { $0.status = .waiting }
        let ids = Set(try archive.decisions().map(\.id))
        #expect(ids == [question.id, risk.id, request.id])
    }

    @Test func closingStampsTheDateAndReopeningClearsIt() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let task = try entry(archive, "Inviare il preventivo")
        #expect(task.closedAt == nil)
        let done = try archive.updateDecision(task.id) { $0.status = .done }
        #expect(done.closedAt != nil)
        let reopened = try archive.updateDecision(task.id) { $0.status = .inProgress }
        #expect(reopened.closedAt == nil)
    }

    @Test func aDecisionAnsweringAQuestionClosesItAndUnlinkingReopensIt() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let question = try entry(archive, "Quale provider SSO?", .openQuestion)
        let answer = try archive.createDecision(
            Decision(text: "Usiamo Azure AD", decidedAt: Date(), origin: .manual), supersedes: [question.id])
        #expect(try archive.decision(question.id)?.status == .superseded)
        #expect(try archive.decision(question.id)?.closedAt != nil)
        try archive.updateDecision(answer.id, supersedes: [])
        #expect(try archive.decision(question.id)?.status == .active)
        #expect(try archive.decision(question.id)?.closedAt == nil)
    }

    @Test func dependenciesBlockAndFree() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let first = try entry(archive, "Firmare il contratto")
        let second = try entry(archive, "Avviare lo sviluppo")
        try archive.setBlockers([first.id], of: second.id)
        #expect(try archive.decision(second.id)?.status == .blocked)
        #expect(try archive.decisionSummary(second.id)?.blockers.map(\.id) == [first.id])
        try archive.setDecisionStatus(first.id, .done)
        #expect(try archive.decision(second.id)?.status == .active)
        try archive.setDecisionStatus(first.id, .active)
        #expect(try archive.decision(second.id)?.status == .blocked)
        // No loops.
        #expect(throws: WorkError.dependencyCycle) { try archive.setBlockers([second.id], of: first.id) }
        // Deleting the blocker frees the entry.
        try archive.deleteDecision(first.id)
        #expect(try archive.decision(second.id)?.status == .active)
    }

    @Test func aRepeatingEntryCreatesTheNextWhenDone() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let due = Date(timeIntervalSince1970: 1_800_000_000)
        var task = try entry(archive, "Report settimanale")
        task = try archive.updateDecision(task.id, people: ["Anna"]) {
            $0.recurrence = .weekly
            $0.dueAt = due
        }
        try archive.addChecklistItem("Dati vendite", decisionID: task.id)
        let line = try #require(try archive.checklistItems(decisionID: task.id).first)
        try archive.updateChecklistItem(line.id) { $0.done = true }
        try archive.setDecisionStatus(task.id, .done)
        let next = try #require(try archive.decisions().first { $0.decision.derivedFromId == task.id })
        #expect(next.decision.status == .active)
        #expect(next.decision.dueAt == Calendar(identifier: .gregorian).date(byAdding: .weekOfYear, value: 1, to: due))
        #expect(next.people == ["Anna"])
        #expect(try archive.checklistItems(decisionID: next.id).map(\.done) == [false])
        #expect(next.checklist.total == 1)
    }

    @Test func checklistsOfActivitiesAndProjects() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let task = try entry(archive, "Consegna", project: project.id)
        let a = try archive.addChecklistItem("Grafica", decisionID: task.id)
        let b = try archive.addChecklistItem("Testi", decisionID: task.id)
        try archive.updateChecklistItem(a.id) { $0.done = true }
        try archive.reorderChecklist([b.id, a.id])
        #expect(try archive.checklistItems(decisionID: task.id).map(\.text) == ["Testi", "Grafica"])
        #expect(try archive.checklistProgress(decisionIDs: [task.id])[task.id]?.done == 1)

        let list = try archive.createChecklist(projectID: project.id, name: "Consegna finale")
        try archive.addChecklistItem("Manuale", checklistID: list.id)
        #expect(try archive.checklists(pinnedOnly: true).map(\.name) == ["Consegna finale"])
        try archive.deleteChecklist(list.id)
        #expect(try archive.checklists().isEmpty)
        #expect(try archive.checklistItems(checklistID: list.id).isEmpty)
    }

    @Test func freeColumnsKeepTheState() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let task = try entry(archive, "Idea app mobile", project: project.id)
        let scope = BoardScope.project(project.id)
        let column = try archive.addBoardColumn(scope, name: "Da discutere")
        try archive.placeOnBoard(task.id, column: column.id, scope: scope)
        #expect(try archive.boardPlaces(scope) == [task.id: column.id])
        #expect(try archive.boardPlaces(.all).isEmpty)
        #expect(try archive.decision(task.id)?.status == .active)
        try archive.deleteBoardColumn(column.id)
        #expect(try archive.boardPlaces(scope).isEmpty)
        #expect(try archive.boardColumns(scope).isEmpty)
    }

    @Test func modeIsPerAppWithProjectsKeptSimple() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Piccolo")
        #expect(archive.workMode() == .track)
        try archive.setWorkMode(.manage)
        #expect(archive.workMode(projectID: project.id) == .manage)
        try archive.setProjectWorkMode(project.id, .track)
        #expect(archive.workMode(projectID: project.id) == .track)
        #expect(archive.workMode(projectID: nil) == .manage)
        try archive.setWorkMode(.track)
        #expect(archive.workMode(projectID: project.id) == .track)
    }

    @Test func ownersAndSimilarNames() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let marco = try #require(try archive.person(named: "Marco Rossi"))
        _ = try archive.person(named: "Anna Bianchi")
        #expect(try archive.similarPeople(to: "Marco").map(\.name) == ["Marco Rossi"])
        #expect(try archive.similarPeople(to: "Marco Rosi").map(\.name) == ["Marco Rossi"])
        #expect(try archive.similarPeople(to: "Marco Rossi").isEmpty)
        #expect(try archive.similarPeople(to: "Luca").isEmpty)
        let task = try entry(archive, "Preventivo")
        try archive.updateDecision(task.id) { $0.ownerId = marco.id }
        #expect(try archive.decisionSummary(task.id)?.ownerName == "Marco Rossi")
        #expect(try archive.decisions(DecisionQuery(ownerID: marco.id)).map(\.id) == [task.id])
    }

    @Test func replacingAChecklistKeepsTheSameLines() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let task = try entry(archive, "Consegna")
        let kept = try archive.addChecklistItem("Raccogliere i file", decisionID: task.id)
        try archive.addChecklistItem("Vecchia riga", decisionID: task.id)
        try archive.replaceChecklist(
            [.init(text: "Inviare il link", done: false), .init(text: "Raccogliere i file", done: true)],
            decisionID: task.id)
        let items = try archive.checklistItems(decisionID: task.id)
        #expect(items.map(\.text) == ["Inviare il link", "Raccogliere i file"])
        #expect(items.map(\.done) == [false, true])
        #expect(items.last?.id == kept.id)
    }

    @Test func undoingClaudesChangeRestoresTheWorkFields() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let blocker = try entry(archive, "Firmare il contratto")
        let task = try entry(archive, "Preventivo")
        try archive.addChecklistItem("Bozza", decisionID: task.id)
        let before = try #require(try archive.decision(task.id))
        let change = try archive.recordMCPChange(
            .decision, id: task.id, action: .update,
            previous: MCPPrevious(
                text: before.text, status: before.status, work: .init(before), blockerIDs: [],
                checklist: [.init(text: "Bozza", done: false)]))
        try archive.updateDecision(task.id) {
            $0.kind = .risk
            $0.severity = .high
            $0.dueAt = Date(timeIntervalSince1970: 1_800_100_000)
        }
        try archive.setBlockers([blocker.id], of: task.id)
        try archive.replaceChecklist([.init(text: "Altro", done: true)], decisionID: task.id)

        try archive.undoMCPChange(try #require(change.id))
        let after = try #require(try archive.decision(task.id))
        #expect(after.kind == .action && after.severity == nil && after.dueAt == nil)
        #expect(after.status == .active)
        #expect(try archive.blockers(of: task.id).isEmpty)
        #expect(try archive.checklistItems(decisionID: task.id).map(\.text) == ["Bozza"])
    }
}

@Suite struct WorkReviewTests {
    func entry(_ archive: Archive, _ text: String, _ kind: Decision.Kind = .action, project: String? = nil) throws
        -> Decision
    {
        try archive.createDecision(
            Decision(
                text: text, decidedAt: Date(timeIntervalSince1970: 1_800_000_000), projectId: project,
                origin: .manual, kind: kind))
    }

    @Test func aRepeatingEntryIsCopiedOnceAndNotWhenRejected() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let task = try entry(archive, "Report settimanale")
        try archive.updateDecision(task.id) { $0.recurrence = .weekly }
        try archive.setDecisionStatus(task.id, .done)
        try archive.setDecisionStatus(task.id, .active)
        try archive.setDecisionStatus(task.id, .done)
        let copies = try archive.decisions(DecisionQuery(statuses: [])).filter { $0.decision.derivedFromId == task.id }
        #expect(copies.count == 1)
        // The copy can be found.
        #expect(try archive.search("Report settimanale").count >= 2)

        let request = try entry(archive, "Report mensile", .request)
        try archive.updateDecision(request.id) {
            $0.recurrence = .monthly
            $0.status = .done
            $0.outcomeKind = .rejected
        }
        #expect(
            try archive.decisions(DecisionQuery(statuses: [])).allSatisfy { $0.decision.derivedFromId != request.id })
    }

    @Test func memoryNeverBlocksNorIsBlocked() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let decision = try entry(archive, "Usiamo Azure AD", .decision)
        let task = try entry(archive, "Configurare SSO")
        try archive.setBlockers([decision.id], of: task.id)
        #expect(try archive.decision(task.id)?.status == .active)

        let other = try entry(archive, "Firmare il contratto")
        try archive.setBlockers([other.id], of: task.id)
        #expect(try archive.decision(task.id)?.status == .blocked)
        let turned = try archive.updateDecision(task.id) { $0.kind = .decision }
        #expect(turned.status == .active)
        #expect(try archive.blockers(of: task.id).isEmpty)
    }

    @Test func reopeningClearsOutcomeAndLeavingWaitingClearsWhom() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let anna = try #require(try archive.person(named: "Anna"))
        let request = try entry(archive, "App mobile", .request)
        try archive.updateDecision(request.id) {
            $0.status = .done
            $0.outcomeKind = .rejected
            $0.outcome = "fuori budget"
        }
        let reopened = try archive.updateDecision(request.id) { $0.status = .active }
        #expect(reopened.outcome == nil && reopened.outcomeKind == nil)

        let task = try entry(archive, "File definitivi")
        try archive.updateDecision(task.id) {
            $0.status = .waiting
            $0.waitingOnId = anna.id
            $0.waitingUntil = Date()
        }
        let moved = try archive.updateDecision(task.id) { $0.status = .inProgress }
        #expect(moved.waitingOnId == nil && moved.waitingUntil == nil)
    }

    @Test func deletingAProjectRemovesItsChecklistsAndFreesOthers() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Vecchio")
        let other = try archive.createProject(name: "Nuovo")
        let blocker = try entry(archive, "Consegna", project: project.id)
        let blocked = try entry(archive, "Collaudo", project: other.id)
        try archive.setBlockers([blocker.id], of: blocked.id)
        let list = try archive.createChecklist(projectID: project.id, name: "Consegna finale")
        try archive.addChecklistItem("Manuale", checklistID: list.id)
        try archive.deleteProject(project.id)
        #expect(try archive.checklists(pinnedOnly: true).isEmpty)
        #expect(try archive.decision(blocked.id)?.status == .active)
    }
}
