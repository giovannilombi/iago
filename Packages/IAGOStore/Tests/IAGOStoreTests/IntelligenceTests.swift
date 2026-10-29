import Foundation
import Testing

@testable import IAGOStore

@Suite struct IntelligenceTests {
    @Test func chunksFollowScopeAndModelAndGoWithTheirOwner() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let other = try archive.createProject(name: "Altro")
        let design = try archive.createStream(projectID: project.id, name: "Design")
        let call = try fixture.makeItem()
        try archive.updateItem(call.id) { $0.projectId = project.id }
        try archive.setStreams([design.id], itemID: call.id)
        try archive.storeAsset(Data("{}".utf8), itemID: call.id, kind: .transcriptJSON, fileName: "transcript.json")
        let elsewhere = try fixture.makeItem("Altra call")
        try archive.updateItem(elsewhere.id) { $0.projectId = other.id }
        let note = try archive.addNote(itemID: nil, projectID: project.id, body: "Il logo resta blu")

        #expect(try archive.unindexed(model: "e1").items == [call.id])  // only items with text
        #expect(try archive.unindexed(model: "e1").notes == [note.id])
        // Nothing to index in it: not tried again until its text changes.
        try archive.markNothingToIndex(itemID: call.id, model: "e1")
        #expect(try archive.unindexed(model: "e1").items.isEmpty)
        #expect(try archive.unindexed(model: "e2").items == [call.id])
        try archive.setSetting("chunk.empty.e1.\(call.id)", nil)
        try archive.replaceChunks(
            itemID: call.id, noteID: nil,
            with: [
                Chunk(
                    id: "\(call.id)#0", itemId: call.id, noteId: nil, source: .transcript, startSec: 0, endSec: 60,
                    text: "Parliamo del logo", model: "e1", vector: [1, 0])
            ])
        try archive.replaceChunks(
            itemID: nil, noteID: note.id,
            with: [
                Chunk(
                    id: note.id, itemId: nil, noteId: note.id, source: .note, text: note.body, model: "e1",
                    vector: [0, 1])
            ])
        try archive.replaceChunks(
            itemID: elsewhere.id, noteID: nil,
            with: [
                Chunk(
                    id: "\(elsewhere.id)#0", itemId: elsewhere.id, noteId: nil, source: .transcript, text: "x",
                    model: "e1", vector: [1, 1])
            ])

        #expect(Set(try archive.chunks(.project(project.id), model: "e1").map(\.id)) == ["\(call.id)#0", note.id])
        #expect(try archive.chunks(.stream(design.id), model: "e1").map(\.id) == ["\(call.id)#0"])
        #expect(try archive.chunks(.all, model: "e2").isEmpty)
        #expect(try archive.chunks(.project(project.id), model: "e1").first { $0.noteId == nil }?.values == [1, 0])
        #expect(try archive.unindexed(model: "e1").items.isEmpty)
        // A new transcription or an edited note makes them stale.
        fixture.clock.advance(days: 0.01)
        try archive.storeAsset(Data("{}".utf8), itemID: call.id, kind: .transcriptJSON, fileName: "transcript-2.json")
        try archive.updateNote(note.id) { $0.body = "Il logo diventa verde" }
        #expect(try archive.unindexed(model: "e1").items == [call.id])
        #expect(try archive.unindexed(model: "e1").notes == [note.id])

        // Trashed items leave the search; purged items and deleted notes lose their chunks.
        try archive.trashItem(elsewhere.id)
        #expect(try archive.chunks(.all, model: "e1").count == 2)
        try archive.deleteNote(note.id)
        try archive.purgeItem(call.id)
        #expect(try archive.chunkCount(model: "e1") == 1)
        try archive.deleteChunks(notFrom: "e2")
        #expect(try archive.chunkCount(model: "e1") == 0)
    }

    @Test func answeredSuggestionsAreNotProposedAgain() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Portale")
        let call = try fixture.makeItem()
        try archive.updateItem(call.id) { $0.projectId = project.id }
        let first = try archive.replacePendingSuggestions(
            itemID: call.id, model: "m",
            [
                (.decision, SuggestionPayload(text: "Logo blu", quote: "facciamo il logo blu", atSec: 75)),
                (.activity, SuggestionPayload(text: "Mandare il preventivo", owner: "Mario")),
                (.decision, SuggestionPayload(text: "logo BLU")),  // same proposal twice in one run
            ])
        #expect(first.count == 2)
        #expect(try archive.pendingSuggestionCounts() == [call.id: 2])
        #expect(try archive.pendingKeyPointSuggestions(.project(project.id)).count == 2)
        // ADR-0074: the open work kinds wait in "Da confermare" too; tags do not.
        let other = try fixture.makeItem()
        try archive.updateItem(other.id) { $0.projectId = project.id }
        try archive.replacePendingSuggestions(
            itemID: other.id, model: "m",
            [
                (.question, SuggestionPayload(text: "Quale provider?")),
                (.risk, SuggestionPayload(text: "Ritardo del fornitore", severity: "high")),
                (.request, SuggestionPayload(text: "Export in Excel")), (.tag, SuggestionPayload(text: "sso")),
            ])
        #expect(try archive.pendingKeyPointSuggestions(.project(project.id)).count == 5)
        try archive.purgeItem(other.id)
        #expect(first[0].content.atSec == 75)

        try archive.setSuggestionStatus(first[0].id, .rejected)
        try archive.setSuggestionStatus(first[1].id, .accepted)
        // A new run: the rejected and the accepted ones do not come back; the new one does.
        let second = try archive.replacePendingSuggestions(
            itemID: call.id, model: "m",
            [(.decision, SuggestionPayload(text: "Logo blu")), (.tag, SuggestionPayload(text: "brand", isNew: true))])
        #expect(second.map(\.kind) == [.tag])
        #expect(try archive.suggestions(itemID: call.id).map(\.kind) == [.tag])
        #expect(try archive.suggestions(itemID: call.id, status: nil).count == 3)
        try archive.purgeItem(call.id)
        #expect(try archive.suggestions(itemID: call.id, status: nil).isEmpty)
    }

    /// ADR-0070: who produced each result is kept, and the engine and Claude do not remove each other's proposals.
    @Test func resultsKeepWhoProducedThem() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let call = try fixture.makeItem()
        try archive.replacePendingSuggestions(
            itemID: call.id, model: "qwen3.5-4b", [(.decision, SuggestionPayload(text: "Logo blu"))])
        try archive.replacePendingSuggestions(
            itemID: call.id, model: "Claude Desktop", origin: .claude,
            [(.activity, SuggestionPayload(text: "Mandare il preventivo"))])
        // A new run of the engine replaces only its own pending proposals.
        try archive.replacePendingSuggestions(
            itemID: call.id, model: "qwen3.5-9b", [(.decision, SuggestionPayload(text: "Font nuovo"))])
        let pending = try archive.suggestions(itemID: call.id)
        #expect(Set(pending.map(\.content.text)) == ["Mandare il preventivo", "Font nuovo"])
        #expect(pending.first { $0.origin == .claude }?.model == "Claude Desktop")
        #expect(pending.first { $0.origin == .engine }?.model == "qwen3.5-9b")

        try archive.saveSummary(itemID: call.id, categoryID: nil, templateID: nil, markdown: "# Sintesi", model: "m")
        #expect(try archive.summary(itemID: call.id)?.origin == .engine)
        try archive.saveSummary(
            itemID: call.id, categoryID: nil, templateID: nil, markdown: "# Sintesi", model: "Claude Desktop",
            origin: .claude)
        #expect(try archive.summary(itemID: call.id)?.origin == .claude)

        var draft = Decision(text: "Logo blu", decidedAt: fixture.clock.now, sourceItemId: call.id, origin: .extraction)
        draft.model = "qwen3.5-4b"
        let decision = try archive.createDecision(draft)
        #expect(try archive.decision(decision.id)?.model == "qwen3.5-4b")
    }

    /// ADR-0071: undoing Claude's summary never throws away what was written after it.
    @Test func undoingAClaudeSummaryKeepsLaterWork() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let call = try fixture.makeItem()
        try archive.saveSummary(
            itemID: call.id, categoryID: nil, templateID: nil, markdown: "# Di Claude", model: "Claude Desktop",
            origin: .claude)
        let change = try archive.recordMCPChange(
            .summary, id: call.id, action: .create, previous: MCPPrevious(body: "# Di Claude"))
        try archive.editSummary(itemID: call.id, markdown: "# Corretta a mano")
        #expect(throws: MCPChangeError.changedSince) { try archive.undoMCPChange(try #require(change.id)) }
        #expect(try archive.summary(itemID: call.id)?.markdown == "# Corretta a mano")
    }

    @Test func conversationsLast48HoursUnlessKept() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Fondo")
        let start = fixture.clock.now
        let temporary = try archive.startConversation(
            scope: .project(project.id), question: "Cosa abbiamo deciso?", answer: "Il 2% [1]", sources: "[]",
            model: "m")
        let kept = try archive.startConversation(
            scope: .all, question: "Chi manda il modulo?", answer: "Mario [1]", sources: "[]", model: "m")
        try archive.setConversationKept(kept.id, keep: true)
        let pinned = try archive.startConversation(
            scope: .all, question: "Altro", answer: "…", sources: "[]", model: "m")
        try archive.setConversationKept(pinned.id, keep: false, pinned: true)
        #expect(try archive.conversations().first?.id == pinned.id)
        #expect(temporary.scope == .project(project.id))

        // A new question moves the deadline; the new material since the answer is counted.
        fixture.clock.advance(days: 1)
        try archive.addTurn(to: temporary.id, question: "E il TFR?", answer: "100% [1]", sources: "[]", model: "m")
        #expect(try archive.conversationTurns(temporary.id).count == 2)
        let call = try fixture.makeItem()
        try archive.updateItem(call.id) { $0.projectId = project.id }
        #expect(try archive.changedSince(start, scope: .project(project.id)).items == [call.id])
        #expect(
            try archive.changedSince(fixture.clock.now.addingTimeInterval(60), scope: .project(project.id)).items
                .isEmpty)

        fixture.clock.advance(days: 1.9)
        #expect(try archive.purgeExpiredConversations() == 0)  // 48 h from the last question
        fixture.clock.advance(days: 0.2)
        #expect(try archive.purgeExpiredConversations() == 1)
        #expect(Set(try archive.conversations().map(\.id)) == [kept.id, pinned.id])
        #expect(try archive.conversationTurns(temporary.id).isEmpty)
        try archive.deleteConversation(kept.id)
        #expect(try archive.conversations().map(\.id) == [pinned.id])
    }
}
