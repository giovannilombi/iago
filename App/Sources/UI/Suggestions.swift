import IAGOEngine
import IAGOStore
import SwiftUI

/// Confirming and dismissing the engine's proposals (ADR-0049, FR-111): only a confirmed proposal changes the archive,
/// and it becomes an ordinary decision, activity, speaker name, tag, project or link.
extension AppModel {
    func accept(_ suggestion: Suggestion) {
        guard let item = item(suggestion.itemId) else { return }
        let content = suggestion.content
        perform {
            switch suggestion.kind {
            case .decision, .activity:
                var decision = Decision(
                    text: content.text,
                    decidedAt: item.occurredAt.addingTimeInterval(content.atSec ?? 0), projectId: item.projectId,
                    sourceItemId: item.id, sourceAtSec: content.atSec, supersedesId: content.supersedesID,
                    origin: .extraction, kind: suggestion.kind == .activity ? .action : .decision)
                decision.model = Provenance.decisionModel(of: suggestion)
                try archive.createDecision(
                    decision, people: content.owner.map { DecisionDraft.isPersonName($0) ? [$0] : [] } ?? [])
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

    /// "Modifica…" on a decision or activity: the editor, prefilled; saving it confirms the proposal.
    func edit(_ suggestion: Suggestion) {
        guard let item = item(suggestion.itemId) else { return }
        let content = suggestion.content
        var draft = DecisionDraft(item: item, atSec: content.atSec, text: content.text, origin: .extraction)
        draft.kind = suggestion.kind == .activity ? .action : .decision
        draft.supersedesID = content.supersedesID
        if let owner = content.owner, DecisionDraft.isPersonName(owner) { draft.people = [owner] }
        draft.suggestionID = suggestion.id
        editingDecision = draft
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
                                    "Il motore locale propone decisioni, attività, nomi, tag e collegamenti; niente viene applicato senza la tua conferma"
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
                if suggestion.kind == .decision || suggestion.kind == .activity {
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
        }
    }

    static func reason(_ kind: Suggestion.Kind, _ content: SuggestionPayload, _ model: AppModel) -> String? {
        switch kind {
        case .decision:
            guard let id = content.supersedesID, let previous = try? model.archive.decision(id) else { return nil }
            return String(localized: "Potrebbe superare «\(previous.text)»: confermando, quella diventa Superata.")
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
