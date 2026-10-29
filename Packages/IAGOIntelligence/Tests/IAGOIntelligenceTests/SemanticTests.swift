import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOIntelligence

/// Words to vectors through a tiny thesaurus: synonyms land on the same dimension, so "datoriale" and "azienda" are
/// close by meaning but not by words.
struct FakeEmbedder: TextEmbedder {
    let modelID = "fake-embed"
    static let groups: [[String]] = [
        ["azienda", "datoriale", "datore"], ["contributo", "versa", "versamento"], ["logo", "marchio"],
        ["colore", "blu", "verde"], ["budget", "costo", "preventivo"], ["mario"], ["anna"], ["fondo", "pensione"],
    ]

    func embed(_ texts: [String], query: Bool) async throws -> [[Float]] {
        texts.map { text in
            var vector = [Float](repeating: 0, count: Self.groups.count + 1)
            for word in KeyPointExtractor.words(text) {
                if let index = Self.groups.firstIndex(where: { group in group.contains { word.hasPrefix($0) } }) {
                    vector[index] += 1
                }
            }
            vector[Self.groups.count] = 0.01
            return vector
        }
    }
}

func memoryArchive() throws -> Archive {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("iago-sem-\(UUID().uuidString)")
    return try Archive(
        database: try AppDatabase.inMemory(), itemsRoot: root.appendingPathComponent("Items"),
        keyStore: EphemeralMasterKeyStore())
}

@Suite struct SemanticTests {
    func transcript(_ lines: [(String, Double, String)]) -> Transcript {
        Transcript(
            itemId: "c", engine: .init(asr: "test", model: "test"), language: "it",
            speakers: [.me(), .init(id: "s1", label: "Speaker 1", source: .system)],
            segments: lines.enumerated().map { index, line in
                .init(id: index, speaker: line.0, start: line.1, end: line.1 + 5, text: line.2)
            })
    }

    @Test func transcriptsGoInTurnsWithOverlap() {
        let long = String(repeating: "parola ", count: 150)
        let chunks = Chunker.transcript(
            transcript([("me", 0, long), ("me", 5, "e ancora"), ("s1", 10, long), ("me", 20, long), ("s1", 30, long)]),
            labels: ["s1": "Mario"])
        #expect(chunks.count == 3)
        #expect(chunks[0].startSec == 0 && chunks[0].speakers == ["Io", "Mario"])
        // The last turn of a chunk opens the next one.
        #expect(chunks[1].text.hasPrefix("Mario:"))
        #expect(Chunker.text("Primo paragrafo.\n\nSecondo paragrafo.").count == 1)
    }

    @Test func meaningFindsWhatWordsMiss() async throws {
        let archive = try memoryArchive()
        let project = try archive.createProject(name: "Fondo")
        let call = try archive.createItem(
            title: "Call di prova", occurredAt: Date(), source: .recording, status: .transcribed)
        try archive.updateItem(call.id) { $0.projectId = project.id }
        let other = try archive.createItem(title: "Logo", occurredAt: Date(), source: .recording, status: .transcribed)
        try archive.updateItem(other.id) { $0.projectId = project.id }
        let embedder = FakeEmbedder()
        try await SemanticIndexer.index(
            [ChunkDraft(text: "Mario: l'azienda versa il 2% ogni mese", startSec: 120, endSec: 180)], itemID: call.id,
            noteID: nil, source: .transcript, archive: archive, embedder: embedder)
        try await SemanticIndexer.index(
            [ChunkDraft(text: "Anna: il logo resta blu", startSec: 10, endSec: 30)], itemID: other.id, noteID: nil,
            source: .transcript, archive: archive, embedder: embedder)
        let cache = VectorCache()
        #expect(try archive.search("contributo datoriale", scope: .project(project.id)).isEmpty)
        let hits = try await HybridSearch.search(
            "contributo datoriale", scope: .project(project.id), archive: archive, embedder: embedder, cache: cache)
        #expect(hits.first?.itemID == call.id && hits.first?.byMeaning == true && hits.first?.atSec == 120)
        #expect(!hits.contains { $0.itemID == other.id })
        // Without an embedder it is the search by words.
        let plain = try await HybridSearch.search(
            "contributo datoriale", scope: .project(project.id), archive: archive, embedder: nil, cache: cache)
        #expect(plain.isEmpty)
    }

    @Test func suggestionsCoverKeyPointsSpeakersTagsProjectsAndLinks() async throws {
        let archive = try memoryArchive()
        let project = try archive.createProject(name: "Fondo pensione")
        let older = try archive.createItem(
            title: "Kickoff fondo", occurredAt: Date(), source: .recording, status: .transcribed)
        try archive.updateItem(older.id) { $0.projectId = project.id }
        try archive.setTags(["previdenza", "payroll"], for: older.id)
        let active = try archive.createDecision(
            Decision(text: "Contributo azienda al 1,5%", decidedAt: Date(), projectId: project.id, origin: .manual))
        let call = try archive.createItem(
            title: "Call di prova", occurredAt: Date(), source: .recording, status: .transcribed)
        let embedder = FakeEmbedder()
        try await SemanticIndexer.index(
            [ChunkDraft(text: "il fondo pensione e il contributo dell'azienda")], itemID: older.id, noteID: nil,
            source: .transcript, archive: archive, embedder: embedder)
        try await SemanticIndexer.index(
            [ChunkDraft(text: "contributo dell'azienda al fondo pensione")], itemID: call.id, noteID: nil,
            source: .transcript, archive: archive, embedder: embedder)
        let lines: [KeyPointExtractor.Line] = [
            .init(atSec: 10, speaker: "Speaker 1", text: "Buongiorno, sono Anna dell'ufficio HR di Assicura."),
            .init(atSec: 120, speaker: "Io", text: "Va bene, facciamo il contributo dell'azienda al 2% da gennaio."),
        ]
        let engine = FakeEngine { _ in "" }
        let answering = FakeEngine { prompt in
            if prompt.contains("TAG ESISTENTI") {
                // A tag of another call with an invented quote, and a new tag with no ground, are dropped.
                return #"""
                    {"esistenti": [{"tag": "previdenza", "citazione": "il contributo dell'azienda al 2% da gennaio"},
                    {"tag": "payroll", "citazione": "parliamo delle buste paga di tutti"}, "inventato"],
                    "nuovi": [{"tag": "contributo", "citazione": "non detto"}, "tfr"]}
                    """#
            }
            if prompt.hasPrefix("Io:") || prompt.hasPrefix("Speaker 1:") {
                return
                    #"{"speaker": [{"etichetta": "Speaker 1", "nome": "Anna", "citazione": "sono Anna dell'ufficio HR di Assicura"}]}"#
            }
            return
                #"{"decisioni": [{"testo": "Contributo azienda al 2%", "citazione": "facciamo il contributo dell'azienda al 2% da gennaio", "sicurezza": "alta"}], "attivita": []}"#
        }
        _ = engine
        let proposals = try await SuggestionEngine.propose(
            .init(
                itemID: call.id, projectID: nil, lines: lines, isCall: true,
                speakers: ["me": "Io", "s1": "Speaker 1"]), engine: answering, embedder: embedder, archive: archive)
        let kinds = proposals.map(\.kind)
        #expect(
            kinds.contains(.decision) && kinds.contains(.person) && kinds.contains(.tag) && kinds.contains(.project))
        #expect(proposals.first { $0.kind == .person }?.payload.targetID == "s1")
        let tags = proposals.filter { $0.kind == .tag }.map(\.payload)
        #expect(Set(tags.map(\.text)) == ["previdenza", "contributo"])
        #expect(tags.first { $0.text == "previdenza" }?.atSec == 120)
        #expect(proposals.first { $0.kind == .project }?.payload.targetID == project.id)
        // In the project, the decision may supersede the active one and the older call is related.
        try archive.updateItem(call.id) { $0.projectId = project.id }
        let inProject = try await SuggestionEngine.propose(
            .init(itemID: call.id, projectID: project.id, lines: lines, isCall: true, speakers: [:]),
            engine: answering, embedder: embedder, archive: archive)
        #expect(inProject.first { $0.kind == .decision }?.payload.supersedesID == active.id)
        #expect(inProject.first { $0.kind == .link }?.payload.targetID == older.id)
    }

    @Test func chatAnswersFromNumberedSourcesAndCitesThem() async throws {
        let archive = try memoryArchive()
        let project = try archive.createProject(name: "Fondo")
        let call = try archive.createItem(
            title: "Call di prova", occurredAt: Date(), source: .recording, status: .transcribed)
        try archive.updateItem(call.id) { $0.projectId = project.id }
        try await SemanticIndexer.index(
            [ChunkDraft(text: "Io: l'azienda versa il 2%", startSec: 120, endSec: 140)], itemID: call.id, noteID: nil,
            source: .transcript, archive: archive, embedder: FakeEmbedder())
        _ = try archive.createDecision(
            Decision(text: "Contributo azienda al 2%", decidedAt: Date(), projectId: project.id, origin: .manual))
        let sources = try await ChatAnswerer.sources(
            for: "Quanto è il contributo dell'azienda?", scope: .project(project.id), archive: archive,
            embedder: FakeEmbedder(), cache: VectorCache())
        #expect(sources.map(\.kind) == [.call, .decision])
        #expect(sources[0].atSec == 120)
        let engine = FakeEngine { _ in "- L'azienda versa il 2% [1][2], come deciso [2]. [7]" }
        let answer = try await ChatAnswerer.answer(
            "Quanto è il contributo dell'azienda?", sources: sources, engine: engine)
        #expect(ChatAnswerer.citations(in: answer, sources: sources) == [1, 2])
        #expect(engine.requests[0].prompt.contains("[1] Call «Call di prova»"))
        #expect(engine.requests[0].prompt.contains("Decisione ATTIVA"))
        let nothing = try await ChatAnswerer.answer("Altro?", sources: [], engine: engine)
        #expect(nothing.contains("Non trovo nulla"))
    }
}
