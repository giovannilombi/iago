import Foundation
import Testing

@testable import IAGOStore

@Suite struct DecisionTests {
    @Test func supersedingChainsAndRestores() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let first = try archive.createDecision(
            Decision(text: "Go-live a marzo", decidedAt: Date(timeIntervalSince1970: 1_000), origin: .manual))
        let second = try archive.createDecision(
            Decision(
                text: "Go-live ad aprile", decidedAt: Date(timeIntervalSince1970: 2_000), supersedesId: first.id,
                origin: .manual))
        #expect(try archive.decision(first.id)?.status == .superseded)
        #expect(try archive.decisionChain(of: first.id).map(\.id) == [first.id, second.id])
        #expect(try archive.decisionChain(of: second.id).map(\.id) == [first.id, second.id])
        #expect(try archive.decisions().map(\.id) == [second.id])  // default: only active
        let summary = try #require(try archive.decisionSummary(first.id))
        #expect(summary.supersededBy?.id == second.id)

        // A loop is refused.
        #expect(throws: DecisionError.supersedeCycle) {
            try archive.updateDecision(first.id) { $0.supersedesId = second.id }
        }

        // Deleting the newer decision brings the older one back.
        try archive.deleteDecision(second.id)
        #expect(try archive.decision(first.id)?.status == .active)
        #expect(try archive.decision(second.id) == nil)
    }

    @Test func reorderingAChain() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        func make(_ text: String, _ at: Double, supersedes: String? = nil, kind: Decision.Kind = .decision) throws
            -> Decision
        {
            try archive.createDecision(
                Decision(
                    text: text, decidedAt: Date(timeIntervalSince1970: at), supersedesId: supersedes, origin: .manual,
                    kind: kind))
        }
        // Entered the wrong way round: the activity supersedes the decision it became.
        let decision = try make("Verso 1.5%", 2_000)
        let activity = try make("Decidere quanto versare", 1_000, supersedes: decision.id, kind: .action)
        try archive.setChainName("Contributo", decisionID: decision.id)
        #expect(try archive.comesLater(activity.id, than: decision.id))

        try archive.updateDecision(decision.id, reorderingChain: true) { $0.supersedesId = activity.id }
        #expect(try archive.decisionChain(of: decision.id).map(\.id) == [activity.id, decision.id])
        #expect(try archive.decision(decision.id)?.status == .active)
        #expect(try archive.decision(activity.id)?.status == .superseded)
        #expect(try archive.decision(activity.id)?.supersedesId == nil)
        #expect(try archive.chainName(of: decision.id) == "Contributo")
        #expect(try archive.decision(activity.id)?.chainName == "Contributo")

        // In a longer chain the moved decision leaves its place: A → B → C, then B after C gives A → C → B.
        let a = try make("A", 10)
        let b = try make("B", 20, supersedes: a.id)
        let c = try make("C", 30, supersedes: b.id)
        try archive.updateDecision(b.id, reorderingChain: true) { $0.supersedesId = c.id }
        #expect(try archive.decisionChain(of: a.id).map(\.id) == [a.id, c.id, b.id])
        #expect(try archive.decision(a.id)?.status == .superseded)
        #expect(try archive.decision(c.id)?.status == .superseded)
        #expect(try archive.decision(b.id)?.status == .active)
    }

    @Test func chainNamesAndRelatedDecisions() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let design = try archive.createStream(projectID: project.id, name: "Design")
        func make(_ text: String, _ at: Double, supersedes: String? = nil, streams: [String] = []) throws -> Decision {
            try archive.createDecision(
                Decision(
                    text: text, decidedAt: Date(timeIntervalSince1970: at), projectId: project.id,
                    supersedesId: supersedes, origin: .manual), streams: streams)
        }
        let first = try make("Logo blu", 1_000, streams: [design.id])
        let second = try make("Logo verde", 2_000, supersedes: first.id, streams: [design.id])
        let other = try make("Font Inter", 3_000, streams: [design.id])
        let elsewhere = try make("Budget 50k", 4_000)

        // The name lives on the first decision and is found from any decision of the chain.
        try archive.setChainName("  Colore del logo ", decisionID: second.id)
        #expect(try archive.decision(first.id)?.chainName == "Colore del logo")
        #expect(try archive.decision(second.id)?.chainName == nil)
        #expect(try archive.chainName(of: second.id) == "Colore del logo")
        #expect(try archive.decisionSummary(first.id)?.chainName == "Colore del logo")
        #expect(try archive.decisionSummary(second.id)?.chainName == "Colore del logo")
        #expect(try archive.decisionSummary(other.id)?.chainName == nil)
        try archive.setChainName("", decisionID: first.id)
        #expect(try archive.chainName(of: second.id) == nil)

        // Same stream only, own chain excluded, active only.
        #expect(try archive.relatedDecisions(of: other.id).map(\.id) == [second.id])
        #expect(try archive.relatedDecisions(of: elsewhere.id).map(\.id) == [other.id, second.id])
    }

    @Test func decisionsPromotedFromItemNotesBelongToTheItem() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        let note = try archive.addNote(itemID: item.id, body: "Logo giallo")
        let decision = try archive.createDecision(
            Decision(text: "Logo giallo", decidedAt: note.notedAt, sourceNoteId: note.id, origin: .note))
        #expect(try archive.decisions(sourceItemID: item.id).map(\.id) == [decision.id])
        #expect(try archive.promotedDecisions(noteIDs: [note.id]) == [note.id: decision.id])

        // Classifying the item moves the decision born from its note too.
        let project = try archive.createProject(name: "Brand")
        try archive.updateItem(item.id) { $0.projectId = project.id }
        #expect(try archive.decision(decision.id)?.projectId == project.id)
    }

    @Test func activitiesAndMilestonesShareTheRegisterAndChains() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let at = Date(timeIntervalSince1970: 1_000)
        let activity = try archive.createDecision(
            Decision(text: "Preparare l'offerta", decidedAt: at, projectId: project.id, origin: .manual, kind: .action))
        let milestone = try archive.createDecision(
            Decision(
                text: "Contratto firmato", decidedAt: at.addingTimeInterval(10), projectId: project.id,
                origin: .manual, kind: .milestone))
        try archive.createDecision(
            Decision(text: "Budget 50k", decidedAt: at.addingTimeInterval(20), projectId: project.id, origin: .manual))

        #expect(try archive.decisions(DecisionQuery(scope: .project(project.id))).count == 3)
        #expect(
            try archive.decisions(DecisionQuery(scope: .project(project.id), kinds: [.milestone])).map(\.id)
                == [milestone.id])

        // An activity is done, reopened, then becomes a decision that supersedes it.
        try archive.setDecisionStatus(activity.id, .done)
        #expect(try archive.decision(activity.id)?.status == .done)
        try archive.setDecisionStatus(activity.id, .active)
        let decision = try archive.createDecision(
            Decision(
                text: "Offerta a 48k", decidedAt: at.addingTimeInterval(30), projectId: project.id,
                supersedesId: activity.id, origin: .manual))
        #expect(try archive.decision(activity.id)?.status == .superseded)
        #expect(try archive.decisionChain(of: decision.id).map(\.kind) == [.action, .decision])
    }

    @Test func bookmarkConversionAndPeopleAndTags() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        let marker = try archive.addMarker(itemID: item.id, atSec: 95, note: "budget")
        let decision = try archive.createDecision(
            Decision(
                text: "Budget approvato", decidedAt: item.occurredAt, sourceItemId: item.id, sourceAtSec: 95,
                origin: .marker),
            people: ["Mario Rossi", "mario rossi", "Giulia"], tags: ["Budget"], markerID: marker.id)
        #expect(try archive.markers(itemID: item.id).first?.status == .converted)
        let summary = try #require(try archive.decisionSummary(decision.id))
        #expect(summary.people == ["Giulia", "Mario Rossi"])
        #expect(summary.tags == ["Budget"])
        #expect(summary.sourceState == .available)
        let mario = try #require(try archive.people().first { $0.name == "Mario Rossi" })
        #expect(try archive.decisions(DecisionQuery(personID: mario.id)).map(\.id) == [decision.id])
        #expect(try archive.decisions(DecisionQuery(tags: ["budget"])).count == 1)
        #expect(try archive.decisions(DecisionQuery(tags: ["altro"])).isEmpty)
        #expect(try archive.search("approvato").map(\.source) == [.decision])
        try archive.addNote(itemID: item.id, body: "Budget approvato in riunione")
        #expect(try archive.search("approvato").count == 2)
        #expect(try archive.search("approvato", sources: [.decision]).map(\.source) == [.decision])
        #expect(try archive.search("approvato", sources: [.note, .transcript]).map(\.source) == [.note])
    }

    @Test func decisionSurvivesItsSource() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        let decision = try archive.createDecision(
            Decision(
                text: "Fornitore scelto: Alfa", decidedAt: item.occurredAt, sourceItemId: item.id, sourceAtSec: 10,
                origin: .selection), people: ["Anna"])
        try archive.trashItem(item.id)
        #expect(try archive.decisionSummary(decision.id)?.sourceState == .trashed)
        try archive.purgeItem(item.id)
        let summary = try #require(try archive.decisionSummary(decision.id))
        #expect(summary.sourceState == .deleted)
        #expect(summary.decision.text == "Fornitore scelto: Alfa")
        #expect(summary.people == ["Anna"])
        #expect(try archive.search("fornitore").count == 1)  // still searchable (FR-156)
        try archive.updateDecision(decision.id) { $0.notes = "Offerta più bassa e consegna in tre settimane" }
        #expect(try archive.search("consegna").map(\.sourceID) == [decision.id])  // description indexed too
    }

    @Test func decisionsFollowTheirItemAcrossProjects() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let alfa = try archive.createProject(name: "Alfa")
        let beta = try archive.createProject(name: "Beta")
        let item = try fixture.makeItem()
        try archive.updateItem(item.id) { $0.projectId = alfa.id }
        let decision = try archive.createDecision(
            Decision(
                text: "Kickoff confermato", decidedAt: item.occurredAt, projectId: alfa.id, sourceItemId: item.id,
                origin: .selection))
        try archive.updateItem(item.id) { $0.projectId = beta.id }
        #expect(try archive.decision(decision.id)?.projectId == beta.id)
        #expect(try archive.decisions(DecisionQuery(scope: .project(beta.id))).count == 1)
        try archive.deleteProject(beta.id)
        #expect(try archive.decision(decision.id) == nil)
        #expect(try archive.search("kickoff").isEmpty)
    }

    @Test func noteSourceAndCancel() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        let note = try archive.addNote(itemID: item.id, body: "Decidiamo di usare Swift")
        let decision = try archive.createDecision(
            Decision(text: note.body, decidedAt: note.notedAt, sourceNoteId: note.id, origin: .note))
        try archive.setDecisionStatus(decision.id, .cancelled)
        #expect(try archive.decisions().isEmpty)
        #expect(try archive.decisions(DecisionQuery(statuses: [.cancelled])).count == 1)
        try archive.deleteNote(note.id)
        #expect(try archive.decisionSummary(decision.id)?.sourceState == .deleted)
        #expect(throws: DecisionError.emptyText) {
            try archive.createDecision(Decision(text: "  ", decidedAt: Date(), origin: .manual))
        }
    }

    @Test func oneEntrySupersedesSeveralOfAnyKind() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        func make(_ text: String, _ at: Double, kind: Decision.Kind = .decision, supersedes: [String] = []) throws
            -> Decision
        {
            try archive.createDecision(
                Decision(text: text, decidedAt: Date(timeIntervalSince1970: at), origin: .manual, kind: kind),
                supersedes: supersedes)
        }
        let decision = try make("Aderire al fondo", 10)
        let step1 = try make("Raccolti i moduli", 20, kind: .milestone)
        let step2 = try make("Firmare il PX7", 30, kind: .action)
        let done = try make(
            "Firmato il PX7 e inviata la documentazione", 40, kind: .milestone,
            supersedes: [decision.id, step1.id, step2.id])
        for id in [decision.id, step1.id, step2.id] { #expect(try archive.decision(id)?.status == .superseded) }
        #expect(Set(try archive.supersededIDs(of: done.id)) == [decision.id, step1.id, step2.id])
        #expect(try archive.decision(done.id)?.supersedesId == step2.id)
        #expect(try archive.decisionChain(of: step1.id).map(\.id) == [decision.id, step1.id, step2.id, done.id])
        let summary = try #require(try archive.decisionSummary(step1.id))
        #expect(summary.supersededByAll.map(\.id) == [done.id])

        // Superseded by two: stays superseded until both are gone.
        let other = try make("Altra tappa", 50, supersedes: [step1.id])
        try archive.updateDecision(done.id, supersedes: [decision.id, step2.id])
        #expect(try archive.decision(step1.id)?.status == .superseded)
        try archive.updateDecision(other.id) { $0.status = .cancelled }
        #expect(try archive.decision(step1.id)?.status == .active)
        try archive.updateDecision(other.id) { $0.status = .active }
        #expect(try archive.decision(step1.id)?.status == .superseded)
        try archive.deleteDecision(other.id)
        #expect(try archive.decision(step1.id)?.status == .active)

        // No loops, also through other entries; adding keeps the others.
        #expect(throws: DecisionError.supersedeCycle) { try archive.updateDecision(decision.id, supersedes: [done.id]) }
        try archive.addSupersede(newer: done.id, older: step1.id)
        #expect(Set(try archive.supersededIDs(of: done.id)) == [decision.id, step1.id, step2.id])

        // Undo puts every link back.
        let links = try archive.decisionLinks(ofChainsOf: [done.id])
        try archive.updateDecision(done.id, supersedes: [])
        #expect(try archive.decision(decision.id)?.status == .active)
        try archive.restoreDecisionLinks(links)
        #expect(Set(try archive.supersededIDs(of: done.id)) == [decision.id, step1.id, step2.id])
        #expect(try archive.decision(decision.id)?.status == .superseded)
    }

    @Test func categoryLibraryAndSummaries() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let all = try archive.categories(includeArchived: true)
        #expect(all.count == Category.library.count)
        #expect(all.filter { $0.family == nil }.allSatisfy { !$0.archived })
        #expect(all.filter { $0.family != nil }.allSatisfy { $0.archived })
        #expect(all.allSatisfy { $0.templateId != nil })
        #expect(try archive.categories().map(\.name) == Category.builtinNames)
        let agile = try #require(all.first { $0.name == "Daily standup" })
        try archive.setCategoryActive(agile.id, true)
        let active = try archive.categories()
        #expect(active.contains { $0.id == agile.id })

        let item = try archive.createItem(
            type: .document, title: "SAL settimanale", occurredAt: Date(), source: .import, status: .recorded)
        try archive.saveSummary(
            itemID: item.id, categoryID: agile.id, templateID: "dailyStandup", markdown: "## Ieri\n\nFatto il logo",
            model: "test")
        #expect(try archive.summary(itemID: item.id)?.edited == false)
        let hits = try archive.search("logo")
        #expect(hits.contains { $0.source == .summary })
        try archive.editSummary(itemID: item.id, markdown: "## Ieri\n\nFatto il marchio")
        #expect(try archive.summary(itemID: item.id)?.edited == true)
        _ = try archive.updateItem(item.id) { $0.categoryId = agile.id }
        try archive.setTags(["brand"], for: item.id)
        let counts = try archive.labelCounts()
        #expect(counts.categories[agile.id] == 1)
        #expect(counts.tags.values.reduce(0, +) == 1)
        try archive.deleteSummary(itemID: item.id)
        #expect(try archive.summary(itemID: item.id) == nil)
    }
}
