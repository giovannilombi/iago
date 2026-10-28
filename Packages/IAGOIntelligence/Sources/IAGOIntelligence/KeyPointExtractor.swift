import Foundation
import IAGOCore

/// A key point proposed by the local engine from a call, an email or a document (ADR-0048, ADR-0049; FR-110 in block
/// 5): a decision, an activity, a point to clear up, a risk or a request of the client (ADR-0074). Always a proposal:
/// it carries the verbatim quote it comes from, checked against the text.
public struct ProposedKeyPoint: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable {
        case decision, activity
        /// A question asked and not answered ("punto da chiarire").
        case question
        case risk, request
    }
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
    /// Deadline as "yyyy-MM-dd", counted by IAGO from the words of the text and the item's date.
    public var due: String? = nil
    /// Someone else promised it: who we are waiting for (activities).
    public var waitingOn: String? = nil
    /// "high", "medium" or "low" (risks).
    public var severity: String? = nil
    /// The open entry of the project this one answers or accepts ("risponde a", "accoglie").
    public var closesID: String? = nil
}

/// Key points from a transcript, with rules a small model (4B, 16 GB Macs) can follow and checks IAGO makes itself
/// instead of trusting the model:
/// - strict definitions with examples of what is and is not a decision, an activity, a point to clear up…;
/// - the call in blocks of about 10 minutes, merged at the end, all kinds in the same pass;
/// - every item must quote the transcript verbatim: a quote IAGO cannot find is discarded;
/// - deadlines: the model copies the words ("venerdì"), IAGO counts the day from the item's date;
/// - an entry it says it closes must be one of the open entries it was given, of a kind it can close;
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

    /// An open point to clear up or request of the project, which a decision (or, for a request, an activity) of
    /// this item may close.
    public struct OpenEntry: Sendable, Equatable {
        public var id: String
        /// `.question` or `.request`.
        public var kind: ProposedKeyPoint.Kind
        public var text: String

        public init(id: String, kind: ProposedKeyPoint.Kind, text: String) {
            self.id = id
            self.kind = kind
            self.text = text
        }
    }

    /// What the extraction knows besides the text.
    public struct Context: Sendable {
        /// When the call took place or the email arrived: relative deadlines count from here.
        public var date: Date?
        public var openEntries: [OpenEntry]
        public var calendar: Calendar

        public init(date: Date? = nil, openEntries: [OpenEntry] = [], calendar: Calendar = .current) {
            self.date = date
            self.openEntries = openEntries
            self.calendar = calendar
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
    /// Open entries listed in each request, the most recent ones: enough for a project, short for a small model.
    static let maxOpenEntries = 12

    static let system = """
        Leggi un pezzo del testo di una call o di una mail di lavoro ed estrai solo queste voci: DECISIONI, \
        ATTIVITÀ, DOMANDE rimaste aperte, RISCHI e RICHIESTE del cliente.

        DECISIONE: una scelta concordata tra i partecipanti che cambia cosa si farà o come.
        Sono decisioni: "Allora facciamo il contributo al 2%", "Va bene, scegliamo il profilo prudente", \
        "Partiamo con il sito solo per il primo cliente". Sono decisioni anche chi è il referente o chi segue cosa, \
        quando viene concordato ("il referente per voi è Alessandro").
        NON sono decisioni: i dati letti da un modulo (indirizzo, telefono, codici), le conferme di \
        un'informazione già nota ("sì, è un dipendente"), le domande, le ipotesi ("potremmo…"), le spiegazioni.

        ATTIVITÀ: qualcosa che una persona si impegna a fare dopo la call.
        Sono attività: "Ti mando il modulo domani", "Chiamo Anna per la conferma", "Verifico il livello del CCNL".
        NON sono attività: ciò che si sta facendo durante la call, i consigli generici.
        "chi": chi la fa, se è detto. "attende": se è qualcun altro a doverci mandare o fare qualcosa \
        ("Anna ci manda i file entro venerdì"), il suo nome, e allora "chi" è null.
        "entro": le parole ESATTE del testo che dicono la scadenza ("venerdì", "domani", "entro il 10 novembre", \
        "fine mese"), senza calcolare la data; null se non c'è.

        DOMANDA: un punto da chiarire, cioè una domanda fatta e rimasta SENZA risposta nel testo \
        ("Quale provider usiamo per il login? Ci dobbiamo pensare"). NON sono domande quelle a cui qualcuno risponde \
        subito, né quelle di cortesia.

        RISCHIO: qualcosa che può andare storto e che qualcuno segnala ("Se il fornitore ritarda, salta la \
        consegna"). "gravita": "alta", "media" o "bassa".

        RICHIESTA: qualcosa che il cliente chiede di avere o di fare ("Ci servirebbe anche l'accesso con SSO"). \
        NON è una richiesta un impegno preso da noi: quella è un'attività.

        Se prima del testo ci sono VOCI APERTE numerate: quando una decisione risponde a una domanda aperta, o una \
        decisione o un'attività accoglie una richiesta aperta, scrivi il suo numero in "chiude"; altrimenti null.

        Per ogni voce riporta in "citazione" la frase ESATTA della trascrizione da cui la ricavi, copiata parola per \
        parola, senza il minuto e senza il nome di chi parla. Se non trovi una frase precisa, non inserire la voce.
        "sicurezza": "alta" se la cosa è detta chiaramente, "media" se è implicita, "bassa" se è incerta.
        Meglio poche voci giuste che molte dubbie. Se nel pezzo non c'è nulla, rispondi con liste vuote.

        Rispondi solo con JSON valido, senza altro testo:
        {"decisioni": [{"testo": "breve, in italiano", "citazione": "...", "sicurezza": "alta", "chiude": null}],
         "attivita": [{"testo": "breve, in italiano", "chi": null, "attende": null, "entro": null, "citazione": "...", \
        "sicurezza": "alta", "chiude": null}],
         "domande": [{"testo": "la domanda", "citazione": "...", "sicurezza": "alta"}],
         "rischi": [{"testo": "breve", "gravita": "media", "citazione": "...", "sicurezza": "alta"}],
         "richieste": [{"testo": "breve", "citazione": "...", "sicurezza": "alta"}]}
        """

    public static func extract(
        _ lines: [Line], context: Context = Context(), with engine: any LLMProvider
    ) async throws -> Result {
        var items: [ProposedKeyPoint] = []
        var discarded: [(String, String)] = []
        let open = Array(context.openEntries.prefix(maxOpenEntries))
        let header =
            open.isEmpty
            ? ""
            : "VOCI APERTE DEL PROGETTO (per \"chiude\"):\n"
                + open.enumerated().map { index, entry in
                    "[\(index + 1)] \(entry.kind == .question ? "Domanda" : "Richiesta"): "
                        + String(entry.text.prefix(160))
                }.joined(separator: "\n") + "\n\nTESTO:\n"
        for block in blocks(lines) {
            try Task.checkCancellation()
            let prompt =
                header
                + block.map {
                    $0.speaker.isEmpty ? $0.text : "[\(clock($0.atSec))] \($0.speaker): \($0.text)"
                }.joined(separator: "\n")
            let answer = try await engine.generate(LLMRequest(system: system, prompt: prompt, maxTokens: 1_400))
            for candidate in parse(answer) {
                var item = candidate.point
                guard let index = locateLine(item.quote, in: block) else {
                    discarded.append((item.text, "citazione non trovata nella trascrizione"))
                    continue
                }
                guard item.confidence > .low else {
                    discarded.append((item.text, "sicurezza bassa"))
                    continue
                }
                item.atSec = block[index].atSec
                let said = block[index..<min(block.count, index + 2)].map(\.text) + [item.quote]
                if let words = candidate.due, let date = context.date {
                    item.due = due(words, said: said, quote: item.quote, from: date, calendar: context.calendar)
                }
                if let number = candidate.closes {
                    item.closesID = closing(item, number: number, in: open)
                }
                if item.kind == .question || item.kind == .request,
                    open.contains(where: { $0.kind == item.kind && similarText($0.text, item.text) })
                {
                    discarded.append((item.text, "già aperta nel progetto"))
                    continue
                }
                if items.contains(where: {
                    similar($0, item) || ($0.atSec == item.atSec && similarText($0.text, item.text))
                }) {
                    discarded.append((item.text, "doppione"))
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

    /// The deadline: the model's words when the text really says them, counted from the item's date; if the model
    /// rewrote them (or did the arithmetic itself), the deadline read from the quote. nil when neither is clear.
    static func due(_ words: String, said: [String], quote: String, from date: Date, calendar: Calendar) -> String? {
        let filler: Set = ["entro", "il", "lo", "la", "l", "le", "per", "di", "del", "della", "a", "al", "alla", "e"]
        let evidence = Set(self.words(words)).subtracting(filler)
        let text = Set(said.flatMap(self.words))
        if !evidence.isEmpty, evidence.isSubset(of: text),
            let day = DueDates.resolve(words, from: date, calendar: calendar)
        {
            return day
        }
        return DueDates.resolve(quote, from: date, calendar: calendar)
    }

    /// The id of the open entry number `number` if this item can close it: a decision answers a point to clear up or
    /// accepts a request, an activity accepts a request; and they must talk about the same thing (a word in common).
    static func closing(_ item: ProposedKeyPoint, number: Int, in open: [OpenEntry]) -> String? {
        guard open.indices.contains(number - 1) else { return nil }
        let entry = open[number - 1]
        let allowed: Bool =
            switch (item.kind, entry.kind) {
            case (.decision, .question), (.decision, .request), (.activity, .request): true
            default: false
            }
        guard allowed else { return nil }
        let mine = Set(words(item.text + " " + item.quote).filter { $0.count >= 3 && !stopwords.contains($0) })
        let theirs = Set(words(entry.text).filter { $0.count >= 3 && !stopwords.contains($0) })
        return mine.isDisjoint(with: theirs) ? nil : entry.id
    }

    static let stopwords: Set = [
        "che", "chi", "cosa", "come", "quale", "quali", "quando", "dove", "perche", "per", "con", "una", "uno", "del",
        "della", "dei", "delle", "nel", "nella", "sul", "sulla", "non", "anche", "questo", "questa", "quello",
        "quella", "sono", "siamo", "fare", "facciamo", "usiamo", "allora", "bene",
    ]

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

    /// A point as the model wrote it, with what IAGO still has to check: the words of the deadline and the number of
    /// the open entry it closes.
    struct Candidate {
        var point: ProposedKeyPoint
        var due: String?
        var closes: Int?
    }

    /// The model's answer, forgiving what small models do: reasoning before the JSON, code fences, commas before a
    /// bracket, an answer cut when it ran out of room, keys with accents, numbers written as text, "null" in quotes.
    static func parse(_ answer: String) -> [Candidate] {
        let cleaned = TextTidier.clean(answer)
        guard
            let object = SummaryGenerator.jsonObject(cleaned)
                ?? SummaryGenerator.jsonObject(cleaned.replacing(/,\s*([\]}])/) { String($0.1) })
        else { return [] }
        func string(_ value: Any?) -> String? {
            guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
                !["null", "nessuno", "nessuna", "-", "n/a"].contains(text.lowercased())
            else { return nil }
            return text
        }
        func items(_ keys: [String], _ kind: ProposedKeyPoint.Kind) -> [Candidate] {
            keys.flatMap { object[$0] as? [[String: Any]] ?? [] }.compactMap { entry in
                guard let text = string(entry["testo"]), let quote = string(entry["citazione"]) else { return nil }
                let confidence: ProposedKeyPoint.Confidence =
                    switch string(entry["sicurezza"])?.lowercased() {
                    case "alta", "high": .high
                    case "media", "medium": .medium
                    default: .low
                    }
                var point = ProposedKeyPoint(
                    kind: kind, text: text, quote: quote, atSec: 0, owner: string(entry["chi"]),
                    confidence: confidence)
                point.waitingOn = string(entry["attende"])
                // "chi" and "attende" both the same person: we wait for them.
                if let waiting = point.waitingOn, let owner = point.owner, words(waiting) == words(owner) {
                    point.owner = nil
                }
                if kind == .risk {
                    point.severity =
                        switch string(entry["gravita"] ?? entry["gravità"])?.lowercased() {
                        case "alta", "alto", "high": "high"
                        case "bassa", "basso", "low": "low"
                        default: "medium"
                        }
                }
                let closes: Int? =
                    switch entry["chiude"] {
                    case let number as Int: number
                    case let text as String: Int(text.filter(\.isNumber))
                    default: nil
                    }
                return Candidate(point: point, due: string(entry["entro"]), closes: closes)
            }
        }
        return items(["decisioni"], .decision) + items(["attivita", "attività"], .activity)
            + items(["domande", "domande_aperte", "punti_da_chiarire"], .question) + items(["rischi"], .risk)
            + items(["richieste"], .request)
    }

    // MARK: Checks

    /// The second of the line holding the quote, or nil. Models copy quotes loosely, so case, accents, punctuation and
    /// small rewordings do not count: at least three quarters of the quote's meaningful words (4+ letters, at least
    /// 3 of them) must be in one line or in two consecutive lines. Numbers are strict: every number in the quote must
    /// be there, so an invented amount or percentage is always discarded.
    /// `span`: how many consecutive lines may hold the quote (2 for key points; summaries paraphrase more).
    public static func locate(_ quote: String, in block: [Line], span: Int = 2) -> Double? {
        locateLine(quote, in: block, span: span).map { block[$0].atSec }
    }

    /// The index of the line `locate` finds.
    static func locateLine(_ quote: String, in block: [Line], span: Int = 2) -> Int? {
        let wanted = words(quote)
        let meaningful = Set(wanted.filter { $0.count >= 4 && !$0.allSatisfy(\.isNumber) })
        let numbers = Set(wanted.filter { $0.contains(where: \.isNumber) })
        guard meaningful.count >= 3 || (meaningful.count >= 2 && !numbers.isEmpty) else { return nil }
        func coverage(_ words: Set<String>) -> Double {
            Double(meaningful.intersection(words).count) / Double(meaningful.count)
        }
        // The line that holds most of the quote by itself wins; the next line only completes it.
        var best: (own: Double, pair: Double, index: Int)?
        for (index, line) in block.enumerated() {
            let own = Set(words(line.text))
            let pair = block[index..<min(block.count, index + max(span, 1))].reduce(into: own) {
                $0.formUnion(words($1.text))
            }
            guard numbers.isSubset(of: pair) else { continue }
            let candidate = (own: coverage(own), pair: coverage(pair), index: index)
            guard candidate.pair >= 0.75, candidate.own > 0 else { continue }
            if best == nil || (candidate.own, candidate.pair) > (best!.own, best!.pair) { best = candidate }
        }
        return best?.index
    }

    static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    static func similar(_ a: ProposedKeyPoint, _ b: ProposedKeyPoint) -> Bool {
        a.kind == b.kind && similarText(a.text, b.text)
    }

    static func similarText(_ a: String, _ b: String) -> Bool {
        let left = Set(words(a).filter { $0.count > 3 })
        let right = Set(words(b).filter { $0.count > 3 })
        guard !left.isEmpty, !right.isEmpty else { return false }
        return Double(left.intersection(right).count) / Double(min(left.count, right.count)) >= 0.7
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
