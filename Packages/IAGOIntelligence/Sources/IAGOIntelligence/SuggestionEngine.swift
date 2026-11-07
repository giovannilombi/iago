import Foundation
import IAGOCore
import IAGOStore

/// What the engine proposes for one item (ADR-0049, FR-110/111, ADR-0074): decisions, activities (with owner,
/// deadline, who we wait for), points to clear up, risks and requests; what they may supersede or close; names for
/// generic speakers, tags, a project for unclassified items and related items. Only proposals: the app stores them
/// as `Suggestion` and applies one only when the user confirms it.
public enum SuggestionEngine {
    public struct Input: Sendable {
        public var itemID: String
        public var projectID: String?
        /// The text as lines; calls have times and speakers, other items one line per paragraph.
        public var lines: [KeyPointExtractor.Line]
        public var isCall: Bool
        /// Speaker id → label, for calls: generic labels ("Speaker 2") may get a name.
        public var speakers: [String: String]
        /// When the call took place or the email arrived: "venerdì" counts from here (ADR-0074).
        public var date: Date?
        /// Key points are proposed too: not for items of a project in «Raccogli» (ADR-0098).
        public var keyPoints = true

        public init(
            itemID: String, projectID: String?, lines: [KeyPointExtractor.Line], isCall: Bool,
            speakers: [String: String] = [:], date: Date? = nil
        ) {
            self.itemID = itemID
            self.projectID = projectID
            self.lines = lines
            self.isCall = isCall
            self.speakers = speakers
            self.date = date
        }
    }

    public typealias Proposal = (kind: Suggestion.Kind, payload: SuggestionPayload)

    public static func propose(
        _ input: Input, engine: any LLMProvider, embedder: (any TextEmbedder)?, archive: Archive
    ) async throws -> [Proposal] {
        var proposals: [Proposal] = []
        if input.keyPoints {
            proposals += try await keyPoints(input, engine: engine, embedder: embedder, archive: archive)
        }
        if input.isCall { proposals += try await speakerNames(input, engine: engine) }
        proposals += try await tags(input, engine: engine, archive: archive)
        if let embedder {
            proposals += try neighbours(input, model: embedder.modelID, archive: archive)
        }
        return proposals
    }

    /// Decisions, activities, points to clear up, risks and requests, with what they may supersede or close.
    static func keyPoints(
        _ input: Input, engine: any LLMProvider, embedder: (any TextEmbedder)?, archive: Archive
    ) async throws -> [Proposal] {
        var proposals: [Proposal] = []
        let points = try await KeyPointExtractor.extract(
            input.lines, context: .init(date: input.date, openEntries: try openEntries(input.projectID, archive)),
            with: engine)
        let active =
            try input.projectID.map {
                try archive.decisions(DecisionQuery(scope: .project($0), statuses: [.active], kinds: [.decision]))
            } ?? []
        for point in points.items {
            var payload = SuggestionPayload(
                text: point.text, quote: point.quote, atSec: input.isCall ? point.atSec : nil, owner: point.owner,
                confidence: point.confidence == .high ? "high" : "medium", supersedesID: point.closesID,
                due: point.due, waitingOn: point.waitingOn, severity: point.severity)
            if point.kind == .decision, payload.supersedesID == nil,
                let previous = try await supersedable(point.text, active, embedder)
            {
                payload.supersedesID = previous.id
            }
            proposals.append((kind(point.kind), payload))
        }
        return proposals
    }

    static func kind(_ kind: ProposedKeyPoint.Kind) -> Suggestion.Kind {
        switch kind {
        case .decision: .decision
        case .activity: .activity
        case .question: .question
        case .risk: .risk
        case .request: .request
        }
    }

    // MARK: Supersede

    /// The open points to clear up and requests of the project, the most recent first: a decision of this item may
    /// answer one, a decision or an activity may accept one (ADR-0074).
    static func openEntries(_ projectID: String?, _ archive: Archive) throws -> [KeyPointExtractor.OpenEntry] {
        guard let projectID else { return [] }
        return try archive.decisions(
            DecisionQuery(
                scope: .project(projectID), statuses: DecisionQuery.current, kinds: [.openQuestion, .request])
        )
        .sorted { $0.decision.decidedAt > $1.decision.decidedAt }
        .prefix(KeyPointExtractor.maxOpenEntries)
        .map {
            .init(id: $0.decision.id, kind: $0.decision.kind == .request ? .request : .question, text: $0.decision.text)
        }
    }

    /// An active decision of the project that the proposal probably replaces: the same topic, by meaning when an
    /// embedder is there, by words otherwise.
    static func supersedable(_ text: String, _ active: [DecisionSummary], _ embedder: (any TextEmbedder)?) async throws
        -> DecisionSummary?
    {
        guard !active.isEmpty else { return nil }
        if let embedder {
            let vectors = try await embedder.embed([text] + active.map(\.decision.text), query: false)
                .map(VectorMath.normalized)
            guard let query = vectors.first else { return nil }
            let scores = vectors.dropFirst().map { zip(query, $0).reduce(0) { $0 + $1.0 * $1.1 } }
            if let best = scores.enumerated().max(by: { $0.element < $1.element }), best.element >= 0.8 {
                return active[best.offset]
            }
            return nil
        }
        let words = Set(KeyPointExtractor.words(text).filter { $0.count > 3 })
        return active.first { summary in
            let other = Set(KeyPointExtractor.words(summary.decision.text).filter { $0.count > 3 })
            return !other.isEmpty && Double(words.intersection(other).count) / Double(other.count) >= 0.6
        }
    }

    // MARK: Speakers

    static let speakerSystem = """
        Nella trascrizione di una call alcuni partecipanti hanno un'etichetta generica ("Speaker 1", "Speaker 2"). \
        Indica il nome di ciascuno SOLO se la trascrizione lo rende evidente: si presenta ("sono Anna"), viene \
        chiamato per nome da altri e risponde, o firma ciò che dice. Non indovinare. Per ogni nome riporta la frase \
        ESATTA della trascrizione che lo dimostra.
        Rispondi solo con JSON: {"speaker": [{"etichetta": "Speaker 2", "nome": "Anna", "citazione": "..."}]}
        """

    static func isGeneric(_ label: String) -> Bool {
        label.hasPrefix("Speaker") || label.hasPrefix("Stanza") || label.hasPrefix("Partecipante")
    }

    static func speakerNames(_ input: Input, engine: any LLMProvider) async throws -> [Proposal] {
        let generic = input.speakers.filter { isGeneric($0.value) }
        guard !generic.isEmpty else { return [] }
        let excerpt = input.lines.prefix(400).map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
        let answer = try await engine.generate(
            LLMRequest(system: speakerSystem, prompt: String(excerpt.prefix(12_000)), maxTokens: 400))
        guard let object = jsonObject(answer), let entries = object["speaker"] as? [[String: Any]] else { return [] }
        var proposals: [Proposal] = []
        for entry in entries {
            guard let label = entry["etichetta"] as? String, let name = entry["nome"] as? String,
                let quote = entry["citazione"] as? String,
                let speakerID = generic.first(where: { $0.value == label })?.key,
                !name.isEmpty, !isGeneric(name),
                let atSec = KeyPointExtractor.locate(quote, in: input.lines),
                KeyPointExtractor.words(quote).contains(where: {
                    KeyPointExtractor.words(name).contains($0)
                })
            else { continue }
            proposals.append(
                (.person, SuggestionPayload(text: name, quote: quote, atSec: atSec, targetID: speakerID, reason: label))
            )
        }
        return proposals
    }

    // MARK: Tags

    /// New tags in the language of the app (ADR-0077).
    static var tagSystem: String {
        tagSystemItalian.replacingOccurrences(of: "in italiano", with: ContentLanguage.current.inLanguage)
    }

    static let tagSystemItalian = """
        Scegli i temi di un contenuto di lavoro. Ricevi l'elenco dei TAG ESISTENTI e il testo.
        Scegli fino a 5 tag tra quelli esistenti solo se il testo parla davvero di quel tema: l'elenco viene da altri \
        contenuti e di solito quasi nessun tag va bene, quindi l'elenco vuoto è una risposta normale. Proponi al \
        massimo 3 tag nuovi solo se nessun tag esistente va bene: una o due parole, minuscole, in italiano.
        Per ogni tag copia dal testo la frase che ne parla, parola per parola.
        Rispondi solo con JSON: {"esistenti": [{"tag": "...", "citazione": "..."}], "nuovi": [{"tag": "...", \
        "citazione": "..."}]}
        """

    static func tags(_ input: Input, engine: any LLMProvider, archive: Archive) async throws -> [Proposal] {
        let existing = try archive.allTags().map(\.name)
        let current = Set(try archive.tags(for: input.itemID).map { $0.name.lowercased() })
        let text = input.lines.map(\.text).joined(separator: "\n")
        let answer = try await engine.generate(
            LLMRequest(
                system: tagSystem,
                prompt: "TAG ESISTENTI: \(existing.joined(separator: ", "))\n\nTESTO:\n\(text.prefix(8_000))",
                maxTokens: 400))
        guard let object = jsonObject(answer) else { return [] }
        let byName = Dictionary(existing.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let textWords = Set(KeyPointExtractor.words(text))
        var proposals: [Proposal] = []
        for entry in tagEntries(object["esistenti"]).prefix(5) {
            guard let tag = byName[entry.name.lowercased()], !current.contains(tag.lowercased()),
                let payload = grounded(tag, quote: entry.quote, isNew: false, in: input.lines, words: textWords)
            else { continue }
            proposals.append((.tag, payload))
        }
        for entry in tagEntries(object["nuovi"]).prefix(3) {
            let clean = entry.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !clean.isEmpty, clean.split(separator: " ").count <= 3, byName[clean] == nil,
                !current.contains(clean),
                let payload = grounded(clean, quote: entry.quote, isNew: true, in: input.lines, words: textWords)
            else { continue }
            proposals.append((.tag, payload))
        }
        return proposals
    }

    /// The tags of an answer, with their quotes; a bare name (the older form) has none.
    static func tagEntries(_ value: Any?) -> [(name: String, quote: String?)] {
        (value as? [Any] ?? []).compactMap { entry in
            if let name = entry as? String { return (name, nil) }
            guard let entry = entry as? [String: Any], let name = entry["tag"] as? String else { return nil }
            return (name, entry["citazione"] as? String)
        }
    }

    /// A tag is proposed only if the text talks about it: its quote is found in the text (shown with the proposal,
    /// at its minute), or failing that the tag's own words are in the text. A small model otherwise picks tags
    /// of other calls from the list just because they are there.
    static func grounded(
        _ tag: String, quote: String?, isNew: Bool, in lines: [KeyPointExtractor.Line], words: Set<String>
    ) -> SuggestionPayload? {
        if let quote, let line = KeyPointExtractor.locateLine(quote, in: lines) {
            return SuggestionPayload(text: tag, quote: quote, atSec: lines[line].atSec, isNew: isNew)
        }
        let own = KeyPointExtractor.words(tag)
        guard !own.isEmpty, own.allSatisfy(words.contains) else { return nil }
        return SuggestionPayload(text: tag, isNew: isNew)
    }

    // MARK: Project and related items

    static let projectThreshold: Float = 0.6
    static let projectMargin: Float = 0.04
    static let linkThreshold: Float = 0.78

    /// By meaning, from the vectors already in the index: the project whose content is closest, for an item without
    /// one; for every item, up to 3 items of the same project that talk about the same things.
    static func neighbours(_ input: Input, model: String, archive: Archive) throws -> [Proposal] {
        let all = try archive.chunks(.all, model: model)
        let own = all.filter { $0.itemId == input.itemID && $0.noteId == nil }
        guard let centroid = Self.centroid(own.map(\.values)) else { return [] }
        var proposals: [Proposal] = []
        let items = Dictionary(
            grouping: all.filter { $0.itemId != nil && $0.itemId != input.itemID && $0.noteId == nil }
        ) {
            $0.itemId!
        }
        let projects = try archive.projects()
        if input.projectID == nil {
            var byProject: [String: [[Float]]] = [:]
            for (itemID, chunks) in items {
                guard let projectID = try archive.item(itemID)?.projectId else { continue }
                byProject[projectID, default: []] += chunks.map(\.values)
            }
            let ranked = byProject.compactMap { id, vectors -> (String, Float)? in
                guard let center = Self.centroid(vectors) else { return nil }
                return (id, dot(centroid, center))
            }
            .sorted { $0.1 > $1.1 }
            if let best = ranked.first, best.1 >= projectThreshold,
                ranked.count == 1 || best.1 - ranked[1].1 >= projectMargin,
                let project = projects.first(where: { $0.id == best.0 })
            {
                proposals.append(
                    (
                        .project,
                        SuggestionPayload(
                            text: project.name, targetID: project.id,
                            reason: "Il contenuto è simile a quello degli elementi di «\(project.name)»")
                    ))
            }
        } else {
            let linked = Set(try archive.links(itemID: input.itemID).map(\.item.id))
            var candidates: [(Item, Float)] = []
            for (itemID, chunks) in items where !linked.contains(itemID) {
                guard let item = try archive.item(itemID), item.projectId == input.projectID,
                    item.trashedAt == nil, item.deletedAt == nil, let center = Self.centroid(chunks.map(\.values))
                else { continue }
                let score = dot(centroid, center)
                if score >= linkThreshold { candidates.append((item, score)) }
            }
            for (item, _) in candidates.sorted(by: { $0.1 > $1.1 }).prefix(3) {
                proposals.append(
                    (.link, SuggestionPayload(text: item.title, targetID: item.id, reason: "Parla degli stessi temi")))
            }
        }
        return proposals
    }

    static func centroid(_ vectors: [[Float]]) -> [Float]? {
        guard let first = vectors.first else { return nil }
        var sum = [Float](repeating: 0, count: first.count)
        for vector in vectors where vector.count == sum.count {
            for index in sum.indices { sum[index] += vector[index] }
        }
        return VectorMath.normalized(sum)
    }

    static func dot(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        return zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }

    static func jsonObject(_ answer: String) -> [String: Any]? {
        guard let open = answer.firstIndex(of: "{"), let close = answer.lastIndex(of: "}"), open < close else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: Data(answer[open...close].utf8)) as? [String: Any]
    }
}
