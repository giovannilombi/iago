import Foundation
import IAGOCore

/// A decision or activity proposed by the local engine from a call (ADR-0048; FR-110 in block 5). Always a proposal:
/// it carries the verbatim quote it comes from, checked against the transcript.
public struct ProposedKeyPoint: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable { case decision, activity }
    public enum Confidence: String, Sendable, Codable, Comparable {
        case high, medium, low

        var rank: Int {
            switch self {
            case .high: 2
            case .medium: 1
            case .low: 0
            }
        }

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
    }

    public var kind: Kind
    public var text: String
    /// The sentence of the transcript it comes from, as found there.
    public var quote: String
    /// Second of the call where the quote is.
    public var atSec: Double
    /// Who does it (activities), when the transcript says so.
    public var owner: String?
    public var confidence: Confidence
}

/// Decisions and activities from a transcript, with rules a small model (4B, 16 GB Macs) can follow and checks IAGO
/// makes itself instead of trusting the model:
/// - strict definitions with examples of what is and is not a decision;
/// - the call in blocks of about 10 minutes, merged at the end;
/// - every item must quote the transcript verbatim: a quote IAGO cannot find is discarded;
/// - a confidence for every item: low ones are dropped, and there is a ceiling per call.
public enum KeyPointExtractor {
    public struct Line: Sendable, Equatable {
        public var atSec: Double
        public var speaker: String
        public var text: String

        public init(atSec: Double, speaker: String, text: String) {
            self.atSec = atSec
            self.speaker = speaker
            self.text = text
        }
    }

    public struct Result: Sendable, Equatable {
        public var items: [ProposedKeyPoint]
        /// What the model proposed and IAGO dropped, with the reason (for the trial and the logs, never shown as
        /// proposals).
        public var discarded: [(item: String, reason: String)]

        public static func == (lhs: Result, rhs: Result) -> Bool {
            lhs.items == rhs.items && lhs.discarded.map(\.item) == rhs.discarded.map(\.item)
        }
    }

    static let blockSeconds: Double = 600
    static let blockCharacters = 10_000
    /// The longest line a block takes whole: longer ones (a pasted JSON, a text without line breaks) are cut, so a
    /// block never goes much beyond `blockCharacters` and a request never fills the memory.
    static let lineCharacters = 2_500
    static let maxItems = 12

    static let system = """
        Leggi un pezzo della trascrizione di una call di lavoro ed estrai solo DECISIONI e ATTIVITÀ.

        DECISIONE: una scelta concordata tra i partecipanti che cambia cosa si farà o come.
        Sono decisioni: "Allora facciamo il contributo al 2%", "Va bene, scegliamo il profilo prudente", \
        "Partiamo con il sito solo per il primo cliente". Sono decisioni anche chi è il referente o chi segue cosa, \
        quando viene concordato ("il referente per voi è Alessandro").
        NON sono decisioni: i dati letti da un modulo (indirizzo, telefono, codici), le conferme di \
        un'informazione già nota ("sì, è un dipendente"), le domande, le ipotesi ("potremmo…"), le spiegazioni.

        ATTIVITÀ: qualcosa che una persona si impegna a fare dopo la call.
        Sono attività: "Ti mando il modulo domani", "Chiamo Anna per la conferma", "Verifico il livello del CCNL".
        NON sono attività: ciò che si sta facendo durante la call, i consigli generici.

        Per ogni voce riporta in "citazione" la frase ESATTA della trascrizione da cui la ricavi, copiata parola per \
        parola, senza il minuto e senza il nome di chi parla. Se non trovi una frase precisa, non inserire la voce.
        "sicurezza": "alta" se la scelta o l'impegno è detto chiaramente, "media" se è implicito, "bassa" se è incerto.
        Meglio poche voci giuste che molte dubbie. Se nel pezzo non c'è nulla, rispondi con liste vuote.

        Rispondi solo con JSON valido, senza altro testo:
        {"decisioni": [{"testo": "breve, in italiano", "citazione": "...", "sicurezza": "alta"}],
         "attivita": [{"testo": "breve, in italiano", "chi": "nome o null", "citazione": "...", "sicurezza": "alta"}]}
        """

    public static func extract(_ lines: [Line], with engine: any LLMProvider) async throws -> Result {
        var items: [ProposedKeyPoint] = []
        var discarded: [(String, String)] = []
        for block in blocks(lines) {
            try Task.checkCancellation()
            let prompt = block.map {
                $0.speaker.isEmpty ? $0.text : "[\(clock($0.atSec))] \($0.speaker): \($0.text)"
            }.joined(separator: "\n")
            let answer = try await engine.generate(LLMRequest(system: system, prompt: prompt, maxTokens: 1_000))
            let parsed = parse(answer)
            for candidate in parsed {
                guard let atSec = locate(candidate.quote, in: block) else {
                    discarded.append((candidate.text, "citazione non trovata nella trascrizione"))
                    continue
                }
                guard candidate.confidence > .low else {
                    discarded.append((candidate.text, "sicurezza bassa"))
                    continue
                }
                var item = candidate
                item.atSec = atSec
                if items.contains(where: { similar($0, item) }) {
                    discarded.append((candidate.text, "doppione"))
                    continue
                }
                items.append(item)
            }
        }
        // The ceiling keeps the surest ones, then the call order.
        let kept = items.enumerated().sorted {
            ($0.element.confidence, -$0.offset) > ($1.element.confidence, -$1.offset)
        }
        .prefix(maxItems).sorted { $0.offset < $1.offset }.map(\.element)
        for dropped in items where !kept.contains(dropped) {
            discarded.append((dropped.text, "oltre il massimo per call"))
        }
        return Result(items: kept, discarded: discarded)
    }

    /// Lines in blocks of about `blockSeconds` or `blockCharacters`, cut between lines; a line longer than
    /// `lineCharacters` is cut first.
    static func blocks(_ lines: [Line]) -> [[Line]] {
        var result: [[Line]] = []
        var current: [Line] = []
        var start: Double?
        var characters = 0
        let lines = lines.flatMap { line in
            TextPieces.split(line.text, limit: lineCharacters).map {
                Line(atSec: line.atSec, speaker: line.speaker, text: $0)
            }
        }
        for line in lines {
            // Blocks of ~10 minutes of call; texts without times (emails, documents) by length.
            if let first = start, line.atSec - first >= blockSeconds || characters > blockCharacters, !current.isEmpty {
                result.append(current)
                current = []
                start = nil
                characters = 0
            }
            characters += line.text.count
            if start == nil { start = line.atSec }
            current.append(line)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    // MARK: Answer

    static func parse(_ answer: String) -> [ProposedKeyPoint] {
        guard let open = answer.firstIndex(of: "{"), let close = answer.lastIndex(of: "}"), open < close,
            let object = try? JSONSerialization.jsonObject(with: Data(answer[open...close].utf8)) as? [String: Any]
        else { return [] }
        func items(_ key: String, _ kind: ProposedKeyPoint.Kind) -> [ProposedKeyPoint] {
            (object[key] as? [[String: Any]] ?? []).compactMap { entry in
                guard let text = (entry["testo"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !text.isEmpty, let quote = entry["citazione"] as? String
                else { return nil }
                let owner = (entry["chi"] as? String).flatMap { $0.isEmpty || $0 == "null" ? nil : $0 }
                let confidence: ProposedKeyPoint.Confidence =
                    switch (entry["sicurezza"] as? String)?.lowercased() {
                    case "alta": .high
                    case "media": .medium
                    default: .low
                    }
                return ProposedKeyPoint(
                    kind: kind, text: text, quote: quote, atSec: 0, owner: owner, confidence: confidence)
            }
        }
        return items("decisioni", .decision) + items("attivita", .activity) + items("attività", .activity)
    }

    // MARK: Checks

    /// The second of the line holding the quote, or nil. Models copy quotes loosely, so case, accents, punctuation and
    /// small rewordings do not count: at least three quarters of the quote's meaningful words (4+ letters, at least
    /// 3 of them) must be in one line or in two consecutive lines. Numbers are strict: every number in the quote must
    /// be there, so an invented amount or percentage is always discarded.
    /// `span`: how many consecutive lines may hold the quote (2 for key points; summaries paraphrase more).
    static func locate(_ quote: String, in block: [Line], span: Int = 2) -> Double? {
        let wanted = words(quote)
        let meaningful = Set(wanted.filter { $0.count >= 4 && !$0.allSatisfy(\.isNumber) })
        let numbers = Set(wanted.filter { $0.contains(where: \.isNumber) })
        guard meaningful.count >= 3 || (meaningful.count >= 2 && !numbers.isEmpty) else { return nil }
        func coverage(_ words: Set<String>) -> Double {
            Double(meaningful.intersection(words).count) / Double(meaningful.count)
        }
        // The line that holds most of the quote by itself wins; the next line only completes it.
        var best: (own: Double, pair: Double, atSec: Double)?
        for (index, line) in block.enumerated() {
            let own = Set(words(line.text))
            let pair = block[index..<min(block.count, index + max(span, 1))].reduce(into: own) {
                $0.formUnion(words($1.text))
            }
            guard numbers.isSubset(of: pair) else { continue }
            let candidate = (own: coverage(own), pair: coverage(pair), atSec: line.atSec)
            guard candidate.pair >= 0.75, candidate.own > 0 else { continue }
            if best == nil || (candidate.own, candidate.pair) > (best!.own, best!.pair) { best = candidate }
        }
        return best?.atSec
    }

    static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    static func similar(_ a: ProposedKeyPoint, _ b: ProposedKeyPoint) -> Bool {
        guard a.kind == b.kind else { return false }
        let left = Set(words(a.text).filter { $0.count > 3 })
        let right = Set(words(b.text).filter { $0.count > 3 })
        guard !left.isEmpty, !right.isEmpty else { return false }
        return Double(left.intersection(right).count) / Double(min(left.count, right.count)) >= 0.7
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
