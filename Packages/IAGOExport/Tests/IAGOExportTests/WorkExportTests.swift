import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOExport

/// Open work in exports (ADR-0074): kinds, states, outcome, owner, due date, waiting for, checklist, "nata da".
@Suite struct WorkExportTests {
    let utc = TimeZone(identifier: "UTC")!
    let t0 = Date(timeIntervalSince1970: 1_791_000_000)  // 2026-10-03
    let day: TimeInterval = 86_400

    func archive() throws -> (Archive, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-work-\(UUID().uuidString)")
        let archive = try Archive(
            database: try AppDatabase.inMemory(), itemsRoot: root.appendingPathComponent("Items"),
            keyStore: EphemeralMasterKeyStore())
        return (archive, root)
    }

    @Test func labelsOfKindsStatesAndOutcomes() {
        var risk = Decision(text: "Ritardo fornitore", decidedAt: t0, origin: .manual, kind: .risk)
        risk.severity = .high
        #expect(KeyPointLabels.tag(risk) == "Rischio · alta · Aperto")
        risk.status = .done
        risk.outcomeKind = .irrelevant
        #expect(KeyPointLabels.tag(risk) == "Rischio · alta · Non più rilevante")
        risk.status = .active  // reopened: the old outcome no longer counts
        #expect(KeyPointLabels.status(risk) == "Aperto")

        var task = Decision(text: "Preventivo", decidedAt: t0, origin: .manual, kind: .action)
        #expect(KeyPointLabels.status(task) == "Da fare")
        #expect(KeyPointLabels.status(task, mode: .track) == "Aperta")
        task.status = .inProgress
        #expect(KeyPointLabels.status(task) == "In corso")
        #expect(KeyPointLabels.status(task, mode: .track) == "Aperta")
        task.status = .blocked
        #expect(KeyPointLabels.status(task) == "Bloccata")
        task.status = .waiting
        #expect(KeyPointLabels.status(task, mode: .track) == "In attesa")
        task.status = .superseded
        let milestone = Decision(text: "Firmato", decidedAt: t0, origin: .manual, kind: .milestone)
        #expect(KeyPointLabels.status(task, closedBy: [milestone]) == "Fatta")
        #expect(KeyPointLabels.status(task) == "Superata")

        var question = Decision(text: "Quale provider?", decidedAt: t0, origin: .manual, kind: .openQuestion)
        question.status = .superseded
        let answer = Decision(text: "Usiamo Azure AD", decidedAt: t0, origin: .manual)
        #expect(KeyPointLabels.tag(question, closedBy: [answer]) == "Punto da chiarire · Chiarito")
        #expect(KeyPointLabels.tag(question, closedBy: [milestone]) == "Punto da chiarire · Chiuso")

        var request = Decision(text: "App mobile", decidedAt: t0, origin: .manual, kind: .request)
        request.status = .done
        request.outcomeKind = .rejected
        #expect(KeyPointLabels.tag(request) == "Richiesta · Rifiutata")
        request.status = .cancelled
        request.outcomeKind = nil
        #expect(KeyPointLabels.status(request) == "Annullata")
    }

    @Test func projectExportShowsOpenWork() throws {
        let (archive, _) = try archive()
        let project = try archive.createProject(name: "Portale")
        let marco = try #require(try archive.person(named: "Marco Bianchi"))
        let anna = try #require(try archive.person(named: "Anna Verdi"))

        let request = try archive.createDecision(
            Decision(text: "Login SSO", decidedAt: t0, projectId: project.id, origin: .manual, kind: .request))
        var draft = Decision(
            text: "Preventivo SSO", decidedAt: t0 + day, projectId: project.id, origin: .manual, kind: .action)
        draft.ownerId = marco.id
        draft.dueAt = t0 + 7 * day
        draft.waitingOnId = anna.id
        draft.waitingUntil = t0 + 3 * day
        draft.priority = 1
        draft.derivedFromId = request.id
        draft.status = .waiting
        let task = try archive.createDecision(draft)
        let first = try archive.addChecklistItem("Raccogliere i requisiti", decisionID: task.id)
        try archive.addChecklistItem("Inviare il documento", decisionID: task.id)
        try archive.updateChecklistItem(first.id) { $0.done = true }

        var riskDraft = Decision(
            text: "Ritardo fornitore", decidedAt: t0 + 2 * day, projectId: project.id, origin: .manual, kind: .risk)
        riskDraft.severity = .high
        let risk = try archive.createDecision(riskDraft)
        try archive.setBlockers([risk.id], of: task.id)

        let question = try archive.createDecision(
            Decision(
                text: "Quale provider?", decidedAt: t0 + 3 * day, projectId: project.id, origin: .manual,
                kind: .openQuestion))
        try archive.updateDecision(question.id) {
            $0.status = .done
            $0.outcomeKind = .answered
            $0.outcome = "Usiamo Azure AD"
        }

        let options = ProjectExporter.Options(title: "Portale", itemIDs: [], decisionScope: .project(project.id))
        let md = try ProjectExporter.markdown(options, archive: archive, now: t0 + 10 * day, timeZone: utc)

        #expect(md.contains("## Punti chiave (decisioni, tappe e lavoro aperto)"))
        #expect(md.contains("- **[Richiesta · Aperta] 2026-10-03** Login SSO"))
        #expect(
            md.contains(
                "- **[Attività · In attesa] 2026-10-04** Preventivo SSO — responsabile: Marco Bianchi; scadenza: 2026-10-10; in attesa di: Anna Verdi entro 2026-10-06; priorità: alta; dipende da: «Ritardo fornitore»; nata da: «Login SSO»\n  - ☑ Raccogliere i requisiti\n  - ☐ Inviare il documento"
            ))
        #expect(md.contains("- **[Rischio · alta · Aperto] 2026-10-05** Ritardo fornitore"))
        #expect(md.contains("- **[Punto da chiarire · Chiarito] 2026-10-06** Quale provider? → Usiamo Azure AD"))
    }

    @Test func obsidianShowsOpenWorkOnTheProjectAndItsFile() throws {
        let (archive, root) = try archive()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = try archive.createProject(name: "Portale")
        let marco = try #require(try archive.person(named: "Marco Bianchi"))
        try archive.createDecision(
            Decision(text: "Usiamo Azure AD", decidedAt: t0, projectId: project.id, origin: .manual))
        var draft = Decision(
            text: "Preventivo SSO", decidedAt: t0, projectId: project.id, origin: .manual, kind: .action)
        draft.ownerId = marco.id
        draft.dueAt = t0 + 7 * day
        let task = try archive.createDecision(draft)
        try archive.addChecklistItem("Inviare il documento", decisionID: task.id)

        let vault = root.appendingPathComponent("Vault")
        try ObsidianMirror.sync(archive: archive, vault: vault, projectIDs: [project.id], timeZone: utc)
        let base = vault.appendingPathComponent("IAGO")
        let page = try String(contentsOf: base.appendingPathComponent("Progetti/Portale.md"), encoding: .utf8)
        #expect(page.contains("## Decisioni attive\n\n- 2026-10-03 [[Portale/Decisioni/2026-10-03 Usiamo Azure AD|"))
        #expect(
            page.contains(
                "## Lavoro aperto\n\n- 2026-10-03 [Attività · Da fare] [[Portale/Decisioni/2026-10-03 Preventivo SSO|Preventivo SSO]] · [[Marco Bianchi]] · entro 2026-10-10"
            ))
        let file = try String(
            contentsOf: base.appendingPathComponent("Portale/Decisioni/2026-10-03 Preventivo SSO.md"), encoding: .utf8)
        #expect(file.contains("kind: action\nstatus: active"))
        #expect(file.contains("due: 2026-10-10"))
        #expect(file.contains("Progetto: [[Portale]] · Attività · Stato: Da fare"))
        #expect(file.contains("Responsabile: [[Marco Bianchi]]\nScadenza: 2026-10-10"))
        #expect(file.contains("\n- ☐ Inviare il documento"))
        #expect(FileManager.default.fileExists(atPath: base.appendingPathComponent("Persone/Marco Bianchi.md").path))
    }
}
