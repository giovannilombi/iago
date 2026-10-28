import Foundation
import IAGOStore

/// Italian names of key points and their states (ADR-0046, ADR-0074), shared by exports, the MCP server and the app.
public enum KeyPointLabels {
    public static func kind(_ kind: Decision.Kind) -> String {
        switch kind {
        case .decision: "Decisione"
        case .action: "Attività"
        case .milestone: "Tappa"
        case .openQuestion: "Punto da chiarire"
        case .risk: "Rischio"
        case .request: "Richiesta"
        }
    }

    /// The state as a word. Work in "Gestisci" shows every state, in "Traccia" only Aperta, In attesa and the closed
    /// ones (ADR-0074). A work entry closed with an outcome shows it ("Chiarito", "Rifiutata"); one closed by newer
    /// entries (`closedBy`) reads with the verb of the link ("risponde a" → Chiarito, "accoglie" → Accolta, "completa"
    /// → Fatta).
    public static func status(_ decision: Decision, mode: WorkMode = .manage, closedBy: [Decision] = []) -> String {
        guard decision.kind.isWork else {
            switch (decision.kind, decision.status) {
            case (_, .superseded): return "Superata"
            case (_, .cancelled): return "Annullata"
            case (.milestone, _): return "Raggiunta"
            case (_, .done): return "Fatta"
            default: return "Attiva"
            }
        }
        // "Punto da chiarire" and "Rischio" are masculine.
        let male = decision.kind == .openQuestion || decision.kind == .risk
        func word(_ feminine: String) -> String { male ? String(feminine.dropLast()) + "o" : feminine }
        if !decision.status.isOpen, let outcome = decision.outcomeKind { return Self.outcome(outcome) }
        switch decision.status {
        case .active: return decision.kind == .action && mode == .manage ? "Da fare" : word("Aperta")
        case .inProgress: return mode == .manage ? "In corso" : word("Aperta")
        case .waiting: return "In attesa"
        case .blocked: return mode == .manage ? word("Bloccata") : word("Aperta")
        case .done:
            switch decision.kind {
            // As the app reads a work entry done without an outcome.
            case .openQuestion: return "Chiarito"
            case .action: return "Fatta"
            case .risk: return "Risolto"
            case .request: return "Accolta"
            default: return word("Chiusa")
            }
        case .cancelled: return word("Annullata")
        case .superseded:
            guard !closedBy.isEmpty else { return word("Superata") }
            let closers = Set(closedBy.map(\.kind))
            switch decision.kind {
            case .openQuestion where closers.contains(.decision): return "Chiarito"
            case .request where closers.contains(.decision) || closers.contains(.action): return "Accolta"
            case .action where closers.contains(.decision) || closers.contains(.milestone): return "Fatta"
            default: return word("Chiusa")
            }
        }
    }

    public static func outcome(_ outcome: Decision.Outcome) -> String {
        switch outcome {
        case .answered: "Chiarito"
        case .accepted: "Accolta"
        case .rejected: "Rifiutata"
        case .converted: "Trasformata"
        case .resolved: "Risolto"
        case .irrelevant: "Non più rilevante"
        }
    }

    public static func severity(_ severity: Decision.Severity) -> String {
        switch severity {
        case .high: "alta"
        case .medium: "media"
        case .low: "bassa"
        }
    }

    /// 1 alta, 2 media, 3 bassa.
    public static func priority(_ priority: Int) -> String {
        switch priority {
        case ...1: "alta"
        case 2: "media"
        default: "bassa"
        }
    }

    public static func recurrence(_ recurrence: Decision.Recurrence) -> String {
        switch recurrence {
        case .daily: "ogni giorno"
        case .weekly: "ogni settimana"
        case .monthly: "ogni mese"
        case .yearly: "ogni anno"
        }
    }

    /// "Attiva" for decisions (as always), "Attività · Da fare", "Rischio · alta · Aperto", "Tappa".
    public static func tag(_ decision: Decision, mode: WorkMode = .manage, closedBy: [Decision] = []) -> String {
        let status = status(decision, mode: mode, closedBy: closedBy)
        switch decision.kind {
        case .decision: return status
        case .milestone: return decision.status == .active ? "Tappa" : "Tappa · \(status)"
        default:
            let severity = decision.kind == .risk ? decision.severity.map { " · \(Self.severity($0))" } ?? "" : ""
            return "\(kind(decision.kind))\(severity) · \(status)"
        }
    }

    /// The details of open work, in the order they are read: "responsabile: Marco", "scadenza: 2026-11-10",
    /// "in attesa di: Anna entro 2026-11-05"… Dates as `yyyy-MM-dd`.
    public static func workDetails(_ summary: DecisionSummary, timeZone: TimeZone = .current) -> [String] {
        let decision = summary.decision
        func day(_ date: Date) -> String { TranscriptRenderer.format(date, "yyyy-MM-dd", timeZone) }
        var details: [String] = []
        if let owner = summary.ownerName { details.append("responsabile: \(owner)") }
        if let due = decision.dueAt { details.append("scadenza: \(day(due))") }
        switch (summary.waitingOnName, decision.waitingUntil) {
        case (let who?, let until?): details.append("in attesa di: \(who) entro \(day(until))")
        case (let who?, nil): details.append("in attesa di: \(who)")
        case (nil, let until?): details.append("in attesa fino al \(day(until))")
        case (nil, nil): break
        }
        if let priority = decision.priority { details.append("priorità: \(Self.priority(priority))") }
        if let starts = decision.startsAt { details.append("inizio: \(day(starts))") }
        if let estimate = decision.estimate, !estimate.isEmpty { details.append("stima: \(estimate)") }
        if let happened = decision.happenedAt { details.append("diventato problema il \(day(happened))") }
        if let recurrence = decision.recurrence { details.append("ricorrenza: \(Self.recurrence(recurrence))") }
        if !summary.blockers.isEmpty {
            details.append("dipende da: " + summary.blockers.map { "«\($0.text)»" }.joined(separator: ", "))
        }
        if let origin = summary.derivedFrom { details.append("nata da: «\(origin.text)»") }
        return details
    }

    /// "☑ Inviare i file" / "☐ Firmare l'ordine".
    public static func checklistLine(_ item: ChecklistItem) -> String { (item.done ? "☑ " : "☐ ") + item.text }
}
