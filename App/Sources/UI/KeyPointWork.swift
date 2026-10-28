import IAGOExport
import IAGOStore
import SwiftUI

// MARK: - Kinds, states and links (ADR-0046, ADR-0052, ADR-0074)

/// Names, signs and colours of the six kinds, how each state reads in the two modes, and the verb of a
/// "supera / chiude" link: one place for the rows, the timeline, the detail pane and the other views.
extension DecisionRow {
    /// The order of the kind pickers and menus: memory first, then work.
    static let allKinds: [Decision.Kind] = [.decision, .milestone, .action, .openQuestion, .risk, .request]

    static func kindLabel(_ kind: Decision.Kind) -> String {
        switch kind {
        case .decision: String(localized: "Decisione")
        case .milestone: String(localized: "Tappa")
        case .action: String(localized: "Attività")
        case .openQuestion: String(localized: "Punto da chiarire")
        case .risk: String(localized: "Rischio")
        case .request: String(localized: "Richiesta")
        }
    }

    static func kindPlural(_ kind: Decision.Kind) -> String {
        switch kind {
        case .decision: String(localized: "Decisioni")
        case .milestone: String(localized: "Tappe")
        case .action: String(localized: "Attività")
        case .openQuestion: String(localized: "Punti da chiarire")
        case .risk: String(localized: "Rischi")
        case .request: String(localized: "Richieste")
        }
    }

    static func kindIcon(_ kind: Decision.Kind) -> String {
        switch kind {
        case .decision: "checkmark.seal.fill"
        case .milestone: "flag.fill"
        case .action: "circle.dashed"
        case .openQuestion: "questionmark.circle.fill"
        case .risk: "exclamationmark.triangle.fill"
        case .request: "envelope.fill"
        }
    }

    /// The kind's own colour, for labels, cards and new-item menus.
    static func tint(_ kind: Decision.Kind) -> Color {
        switch kind {
        case .decision: .green
        case .milestone: .blue
        case .action: .orange
        case .openQuestion: .purple
        case .risk: .red
        case .request: .cyan
        }
    }

    /// How an entry looks now: open (also under way), waiting, blocked, done (a positive end, not struck), closed
    /// with another outcome (rejected, turned into something else, no longer relevant), struck (superseded or
    /// cancelled).
    enum Look { case open, waiting, blocked, done, outcome, struck }

    static func look(_ decision: Decision, closedBy: Decision.Kind? = nil) -> Look {
        switch decision.status {
        case .active, .inProgress: .open
        case .waiting: .waiting
        case .blocked: .blocked
        case .done:
            [Decision.Outcome.rejected, .converted, .irrelevant].contains { $0 == decision.outcomeKind }
                ? .outcome : .done
        case .superseded: closedBy.map { link(newer: $0, older: decision.kind).isPositive } == true ? .done : .struck
        case .cancelled: .struck
        }
    }

    /// Still something to read as current: open, waiting or blocked.
    static func isCurrent(_ decision: Decision) -> Bool { decision.status.isOpen }

    // MARK: Links

    /// The "supera / chiude" link read with the verb of the two kinds (design, «Come si collegano»).
    enum Link {
        case replaces, answers, accepts, completes, supersedes

        /// The older entry ends well: cleared up, accepted, done.
        var isPositive: Bool { self == .answers || self == .accepts || self == .completes }
    }

    static func link(newer: Decision.Kind, older: Decision.Kind) -> Link {
        switch (newer, older) {
        case (.decision, .decision), (.milestone, .milestone): .replaces
        case (.decision, .openQuestion): .answers
        case (.decision, .request), (.action, .request): .accepts
        case (.milestone, .action), (.decision, .action): .completes
        default: .supersedes
        }
    }

    /// The newer side: "sostituisce", "risponde a", "accoglie", "completa", "supera".
    static func verb(newer: Decision.Kind, older: Decision.Kind) -> String {
        switch link(newer: newer, older: older) {
        case .replaces: String(localized: "sostituisce")
        case .answers: String(localized: "risponde a")
        case .accepts: String(localized: "accoglie")
        case .completes: String(localized: "completa")
        case .supersedes: String(localized: "supera")
        }
    }

    /// The older side, once closed: "Superata", "Chiarito", "Accolta", "Fatta", "Chiusa".
    static func closedLabel(older: Decision.Kind, by newer: Decision.Kind?) -> String {
        guard let newer else { return older.isWork ? String(localized: "Chiusa") : String(localized: "Superata") }
        switch link(newer: newer, older: older) {
        case .replaces: return String(localized: "Superata")
        case .answers: return String(localized: "Chiarito")
        case .accepts: return String(localized: "Accolta")
        case .completes: return String(localized: "Fatta")
        case .supersedes: return older.isWork ? String(localized: "Chiusa") : String(localized: "Superata")
        }
    }

    /// The older side with who closed it: "Superata da", "Chiarito da", "Accolta da", "Completata da", "Chiusa da".
    static func closedByLabel(older: Decision.Kind, by newer: Decision.Kind) -> String {
        switch link(newer: newer, older: older) {
        case .replaces: String(localized: "Superata da")
        case .answers: String(localized: "Chiarito da")
        case .accepts: String(localized: "Accolta da")
        case .completes: String(localized: "Completata da")
        case .supersedes: older.isWork ? String(localized: "Chiusa da") : String(localized: "Superata da")
        }
    }

    // MARK: States

    /// The state as the mode shows it. In "Traccia" under way and blocked read "Aperta" (blocked keeps its sign).
    static func label(_ decision: Decision, closedBy: Decision.Kind? = nil, mode: WorkMode = .manage) -> String {
        guard decision.kind.isWork else {
            if decision.status == .superseded { return closedLabel(older: decision.kind, by: closedBy) }
            return KeyPointLabels.status(decision)
        }
        switch decision.status {
        case .active: return mode == .track ? String(localized: "Aperta") : String(localized: "Da fare")
        case .inProgress: return mode == .track ? String(localized: "Aperta") : String(localized: "In corso")
        case .waiting: return String(localized: "In attesa")
        case .blocked: return mode == .track ? String(localized: "Aperta") : String(localized: "Bloccata")
        case .done: return outcomeLabel(decision)
        case .superseded: return closedLabel(older: decision.kind, by: closedBy)
        case .cancelled: return String(localized: "Annullata")
        }
    }

    static func label(_ summary: DecisionSummary, mode: WorkMode = .manage) -> String {
        label(summary.decision, closedBy: summary.supersededBy?.kind, mode: mode)
    }

    /// A closed work entry: "Chiarito", "Accolta", "Rifiutata", "Trasformata", "Risolto", "Non più rilevante",
    /// "Fatta".
    static func outcomeLabel(_ decision: Decision) -> String {
        switch decision.outcomeKind {
        case .answered: String(localized: "Chiarito")
        case .accepted: String(localized: "Accolta")
        case .rejected: String(localized: "Rifiutata")
        case .converted: String(localized: "Trasformata")
        case .resolved: String(localized: "Risolto")
        case .irrelevant: String(localized: "Non più rilevante")
        case nil:
            switch decision.kind {
            case .openQuestion: String(localized: "Chiarito")
            case .request: String(localized: "Accolta")
            case .risk: String(localized: "Risolto")
            default: String(localized: "Fatta")
            }
        }
    }

    /// One state in pickers and filters.
    static func statusName(_ status: Decision.Status, mode: WorkMode) -> String {
        switch status {
        case .active: mode == .track ? String(localized: "Aperta") : String(localized: "Da fare")
        case .inProgress: String(localized: "In corso")
        case .waiting: String(localized: "In attesa")
        case .blocked: String(localized: "Bloccata")
        case .done: String(localized: "Fatta")
        case .superseded: String(localized: "Superata")
        case .cancelled: String(localized: "Annullata")
        }
    }

    /// The states the user picks for work, per mode (design, «Stati»).
    static func workStatuses(_ mode: WorkMode) -> [Decision.Status] {
        mode == .track
            ? [.active, .waiting, .done, .cancelled] : [.active, .inProgress, .waiting, .blocked, .done, .cancelled]
    }

    /// In "Traccia": under way and blocked are "Aperta".
    static func trackStatus(_ status: Decision.Status) -> Decision.Status {
        status == .inProgress || status == .blocked ? .active : status
    }

    static func icon(_ decision: Decision, closedBy: Decision.Kind? = nil) -> String {
        switch look(decision, closedBy: closedBy) {
        case .done: return decision.kind.isWork ? "checkmark.circle.fill" : kindIcon(decision.kind)
        case .outcome:
            switch decision.outcomeKind {
            case .converted: return "arrow.uturn.right.circle"
            case .irrelevant: return "minus.circle"
            default: return "xmark.circle"
            }
        case .struck:
            if decision.status == .superseded { return "arrow.triangle.2.circlepath" }
            switch decision.kind {
            case .decision: return "xmark.seal"
            case .milestone: return "flag.slash"
            default: return "xmark.circle"
            }
        case .open, .waiting, .blocked: return kindIcon(decision.kind)
        }
    }

    static func icon(_ summary: DecisionSummary) -> String {
        icon(summary.decision, closedBy: summary.supersededBy?.kind)
    }

    static func color(_ decision: Decision, closedBy: Decision.Kind? = nil) -> Color {
        switch look(decision, closedBy: closedBy) {
        case .done: decision.kind.isWork ? .green : .secondary
        case .outcome: .secondary
        case .struck: decision.status == .cancelled ? .red : .secondary
        case .open, .waiting, .blocked: tint(decision.kind)
        }
    }

    static func color(_ summary: DecisionSummary) -> Color {
        color(summary.decision, closedBy: summary.supersededBy?.kind)
    }

    /// Open work past its due date (by day).
    static func isOverdue(_ decision: Decision, now: Date = Date()) -> Bool {
        guard decision.kind.isWork, decision.status.isOpen, let due = decision.dueAt else { return false }
        return Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: now)
    }

    /// Fields only "Gestisci" shows, filled in: "Traccia" keeps them and says so with a small sign.
    static func hasManageDetails(_ summary: DecisionSummary) -> Bool {
        let decision = summary.decision
        return decision.priority != nil || !summary.blockers.isEmpty || !(decision.estimate ?? "").isEmpty
            || decision.startsAt != nil || decision.recurrence != nil || decision.status == .inProgress
    }

    static func priorityLabel(_ priority: Int) -> String {
        switch priority {
        case 1: String(localized: "Alta")
        case 2: String(localized: "Media")
        default: String(localized: "Bassa")
        }
    }

    static func severityLabel(_ severity: Decision.Severity) -> String {
        switch severity {
        case .high: String(localized: "Alta")
        case .medium: String(localized: "Media")
        case .low: String(localized: "Bassa")
        }
    }

    static func recurrenceLabel(_ recurrence: Decision.Recurrence) -> String {
        switch recurrence {
        case .daily: String(localized: "Ogni giorno")
        case .weekly: String(localized: "Ogni settimana")
        case .monthly: String(localized: "Ogni mese")
        case .yearly: String(localized: "Ogni anno")
        }
    }

    static func shortDate(_ date: Date) -> String {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
            ? date.formatted(.dateTime.day().month(.abbreviated))
            : date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

// MARK: - The work line of a row

/// Owner, due date, "attende Anna · entro 5 nov", «bloccata», severity, checklist, outcome, "nata da": small, after
/// the title, wherever an entry is listed (design, «Timeline»).
struct KeyPointWorkLine: View {
    let model: AppModel
    let summary: DecisionSummary
    /// The outcome line ("→ Usiamo Azure AD"); off where the status line already says it.
    var showsOutcome = true

    var body: some View {
        let decision = summary.decision
        let mode = model.workMode(for: decision.projectId)
        let parts = pieces(mode: mode)
        if !parts.isEmpty || outcome != nil {
            FlowLayout(spacing: 8, lineSpacing: 4) {
                ForEach(parts.indices, id: \.self) { index in
                    let part = parts[index]
                    Group {
                        if part.text.isEmpty {
                            Image(systemName: part.icon)
                        } else {
                            Label(part.text, systemImage: part.icon).labelStyle(.titleAndIcon).lineLimit(1)
                        }
                    }
                    .foregroundStyle(part.color)
                    .help(part.help ?? "")
                }
                if showsOutcome, let outcome {
                    Text(outcome).foregroundStyle(.secondary).italic().lineLimit(2)
                }
            }
            .font(.caption)
        }
    }

    private struct Piece {
        var text: String
        var icon: String
        var color: Color = .secondary
        var help: String?
    }

    private func pieces(mode: WorkMode) -> [Piece] {
        let decision = summary.decision
        var parts: [Piece] = []
        guard decision.kind.isWork else { return parts }
        if let owner = summary.ownerName {
            parts.append(Piece(text: owner, icon: "person", help: String(localized: "Responsabile")))
        }
        if decision.status.isOpen, let due = decision.dueAt {
            let late = DecisionRow.isOverdue(decision)
            parts.append(
                Piece(
                    text: String(localized: "entro \(DecisionRow.shortDate(due))"), icon: "calendar",
                    color: late ? .red : .secondary,
                    help: late ? String(localized: "Scadenza passata") : String(localized: "Scadenza")))
        }
        if decision.status == .waiting || summary.waitingOnName != nil, decision.status.isOpen {
            var text =
                summary.waitingOnName.map { String(localized: "attende \($0)") } ?? String(localized: "in attesa")
            if let until = decision.waitingUntil {
                text += " · " + String(localized: "entro \(DecisionRow.shortDate(until))")
            }
            let late = decision.waitingUntil.map {
                Calendar.current.startOfDay(for: $0) < Calendar.current.startOfDay(for: Date())
            }
            parts.append(Piece(text: text, icon: "hourglass", color: late == true ? .red : .orange))
        }
        if decision.status == .blocked {
            parts.append(
                Piece(
                    text: String(localized: "bloccata"), icon: "nosign", color: .red,
                    help: summary.blockers.isEmpty
                        ? nil
                        : String(
                            localized: "Dipende da: \(summary.blockers.map(\.text).joined(separator: ", "))")))
        }
        if decision.kind == .risk, let severity = decision.severity {
            parts.append(
                Piece(
                    text: String(localized: "gravità \(DecisionRow.severityLabel(severity).lowercased())"),
                    icon: "gauge.with.dots.needle.67percent", color: severity == .high ? .red : .secondary))
        }
        if let happened = decision.happenedAt {
            parts.append(
                Piece(
                    text: String(localized: "diventato problema · \(DecisionRow.shortDate(happened))"),
                    icon: "exclamationmark.octagon", color: .red))
        }
        if mode == .manage, let priority = decision.priority {
            parts.append(
                Piece(
                    text: String(localized: "priorità \(DecisionRow.priorityLabel(priority).lowercased())"),
                    icon: "arrow.up.arrow.down", color: priority == 1 ? .orange : .secondary))
        }
        if summary.checklist.total > 0 {
            parts.append(
                Piece(
                    text: "\(summary.checklist.done)/\(summary.checklist.total)", icon: "checklist",
                    color: summary.checklist.done == summary.checklist.total ? .green : .secondary,
                    help: String(localized: "Checklist")))
        }
        if let origin = summary.derivedFrom {
            parts.append(
                Piece(
                    text: String(localized: "nata da «\(DecisionRow.clip(origin.text, 40))»"),
                    icon: "arrow.turn.down.right"))
        }
        if mode == .track, DecisionRow.hasManageDetails(summary) {
            parts.append(
                Piece(
                    text: "", icon: "slider.horizontal.3",
                    help: String(localized: "Ha dettagli in Gestisci: priorità, dipendenze, stima, inizio o ricorrenza")
                ))
        }
        return parts
    }

    /// "→ Usiamo Azure AD", "→ fuori budget", "→ 1 attività": how a closed entry ended.
    private var outcome: String? {
        let decision = summary.decision
        if decision.status == .superseded, let newer = summary.supersededBy,
            DecisionRow.link(newer: newer.kind, older: decision.kind).isPositive
        {
            return "→ \(DecisionRow.clip(newer.text, 80))"
        }
        guard !decision.status.isOpen, let text = decision.outcome, !text.isEmpty else { return nil }
        return "→ \(DecisionRow.clip(text, 80))"
    }
}

extension String {
    /// "risponde a" → "Risponde a".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

extension DecisionRow {
    static func clip(_ text: String, _ limit: Int) -> String {
        let text = text.replacingOccurrences(of: "\n", with: " ")
        return text.count > limit ? "\(text.prefix(limit))…" : text
    }
}

// MARK: - Actions by kind and state

/// What can be done with an entry (design, «Chiusure con esito»), as menu items: for context menus and the
/// "Azioni" menu of the detail pane.
struct KeyPointActions: View {
    let model: AppModel
    let summary: DecisionSummary

    var body: some View {
        let decision = summary.decision
        if decision.kind.isWork {
            if decision.status.isOpen {
                switch decision.kind {
                case .action:
                    Button(String(localized: "Segna come fatta")) { model.setDecisionStatus(decision.id, .done) }
                    Button(String(localized: "Diventa decisione…")) {
                        model.editingDecision = .superseding(summary, kind: .decision)
                    }
                case .openQuestion:
                    Button(String(localized: "Chiarisci…")) { model.closingKeyPoint = .clarify(summary) }
                case .request:
                    Button(String(localized: "Accogli…")) { model.closingKeyPoint = .accept(summary) }
                    Button(String(localized: "Rifiuta…")) { model.closingKeyPoint = .reject(summary) }
                    Menu(String(localized: "Trasforma in")) {
                        ForEach(DecisionRow.allKinds.filter { $0 != .request }, id: \.self) { kind in
                            Button(DecisionRow.kindLabel(kind)) {
                                model.editingDecision = .converting(summary, to: kind)
                            }
                        }
                    }
                case .risk:
                    if decision.happenedAt == nil {
                        Button(String(localized: "Diventato problema")) { model.riskHappened(decision.id) }
                    }
                    Button(String(localized: "Risolto")) { model.closeKeyPoint(decision.id, .resolved) }
                    Button(String(localized: "Non più rilevante")) { model.closeKeyPoint(decision.id, .irrelevant) }
                default:
                    EmptyView()
                }
                Button(String(localized: "Supera con una nuova voce…")) {
                    model.editingDecision = .superseding(summary, kind: .decision)
                }
                Button(String(localized: "Annulla")) { model.setDecisionStatus(decision.id, .cancelled) }
            } else if decision.status == .done || decision.status == .cancelled {
                Button(String(localized: "Riapri")) { model.reopenKeyPoint(decision.id) }
            }
        } else if decision.status == .active {
            Button(String(localized: "Supera con una nuova decisione…")) {
                model.editingDecision = .superseding(summary)
            }
            Button(String(localized: "Annulla")) { model.setDecisionStatus(decision.id, .cancelled) }
        } else if decision.status == .cancelled {
            Button(String(localized: "Riattiva")) { model.setDecisionStatus(decision.id, .active) }
        }
        Button(String(localized: "Nuova attività da questo")) { model.editingDecision = .derived(from: summary) }
    }
}

/// The one action an entry asks for, as a button: "Segna come fatta", "Chiarisci…", "Accogli…", "Risolto",
/// "Riapri".
struct KeyPointPrimaryAction: View {
    let model: AppModel
    let summary: DecisionSummary

    var body: some View {
        let decision = summary.decision
        if decision.kind.isWork {
            if decision.status.isOpen {
                switch decision.kind {
                case .action:
                    Button(String(localized: "Segna come fatta")) { model.setDecisionStatus(decision.id, .done) }
                case .openQuestion:
                    Button(String(localized: "Chiarisci…")) { model.closingKeyPoint = .clarify(summary) }
                case .request:
                    Button(String(localized: "Accogli…")) { model.closingKeyPoint = .accept(summary) }
                case .risk:
                    Button(String(localized: "Risolto")) { model.closeKeyPoint(decision.id, .resolved) }
                default:
                    EmptyView()
                }
            } else if decision.status == .done || decision.status == .cancelled {
                Button(String(localized: "Riapri")) { model.reopenKeyPoint(decision.id) }
            }
        }
    }
}

// MARK: - Closing with an outcome

/// A closing that needs a few words: the answer to a point, the activities of an accepted request, the reason of a
/// rejection.
enum KeyPointClosing: Identifiable {
    case clarify(DecisionSummary)
    case accept(DecisionSummary)
    case reject(DecisionSummary)

    var id: String {
        switch self {
        case .clarify(let summary): "clarify/\(summary.id)"
        case .accept(let summary): "accept/\(summary.id)"
        case .reject(let summary): "reject/\(summary.id)"
        }
    }

    var summary: DecisionSummary {
        switch self {
        case .clarify(let summary), .accept(let summary), .reject(let summary): summary
        }
    }
}

struct KeyPointClosingSheet: View {
    let model: AppModel
    let closing: KeyPointClosing
    @State private var text = ""
    @State private var becomesDecision = false
    @State private var activities: [String] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let summary = closing.summary
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: DecisionRow.kindIcon(summary.decision.kind))
                .font(.title2).bold().foregroundStyle(DecisionRow.tint(summary.decision.kind))
            Text(summary.decision.text).font(.headline).fixedSize(horizontal: false, vertical: true)
            switch closing {
            case .clarify:
                Text(String(localized: "La risposta")).font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.body).frame(height: 90).padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                Toggle(String(localized: "Diventa decisione"), isOn: $becomesDecision)
                Text(
                    String(
                        localized:
                            "La risposta diventa una decisione che «risponde a» questo punto, nella timeline del progetto."
                    )
                )
                .font(.caption).foregroundStyle(.secondary)
            case .accept:
                Text(
                    String(
                        localized:
                            "Le attività che nascono dalla richiesta: ognuna la ricorda («nata da»). Puoi anche accoglierla senza attività."
                    )
                )
                .font(.caption).foregroundStyle(.secondary)
                ForEach(activities.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        Image(systemName: DecisionRow.kindIcon(.action)).foregroundStyle(.orange)
                        TextField(String(localized: "Cosa c'è da fare"), text: $activities[index])
                            .textFieldStyle(.roundedBorder)
                        Button {
                            activities.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    activities.append("")
                } label: {
                    Label(String(localized: "Aggiungi un'attività"), systemImage: "plus")
                }
                .buttonStyle(.link)
            case .reject:
                Text(String(localized: "Il motivo (facoltativo)")).font(.caption).foregroundStyle(.secondary)
                TextField(String(localized: "Es. fuori budget"), text: $text).textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(confirmTitle) { confirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isClarify && trimmed(text).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            if case .accept(let summary) = closing { activities = [summary.decision.text] }
        }
    }

    private var isClarify: Bool {
        if case .clarify = closing { return true }
        return false
    }

    private var title: String {
        switch closing {
        case .clarify: String(localized: "Chiarisci")
        case .accept: String(localized: "Accogli la richiesta")
        case .reject: String(localized: "Rifiuta la richiesta")
        }
    }

    private var confirmTitle: String {
        switch closing {
        case .clarify: String(localized: "Chiarito")
        case .accept: String(localized: "Accogli")
        case .reject: String(localized: "Rifiuta")
        }
    }

    private func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func confirm() {
        switch closing {
        case .clarify(let summary):
            model.clarify(summary, answer: trimmed(text), becomesDecision: becomesDecision)
        case .accept(let summary):
            model.accept(summary, activities: activities.map(trimmed).filter { !$0.isEmpty })
        case .reject(let summary):
            model.closeKeyPoint(summary.id, .rejected, text: trimmed(text))
        }
        dismiss()
    }
}

// MARK: - Editor fields

/// One line of an activity's checklist while editing: saved with the entry.
struct ChecklistLine: Identifiable, Hashable {
    let id = UUID()
    /// The saved line, nil for a new one.
    var itemID: String?
    var text: String
    var done = false
}

/// One person, known or new (ADR-0074): «Io» first, then the people IAGO knows. A new name that looks like a
/// known one asks «Intendi Marco Rossi?» before it is created; it is created when the entry is saved.
struct PersonField: View {
    let model: AppModel
    @Binding var name: String?
    var placeholder = String(localized: "Nome")
    @State private var input = ""
    /// A typed name waiting for confirmation, with the known people it resembles.
    @State private var pending: (value: String, similar: [String])?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name {
                HStack(spacing: 3) {
                    Image(systemName: "person.fill").font(.caption)
                    Text(name == model.meName ? String(localized: "\(name) (io)") : name)
                    Button {
                        self.name = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            } else {
                TextField(placeholder, text: $input)
                    .textFieldStyle(.roundedBorder).frame(width: 200)
                    .onSubmit { submit(input) }
                if let pending {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(pending.similar, id: \.self) { other in
                            Button(String(localized: "Intendi \(other)?")) { choose(other) }
                                .buttonStyle(.link).font(.caption)
                        }
                        Button(String(localized: "No, «\(pending.value)» è una persona nuova")) {
                            choose(pending.value)
                        }
                        .buttonStyle(.link).font(.caption)
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.08)))
                } else {
                    HStack(spacing: 6) {
                        ForEach(matches, id: \.self) { other in
                            Button(other == model.meName ? String(localized: "Io") : other) { choose(other) }
                                .buttonStyle(.link).font(.caption)
                        }
                    }
                }
            }
        }
    }

    /// «Io» first, then the people whose name contains what is typed.
    private var matches: [String] {
        let me = model.meName
        let query = TagNormalizer.normalize(input)
        let others = model.people.map(\.name).filter { TagNormalizer.normalize($0) != TagNormalizer.normalize(me) }
        guard !query.isEmpty else { return [me] }
        let found = others.filter { TagNormalizer.normalize($0).contains(query) }
        let meToo = TagNormalizer.normalize(me).contains(query) ? [me] : []
        return Array((meToo + found).prefix(6))
    }

    private func submit(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = TagNormalizer.normalize(trimmed)
        if normalized == TagNormalizer.normalize(String(localized: "Io")) {
            choose(model.meName)
            return
        }
        let known = model.people.map(\.name) + [model.meName]
        if let existing = known.first(where: { TagNormalizer.normalize($0) == normalized }) {
            choose(existing)
            return
        }
        let similar = ((try? model.archive.similarPeople(to: trimmed)) ?? []).map(\.name)
        if similar.isEmpty {
            choose(trimmed)
        } else {
            pending = (trimmed, Array(similar.prefix(4)))
        }
    }

    private func choose(_ value: String) {
        name = value
        input = ""
        pending = nil
    }
}

/// An optional date: "Aggiungi" until it is set, then the picker and a button to clear it.
struct OptionalDateField: View {
    @Binding var date: Date?
    var addLabel = String(localized: "Aggiungi")
    var late = false

    var body: some View {
        if let current = date {
            HStack(spacing: 4) {
                DatePicker(
                    "", selection: Binding(get: { current }, set: { date = $0 }), displayedComponents: .date
                )
                .labelsHidden().fixedSize()
                if late { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red) }
                Button {
                    date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Togli la data"))
            }
        } else {
            Button(addLabel) {
                // Midday: the day stays the same whatever the time zone.
                date = Calendar.current.date(byAdding: .hour, value: 12, to: Calendar.current.startOfDay(for: Date()))
            }
            .buttonStyle(.link)
        }
    }
}

/// The lines of an activity: add, tick, reorder, delete. Saved with the entry.
struct ChecklistEditor: View {
    @Binding var lines: [ChecklistLine]
    @State private var newLine = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach($lines) { $line in
                HStack(spacing: 6) {
                    Toggle("", isOn: $line.done).labelsHidden().toggleStyle(.checkbox)
                    TextField("", text: $line.text).textFieldStyle(.plain)
                        .foregroundStyle(line.done ? .secondary : .primary)
                    Button {
                        move(line.id, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .disabled(lines.first?.id == line.id)
                    Button {
                        move(line.id, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .disabled(lines.last?.id == line.id)
                    Button {
                        lines.removeAll { $0.id == line.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help(String(localized: "Togli la voce"))
                }
                .font(.callout)
            }
            HStack(spacing: 6) {
                Image(systemName: "plus").foregroundStyle(.secondary).font(.caption)
                TextField(String(localized: "Aggiungi una voce"), text: $newLine)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                    .onSubmit {
                        let text = newLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        lines.append(ChecklistLine(text: text))
                        newLine = ""
                    }
            }
        }
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = lines.firstIndex(where: { $0.id == id }), lines.indices.contains(index + offset) else {
            return
        }
        lines.swapAt(index, index + offset)
    }
}

/// The checklist of an entry in the detail pane: lines ticked right there.
struct ChecklistSection: View {
    let model: AppModel
    let decisionID: String
    @State private var items: [ChecklistItem] = []

    var body: some View {
        Group {
            if !items.isEmpty {
                SectionBox(
                    String(localized: "Checklist · \(items.filter(\.done).count)/\(items.count)"),
                    systemImage: "checklist", tint: .orange
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items) { item in
                            Toggle(
                                isOn: Binding(
                                    get: { item.done },
                                    set: { done in
                                        model.perform {
                                            try model.archive.updateChecklistItem(item.id) { $0.done = done }
                                        }
                                    })
                            ) {
                                Text(item.text).foregroundStyle(item.done ? .secondary : .primary)
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
            }
        }
        .task(id: "\(model.revision)-\(decisionID)") {
            items = (try? model.archive.checklistItems(decisionID: decisionID)) ?? []
        }
    }
}
