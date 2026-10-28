import IAGOEngine
import IAGOStore
import SwiftUI

/// Confirming and dismissing the engine's proposals (ADR-0049, FR-111): only a confirmed proposal changes the archive,
/// and it becomes an ordinary key point (decision, activity, point to clear up, risk, request: ADR-0074), speaker
/// name, tag, project or link.
extension AppModel {
    func accept(_ suggestion: Suggestion) {
        guard let item = item(suggestion.itemId) else { return }
        let content = suggestion.content
        perform {
            switch suggestion.kind {
            case .decision, .activity, .question, .risk, .request:
                let kind = suggestion.kind.keyPointKind ?? .decision
                var decision = Decision(
                    text: content.text,
                    decidedAt: item.occurredAt.addingTimeInterval(content.atSec ?? 0), projectId: item.projectId,
                    sourceItemId: item.id, sourceAtSec: content.atSec, supersedesId: content.supersedesID,
                    origin: .extraction, kind: kind)
                decision.model = Provenance.decisionModel(of: suggestion)
                // On calls the user's own voice is "Io": that owner is the user, by the name IAGO knows them by.
                let owner = content.owner.flatMap { name in
                    name.caseInsensitiveCompare("Io") == .orderedSame || name == meName
                        ? meName : DecisionDraft.isPersonName(name) ? name : nil
                }
                let waitingOn = content.waitingOn.flatMap { DecisionDraft.isPersonName($0) ? $0 : nil }
                if kind.isWork {
                    decision.ownerId = try owner.flatMap { try archive.person(named: $0)?.id }
                    // Someone else promised it: it waits for them, until the promised day (ADR-0074).
                    if let waitingOn, let person = try archive.person(named: waitingOn) {
                        decision.waitingOnId = person.id
                        decision.waitingUntil = content.dueDate
                        decision.status = .waiting
                    } else {
                        decision.dueAt = content.dueDate
                    }
                    if kind == .risk { decision.severity = content.severity.flatMap(Decision.Severity.init) }
                }
                // A proposal that closes an open entry (answers, accepts) does so through `supersedesId`.
                try archive.createDecision(decision, people: [owner, waitingOn].compactMap { $0 })
            case .person:
                if let speakerID = content.targetID {
                    try archive.renameSpeaker(speakerID, of: item.id, to: content.text)
                    // One name per speaker: the other proposals for it (engine or voice) are answered.
                    for other in try archive.suggestions(itemID: item.id)
                    where other.id != suggestion.id && other.kind == .person && other.content.targetID == speakerID {
                        try archive.setSuggestionStatus(other.id, .rejected)
                    }
                }
            case .tag:
                let current = try archive.tags(for: item.id).map(\.name)
                try archive.setTags(current + [content.text], for: item.id)
            case .project:
                if let projectID = content.targetID { try archive.updateItem(item.id) { $0.projectId = projectID } }
            case .link:
                if let target = content.targetID {
                    try archive.addLink(from: item.id, to: target, kind: .related, origin: .suggestion)
                }
            }
            try archive.setSuggestionStatus(suggestion.id, .accepted)
        }
        refreshTextAssets(item.id)
        intelligence.poke()
        reload()
    }

    func dismiss(_ suggestion: Suggestion) {
        perform { try archive.setSuggestionStatus(suggestion.id, .rejected) }
        reload()
    }

    /// "Modifica…" on a key point: the editor, prefilled; saving it confirms the proposal.
    func edit(_ suggestion: Suggestion) {
        guard let item = item(suggestion.itemId) else { return }
        let content = suggestion.content
        var draft = DecisionDraft(item: item, atSec: content.atSec, text: content.text, origin: .extraction)
        draft.kind = suggestion.kind.keyPointKind ?? .decision
        draft.supersedesID = content.supersedesID
        if let owner = content.owner, DecisionDraft.isPersonName(owner) {
            draft.people = [owner]
            if draft.kind.isWork { draft.ownerName = owner }
        }
        if draft.kind.isWork {
            if let waitingOn = content.waitingOn, DecisionDraft.isPersonName(waitingOn) {
                if !draft.people.contains(waitingOn) { draft.people.append(waitingOn) }
                draft.waitingOnName = waitingOn
                draft.waitingUntil = content.dueDate
                draft.status = .waiting
            } else {
                draft.dueAt = content.dueDate
            }
            if draft.kind == .risk { draft.severity = content.severity.flatMap(Decision.Severity.init) }
        }
        draft.suggestionID = suggestion.id
        editingDecision = draft
    }
}

extension Suggestion.Kind {
    /// The key point a proposal becomes; nil for names, tags, projects and links.
    var keyPointKind: Decision.Kind? {
        switch self {
        case .decision: .decision
        case .activity: .action
        case .question: .openQuestion
        case .risk: .risk
        case .request: .request
        case .person, .tag, .project, .link: nil
        }
    }
}

/// "Proposte (N)" in the item view.
struct SuggestionsSection: View {
    let model: AppModel
    let item: Item
    @State private var suggestions: [Suggestion] = []

    var body: some View {
        let busy = model.intelligence.proposingFor == item.title
        if !suggestions.isEmpty || busy || model.engine.activeModel != nil {
            SectionBox(
                suggestions.isEmpty
                    ? String(localized: "Proposte") : String(localized: "Proposte (\(suggestions.count))"),
                systemImage: "cpu", tint: .indigo, collapseKey: "suggestions"
            ) {
                ForEach(suggestions) { suggestion in
                    SuggestionRow(model: model, item: item, suggestion: suggestion)
                    if suggestion.id != suggestions.last?.id { Divider() }
                }
                HStack {
                    if busy {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "Sto preparando le proposte…")).font(.caption).foregroundStyle(
                            .secondary)
                    } else {
                        Button(
                            suggestions.isEmpty
                                ? String(localized: "Cerca proposte") : String(localized: "Cerca di nuovo"),
                            systemImage: "cpu"
                        ) { model.intelligence.suggestNow(item.id) }
                        .help(
                            String(
                                localized:
                                    "Il motore locale propone decisioni, attività, punti da chiarire, rischi, richieste, nomi, tag e collegamenti; niente viene applicato senza la tua conferma"
                            ))
                    }
                    Spacer()
                    if !suggestions.isEmpty {
                        Text(String(localized: "Proposte da controllare: niente cambia finché non le confermi."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .task(id: "\(model.revision)-\(model.intelligence.revision)") {
                suggestions = (try? model.archive.suggestions(itemID: item.id)) ?? []
            }
        }
    }
}

struct SuggestionRow: View {
    let model: AppModel
    let item: Item
    let suggestion: Suggestion

    var body: some View {
        let content = suggestion.content
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Self.kindLabel(suggestion.kind, content)).font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                Text(content.text).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
                if let owner = content.owner { Text("— \(owner)").foregroundStyle(.secondary) }
                Spacer()
                if let at = content.atSec, item.type == .call {
                    Button(Format.clock(at)) {
                        model.pendingSeek = (item.id, at)
                        model.selectedItemID = item.id
                    }
                    .buttonStyle(.link).monospacedDigit()
                }
            }
            if let details = Self.details(content) {
                Text(details).font(.caption).foregroundStyle(.secondary)
            }
            if let quote = content.quote {
                Text("«\(quote)»").font(.callout).italic().foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let reason = Self.reason(suggestion.kind, content, model) {
                Text(reason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ProvenanceLine(
                text: Provenance.suggestion(suggestion),
                model: suggestion.origin == .engine ? suggestion.model : nil)
            HStack {
                Button(String(localized: "Conferma")) { model.accept(suggestion) }
                if suggestion.kind.keyPointKind != nil {
                    Button(String(localized: "Modifica…")) { model.edit(suggestion) }
                }
                Button(String(localized: "Scarta"), role: .destructive) { model.dismiss(suggestion) }
                    .buttonStyle(.link)
            }
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    static func kindLabel(_ kind: Suggestion.Kind, _ content: SuggestionPayload) -> String {
        switch kind {
        case .decision: String(localized: "Decisione")
        case .activity: String(localized: "Attività")
        case .person: String(localized: "Nome dello speaker")
        case .tag: content.isNew == true ? String(localized: "Tag nuovo") : String(localized: "Tag")
        case .project: String(localized: "Progetto")
        case .link: String(localized: "Collegamento")
        case .question: String(localized: "Punto da chiarire")
        case .risk: String(localized: "Rischio")
        case .request: String(localized: "Richiesta")
        }
    }

    /// "attende Anna · entro 30 ott", "gravità alta" (ADR-0074).
    static func details(_ content: SuggestionPayload) -> String? {
        var parts: [String] = []
        if let waitingOn = content.waitingOn { parts.append(String(localized: "attende \(waitingOn)")) }
        if let due = content.dueDate {
            parts.append(String(localized: "entro \(due.formatted(.dateTime.day().month(.abbreviated)))"))
        }
        switch content.severity {
        case "high": parts.append(String(localized: "gravità alta"))
        case "medium": parts.append(String(localized: "gravità media"))
        case "low": parts.append(String(localized: "gravità bassa"))
        default: break
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func reason(_ kind: Suggestion.Kind, _ content: SuggestionPayload, _ model: AppModel) -> String? {
        switch kind {
        case .decision, .activity:
            guard let id = content.supersedesID, let previous = try? model.archive.decision(id) else { return nil }
            // The verb of the link depends on what it closes (ADR-0074).
            switch previous.kind {
            case .openQuestion:
                return String(localized: "Risponde a «\(previous.text)»: confermando, il punto diventa Chiarito.")
            case .request:
                return String(localized: "Accoglie «\(previous.text)»: confermando, la richiesta diventa Accolta.")
            case .action:
                return String(localized: "Completa «\(previous.text)»: confermando, l'attività diventa Fatta.")
            default:
                return String(
                    localized: "Potrebbe superare «\(previous.text)»: confermando, quella diventa Superata.")
            }
        case .person:
            return content.reason.map { String(localized: "\($0) diventa «\(content.text)»") }
        case .project, .link: return content.reason
        default: return nil
        }
    }
}

/// The mark of pending proposals on lists and timelines.
struct SuggestionBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Label(String(localized: "\(count) proposte"), systemImage: "cpu")
                .font(.caption2.weight(.semibold)).foregroundStyle(.indigo)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(Color.indigo.opacity(0.12)))
                .help(String(localized: "Proposte del motore locale da controllare"))
        }
    }
}
