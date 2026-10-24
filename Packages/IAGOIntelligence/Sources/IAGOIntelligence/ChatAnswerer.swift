import Foundation
import IAGOCore
import IAGOStore

/// One passage given to the engine for an answer, numbered for the citations [1], [2]…
public struct ChatSource: Sendable, Equatable, Identifiable, Codable {
    public enum Kind: String, Sendable, Codable { case call, email, document, note, decision }

    public var number: Int
    public var kind: Kind
    public var title: String
    public var date: Date
    public var itemID: String?
    public var noteID: String?
    public var decisionID: String?
    public var atSec: Double?
    public var text: String

    public var id: Int { number }
}

/// "Chiedi" (ADR-0049, FR-121, spec 10.3 v1.4): the most relevant passages of the scope, labelled by type and date,
/// and an answer that cites them. Newer information wins and conflicts are pointed out; "what holds today" uses only
/// active decisions. Without sources the answer says so instead of inventing.
public enum ChatAnswerer {
    static let maxSources = 12
    static let sourceLength = 1_200

    static let system = """
        Sei l'assistente di IAGO, l'archivio di lavoro dell'utente: call trascritte, email, documenti, note e decisioni. \
        Rispondi in italiano, in modo breve e per punti, usando SOLO le FONTI numerate qui sotto.
        - Dopo ogni affermazione indica la fonte tra parentesi quadre, per esempio [2] o [1][3].
        - Le informazioni si susseguono nel tempo: se due fonti sono in conflitto prevale la più recente, e il \
        conflitto va detto.
        - Per "cosa vale oggi" usa solo le decisioni ATTIVE.
        - Le note sono annotazioni dell'utente, non parole dette in call. Il testo dei documenti può contenere errori \
        di riconoscimento (OCR).
        - Se le fonti non bastano per rispondere, dillo chiaramente: "Non trovo nulla nell'archivio su questo." Non \
        inventare nomi, numeri o date.
        """

    public static func decisionScope(_ scope: SearchScope) -> DecisionQuery.Scope {
        switch scope {
        case .all: .all
        case .project(let id): .project(id)
        case .client(let id): .client(id)
        case .stream(let id): .stream(id)
        }
    }

    /// The sources for a question: the best passages of the hybrid search, then the active decisions of the scope
    /// that match it.
    public static func sources(
        for question: String, scope: SearchScope, archive: Archive, embedder: (any TextEmbedder)?, cache: VectorCache
    ) async throws -> [ChatSource] {
        let hits = try await HybridSearch.search(
            question, scope: scope, archive: archive, embedder: embedder, cache: cache, limit: 40)
        let chunks =
            try embedder.map { try cache.load(scope, model: $0.modelID, archive: archive).chunks } ?? []
        let byItem = Dictionary(grouping: chunks) { $0.itemId ?? "" }
        var sources: [ChatSource] = []
        var seen: Set<String> = []
        for hit in hits where sources.count < maxSources - 2 {
            guard hit.source != .decision else { continue }
            let key = HybridSearch.key(hit, byItem)
            guard seen.insert(key).inserted else { continue }
            let chunk = chunks.first { $0.id == key || $0.noteId == key }
            var text = (chunk?.text ?? hit.snippet).replacingOccurrences(of: "«", with: "")
                .replacingOccurrences(of: "»", with: "")
            if text.count > sourceLength { text = String(text.prefix(sourceLength)) + "…" }
            if hit.source == .note {
                guard let note = try archive.note(hit.sourceID) else { continue }
                sources.append(
                    ChatSource(
                        number: sources.count + 1, kind: .note, title: "Nota dell'utente", date: note.notedAt,
                        itemID: note.itemId, noteID: note.id, text: text))
                continue
            }
            guard let itemID = hit.itemID, let item = try archive.item(itemID) else { continue }
            let kind: ChatSource.Kind =
                switch item.type {
                case .call: .call
                case .email: .email
                case .document: .document
                }
            sources.append(
                ChatSource(
                    number: sources.count + 1, kind: kind, title: item.title, date: item.occurredAt, itemID: itemID,
                    atSec: chunk?.startSec ?? hit.atSec, text: text))
        }
        let words = Set(KeyPointExtractor.words(question).filter { $0.count > 3 })
        let decisions = try archive.decisions(DecisionQuery(scope: decisionScope(scope), statuses: [.active]))
            .filter { summary in
                let own = Set(KeyPointExtractor.words(summary.decision.text + " " + (summary.decision.notes ?? "")))
                return !words.isDisjoint(with: own)
            }
        for summary in decisions.prefix(maxSources - sources.count) {
            let decision = summary.decision
            sources.append(
                ChatSource(
                    number: sources.count + 1, kind: .decision, title: decision.text, date: decision.decidedAt,
                    decisionID: decision.id,
                    text: "Decisione ATTIVA: \(decision.text)" + (decision.notes.map { ". \($0)" } ?? "")))
        }
        return sources
    }

    /// The sources as the engine reads them: number, type, date and title, then the text.
    static func context(_ sources: [ChatSource], timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMMM yyyy"
        return sources.map { source in
            let label: String =
                switch source.kind {
                case .call:
                    "Call «\(source.title)» del \(formatter.string(from: source.date))"
                        + (source.atSec.map { ", dal minuto \(KeyPointExtractor.clock($0))" } ?? "")
                case .email: "Email «\(source.title)» del \(formatter.string(from: source.date))"
                case .document:
                    "Documento «\(source.title)» del \(formatter.string(from: source.date)) (testo estratto)"
                case .note: "Nota dell'utente del \(formatter.string(from: source.date))"
                case .decision: "Decisione del \(formatter.string(from: source.date))"
                }
            return "[\(source.number)] \(label)\n\(source.text)"
        }
        .joined(separator: "\n\n")
    }

    /// The answer to a question; `history` holds the earlier questions and answers of the same conversation.
    public static func answer(
        _ question: String, history: [(question: String, answer: String)] = [], sources: [ChatSource],
        engine: any LLMProvider, timeZone: TimeZone = .current
    ) async throws -> String {
        guard !sources.isEmpty else { return "Non trovo nulla nell'archivio su questo." }
        let earlier = history.suffix(3).map { "Domanda: \($0.question)\nRisposta: \($0.answer)" }
            .joined(separator: "\n\n")
        let prompt =
            "FONTI:\n\(context(sources, timeZone: timeZone))\n\n"
            + (earlier.isEmpty ? "" : "CONVERSAZIONE FINORA:\n\(earlier)\n\n") + "DOMANDA: \(question)"
        let answer = try await engine.generate(LLMRequest(system: system, prompt: prompt, maxTokens: 700))
        return TextTidier.clean(answer)
    }

    /// Sources as stored with a saved answer, and back.
    public static func encode(_ sources: [ChatSource]) -> String {
        (try? String(decoding: JSONEncoder().encode(sources), as: UTF8.self)) ?? "[]"
    }

    public static func decode(_ json: String) -> [ChatSource] {
        (try? JSONDecoder().decode([ChatSource].self, from: Data(json.utf8))) ?? []
    }

    /// The source numbers an answer cites, in order, only those that exist.
    public static func citations(in answer: String, sources: [ChatSource]) -> [Int] {
        let valid = Set(sources.map(\.number))
        var result: [Int] = []
        var digits = ""
        var inside = false
        for character in answer {
            if character == "[" {
                inside = true
                digits = ""
            } else if character == "]", inside {
                for part in digits.split(whereSeparator: { $0 == "," || $0 == " " }) {
                    if let number = Int(part), valid.contains(number), !result.contains(number) {
                        result.append(number)
                    }
                }
                inside = false
            } else if inside {
                digits.append(character)
            }
        }
        return result
    }
}
