import Foundation
import IAGOCore
import IAGOStore

/// «Sintesi di stato» (ADR-0074): a short status text of a project, client or stream, to paste in an email. The engine
/// writes it only from the key points (no transcript), each line citing the numbered facts it comes from; a line that
/// cites nothing, or a fact that does not exist, is dropped, like an unverified quote in the summaries (ADR-0054).
public enum StatusReport {
    /// One key point, numbered, as the engine reads it.
    public struct Fact: Sendable, Equatable {
        public var number: Int
        public var line: String
    }

    public struct Result: Sendable, Equatable {
        /// The text to copy, without the fact numbers.
        public var text: String
        /// The same text with the numbers, to check where each line comes from.
        public var cited: String
        /// Lines left out because they cite nothing that exists.
        public var dropped: [String]
    }

    /// Closed work and memory older than this stays out of the report.
    static let recentDays = 30
    static let maxFacts = 80

    /// The facts of a scope: open work, work closed recently, recent decisions and milestones, upcoming milestones.
    public static func facts(_ entries: [DecisionSummary], now: Date, calendar: Calendar = .current) -> [Fact] {
        let recent = calendar.date(byAdding: .day, value: -recentDays, to: now) ?? now
        let today = calendar.startOfDay(for: now)
        let chosen = entries.filter { summary in
            let decision = summary.decision
            if decision.kind.isWork {
                return decision.status.isOpen || (decision.closedAt ?? .distantPast) >= recent
            }
            guard decision.status == .active else { return false }
            return decision.decidedAt >= recent || decision.decidedAt >= today
        }
        // Open work first (overdue, then by due date), then what happened, most recent first.
        let open = chosen.filter { $0.decision.kind.isWork && $0.decision.status.isOpen }
            .sorted { ($0.decision.dueAt ?? .distantFuture) < ($1.decision.dueAt ?? .distantFuture) }
        let rest = chosen.filter { !($0.decision.kind.isWork && $0.decision.status.isOpen) }
            .sorted {
                ($0.decision.closedAt ?? $0.decision.decidedAt) > ($1.decision.closedAt ?? $1.decision.decidedAt)
            }
        return (open + rest).prefix(maxFacts).enumerated().map { index, summary in
            Fact(number: index + 1, line: line(summary, today: today, calendar: calendar))
        }
    }

    static func line(_ summary: DecisionSummary, today: Date, calendar: Calendar) -> String {
        let decision = summary.decision
        var parts = [kindName(decision.kind), stateName(decision)]
        if let severity = decision.severity { parts.append("gravità \(severityName(severity))") }
        if decision.happenedAt != nil { parts.append("diventato problema") }
        if let priority = decision.priority {
            parts.append("priorità \(["alta", "media", "bassa"][max(0, min(2, priority - 1))])")
        }
        if let owner = summary.ownerName { parts.append("responsabile \(owner)") }
        if let due = decision.dueAt {
            let late = decision.status.isOpen && due < today
            parts.append("scadenza \(day(due))" + (late ? " (in ritardo)" : ""))
        }
        if decision.status == .waiting {
            var waiting = "attende \(summary.waitingOnName ?? "altri")"
            if let until = decision.waitingUntil {
                waiting += " entro \(day(until))" + (until < today ? " (scaduta)" : "")
            }
            parts.append(waiting)
        }
        if !summary.blockers.isEmpty {
            parts.append("dipende da: " + summary.blockers.map(\.text).joined(separator: "; "))
        }
        if summary.checklist.total > 0 {
            parts.append("checklist \(summary.checklist.done)/\(summary.checklist.total)")
        }
        if decision.kind.isWork, let closed = decision.closedAt { parts.append("chiusa il \(day(closed))") }
        if !decision.kind.isWork { parts.append("del \(day(decision.decidedAt))") }
        var text = parts.joined(separator: " · ") + ": " + decision.text
        if let outcome = decision.outcome, !outcome.isEmpty { text += " → \(outcome)" }
        return text
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "it_IT")))
    }

    static func kindName(_ kind: Decision.Kind) -> String {
        switch kind {
        case .decision: "Decisione"
        case .milestone: "Tappa"
        case .action: "Attività"
        case .openQuestion: "Punto da chiarire"
        case .risk: "Rischio"
        case .request: "Richiesta"
        }
    }

    static func stateName(_ decision: Decision) -> String {
        switch decision.status {
        case .active: decision.kind.isWork ? "da fare" : "valida"
        case .inProgress: "in corso"
        case .waiting: "in attesa"
        case .blocked: "bloccata"
        case .done: "fatta"
        case .superseded: decision.kind.isWork ? "chiusa" : "superata"
        case .cancelled: "annullata"
        }
    }

    static func severityName(_ severity: Decision.Severity) -> String {
        switch severity {
        case .high: "alta"
        case .medium: "media"
        case .low: "bassa"
        }
    }

    public static func request(scopeName: String, facts: [Fact], today: Date) -> LLMRequest {
        let system = """
            Sei l'assistente di un project manager. Scrivi in italiano una sintesi di stato di «\(scopeName)» da \
            incollare in una mail, usando SOLO i fatti numerati che ricevi. Non inventare nulla: niente nomi, date o \
            numeri che non siano nei fatti.
            Struttura, con questi titoli su righe proprie:
            In breve
            Avanzamento
            Rischi e punti aperti
            Prossimi passi
            Sotto ogni titolo righe che iniziano con "- ", brevi e concrete. Ogni riga termina con i numeri dei fatti \
            da cui viene, tra parentesi quadre, per esempio [3] o [2, 5]. Ometti un titolo se non ha righe. Niente \
            altro testo prima o dopo.
            """
        let prompt =
            "Oggi è \(day(today)).\n\nFatti:\n" + facts.map { "[\($0.number)] \($0.line)" }.joined(separator: "\n")
        return LLMRequest(system: system, prompt: prompt, maxTokens: 1_200)
    }

    /// Keeps the lines that cite existing facts, and the headings that still have lines under them.
    public static func verify(_ answer: String, facts: [Fact]) -> Result {
        let known = Set(facts.map(\.number))
        let headings = ["In breve", "Avanzamento", "Rischi e punti aperti", "Prossimi passi"]
        var blocks: [(heading: String?, lines: [String])] = [(nil, [])]
        var dropped: [String] = []
        for raw in TextTidier.clean(answer).split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let bare = line.trimmingCharacters(in: CharacterSet(charactersIn: "#*: "))
            if let heading = headings.first(where: { $0.caseInsensitiveCompare(bare) == .orderedSame }) {
                blocks.append((heading, []))
                continue
            }
            let cited = citations(in: line)
            if cited.isEmpty || !cited.isSubset(of: known) {
                dropped.append(line)
                continue
            }
            let bullet = line.hasPrefix("- ") || line.hasPrefix("* ") ? "- " + line.dropFirst(2) : "- " + line
            blocks[blocks.count - 1].lines.append(bullet)
        }
        let kept = blocks.filter { !$0.lines.isEmpty }
        let cited = kept.map { block in
            ([block.heading].compactMap { $0 } + block.lines).joined(separator: "\n")
        }.joined(separator: "\n\n")
        return Result(text: withoutCitations(cited), cited: cited, dropped: dropped)
    }

    public static func generate(scopeName: String, facts: [Fact], now: Date, with engine: any LLMProvider)
        async throws -> Result
    {
        let answer = try await engine.generate(request(scopeName: scopeName, facts: facts, today: now))
        return verify(answer, facts: facts)
    }

    static func citations(in line: String) -> Set<Int> {
        var numbers: Set<Int> = []
        for match in line.matches(of: /\[(\d+(?:\s*,\s*\d+)*)\]/) {
            for piece in match.1.split(separator: ",") {
                if let number = Int(piece.trimmingCharacters(in: .whitespaces)) { numbers.insert(number) }
            }
        }
        return numbers
    }

    static func withoutCitations(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.replacing(/\s*\[(\d+(?:\s*,\s*\d+)*)\]/, with: "")
        }.joined(separator: "\n")
    }
}
