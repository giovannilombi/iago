import IAGOExport
import IAGOIntelligence
import IAGOStore
import SwiftUI

/// What the decision editor works on: a new decision (from a bookmark, a selection, a note or by hand) or an
/// existing one (FR-152).
struct DecisionDraft: Identifiable {
    let id = UUID()
    var existingID: String?
    /// Decision, activity or milestone (ADR-0046).
    var kind = Decision.Kind.decision
    var text = ""
    var decidedAt = Date()
    var projectID: String?
    var sourceItemID: String?
    var sourceAtSec: Double?
    var sourceNoteID: String?
    var origin = Decision.Origin.manual
    var people: [String] = []
    /// ADR-0038: streams of the decision's project.
    var streamIDs: [String] = []
    var tags: [String] = []
    /// ADR-0052: the entries this one supersedes, of any kind.
    var supersedesIDs: [String] = []
    /// A single entry to supersede (proposals, "Supera con…").
    var supersedesID: String? {
        get { supersedesIDs.first }
        set { supersedesIDs = newValue.map { [$0] } ?? [] }
    }
    /// The chosen decision already comes later in this one's chain: move this one after it (confirmed by the user).
    var reorderingChain = false
    var notes = ""
    var markerID: String?
    /// ADR-0049: the proposal this draft comes from; saving it confirms the proposal.
    var suggestionID: String?
    /// Shown read-only in the editor: where the decision comes from.
    var sourceLabel: String?
    /// Placeholder of an empty title (first sentence); used as the title if the user leaves it empty.
    var titleHint: String?
    // Open work (ADR-0074): people by name, resolved to person entities on saving.
    var ownerName: String?
    var dueAt: Date?
    var waitingOnName: String?
    var waitingUntil: Date?
    var priority: Int?
    var severity: Decision.Severity?
    var status = Decision.Status.active

    init(projectID: String? = nil, kind: Decision.Kind = .decision) {
        self.projectID = projectID
        self.kind = kind
    }

    /// Editing an existing decision.
    init(_ summary: DecisionSummary) {
        let decision = summary.decision
        existingID = decision.id
        kind = decision.kind
        text = decision.text
        decidedAt = decision.decidedAt
        projectID = decision.projectId
        sourceItemID = decision.sourceItemId
        sourceAtSec = decision.sourceAtSec
        sourceNoteID = decision.sourceNoteId
        origin = decision.origin
        people = summary.people
        tags = summary.tags
        streamIDs = summary.streamIDs
        supersedesIDs = summary.supersedesAll.map(\.id)
        notes = decision.notes ?? ""
        if let title = summary.sourceTitle {
            sourceLabel = decision.sourceAtSec.map { "\(title) · \(Format.clock($0))" } ?? title
        }
    }

    /// From a point of an item: bookmark or transcript passage. The date is the moment in the call.
    init(item: Item, atSec: Double?, text: String, origin: Decision.Origin, speaker: String? = nil) {
        setContent(text)
        decidedAt = item.occurredAt.addingTimeInterval(atSec ?? 0)
        projectID = item.projectId
        sourceItemID = item.id
        sourceAtSec = atSec
        self.origin = origin
        if let speaker, Self.isPersonName(speaker) { people = [speaker] }
        sourceLabel = atSec.map { "\(item.title) · \(Format.clock($0))" } ?? item.title
    }

    /// "Promuovi a decisione" (FR-174): text and date of the note.
    init(note: Note, item: Item?, kind: Decision.Kind = .decision) {
        self.kind = kind
        setContent(note.body)
        decidedAt = note.notedAt
        projectID = note.projectId ?? item?.projectId
        sourceItemID = item?.id
        sourceNoteID = note.id
        origin = .note
        sourceLabel = String(localized: "Nota del \(note.notedAt.formatted(date: .abbreviated, time: .shortened))")
    }

    /// A new decision that replaces `summary` (FR-151): an activity that becomes a decision, too (ADR-0046).
    static func superseding(_ summary: DecisionSummary, kind: Decision.Kind = .decision) -> DecisionDraft {
        var draft = DecisionDraft(projectID: summary.decision.projectId, kind: kind)
        if summary.decision.kind == .action, kind == .decision {
            draft.text = summary.decision.text
            draft.notes = summary.decision.notes ?? ""
        }
        draft.supersedesID = summary.decision.id
        draft.people = summary.people
        draft.tags = summary.tags
        draft.streamIDs = summary.streamIDs
        return draft
    }

    /// A short passage becomes the title; a long one goes in the description, with its first sentence (clipped)
    /// as a title to refine.
    /// A short passage is the title itself. A longer one goes whole into the description: the title is proposed
    /// by the on-device model when the editor opens (ADR-0042), with the first sentence as hint meanwhile.
    mutating func setContent(_ passage: String) {
        let trimmed = passage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > Self.titleLength else {
            text = trimmed
            return
        }
        text = ""
        notes = trimmed
        titleHint = TitleSuggester.firstSentence(trimmed, limit: Self.titleLength)
    }

    static let titleLength = 90

    /// Generic speaker labels ("Speaker 2", "Io") are not people to record.
    static func isPersonName(_ label: String) -> Bool {
        let generic = ["Io", "Speaker", "Stanza"]
        return !generic.contains { label == $0 || label.hasPrefix("\($0) ") }
    }

    var decision: Decision {
        Decision(
            text: text, decidedAt: decidedAt, projectId: projectID, sourceItemId: sourceItemID,
            sourceAtSec: sourceAtSec, sourceNoteId: sourceNoteID, origin: origin,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes, kind: kind)
    }
}

// MARK: - Register

/// "Decisioni" (FR-153): the register of the current scope as a timeline, most recent first, only active
/// ones by default. A superseded decision sits right under the one that replaced it when they share the day.
struct DecisionsView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                PendingKeyPoints(model: model)
                ForEach(months, id: \.month) { group in
                    Text(group.month.formatted(.dateTime.month(.wide).year()).capitalized)
                        .font(.title3).bold().padding(.top, 18).padding(.bottom, 6).padding(.leading, 8)
                    ForEach(group.entries, id: \.summary.id) { entry in
                        DecisionTimelineEntry(model: model, summary: entry.summary, nested: entry.nested)
                    }
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                ViewModePicker(model: model)
                DecisionFilterBar(model: model)
            }
            .background(.bar)
        }
        .overlay {
            if model.decisions.isEmpty, model.pendingSuggestions.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Nessun punto chiave"), systemImage: "checkmark.seal")
                } description: {
                    Text(
                        String(
                            localized:
                                "Decisioni, attività e tappe: creale da un segnalibro, dal tasto destro su una frase della trascrizione, da una nota oppure qui."
                        ))
                } actions: {
                    NewKeyPointMenu(model: model, projectID: model.scopeProjectID, title: String(localized: "Nuovo"))
                }
            }
        }
    }

    private var months: [(month: Date, entries: [(summary: DecisionSummary, nested: Bool)])] {
        let calendar = Calendar.current
        let arranged = DecisionOrdering.arrange(model.decisions)
        var groups: [(month: Date, entries: [(summary: DecisionSummary, nested: Bool)])] = []
        for entry in arranged {
            let month = calendar.date(
                from: calendar.dateComponents([.year, .month], from: entry.summary.decision.decidedAt))!
            if groups.last?.month == month {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append((month, [entry]))
            }
        }
        return groups
    }
}

/// Order of the register and of the timeline: most recent first; a decision superseded on the same day as
/// the one replacing it goes right under it (`nested`), whatever the times.
enum DecisionOrdering {
    static func arrange(_ decisions: [DecisionSummary]) -> [(summary: DecisionSummary, nested: Bool)] {
        let calendar = Calendar.current
        let sorted = decisions.sorted { $0.decision.decidedAt > $1.decision.decidedAt }
        let byID = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
        /// Superseded decisions placed under their successor: the most recent one of the same day (ADR-0052).
        var parent: [String: String] = [:]
        for summary in sorted {
            for previous in summary.supersedesAll {
                guard parent[previous.id] == nil, let shown = byID[previous.id],
                    calendar.isDate(shown.decision.decidedAt, inSameDayAs: summary.decision.decidedAt)
                else { continue }
                parent[previous.id] = summary.id
            }
        }
        var result: [(DecisionSummary, Bool)] = []
        var emitted: Set<String> = []
        func emit(_ summary: DecisionSummary, nested: Bool) {
            guard emitted.insert(summary.id).inserted else { return }
            result.append((summary, nested))
            for previous in summary.supersedesAll where parent[previous.id] == summary.id {
                if let shown = byID[previous.id] { emit(shown, nested: true) }
            }
        }
        let attached = Set(parent.keys)
        for summary in sorted where !attached.contains(summary.id) { emit(summary, nested: false) }
        return result
    }
}

/// One step of the decision timeline: date on the left, a seal on the line, the decision card.
private struct DecisionTimelineEntry: View {
    let model: AppModel
    let summary: DecisionSummary
    let nested: Bool

    var body: some View {
        let decision = summary.decision
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(decision.decidedAt.formatted(.dateTime.day().month(.abbreviated))).font(.callout).bold()
                Text(decision.decidedAt.formatted(.dateTime.hour().minute())).font(.caption).foregroundStyle(
                    .secondary)
            }
            .frame(width: 70, alignment: .trailing)
            .padding(.top, 12)
            .opacity(nested ? 0.6 : 1)
            ZStack(alignment: .top) {
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 2)
                Image(systemName: DecisionRow.icon(decision))
                    .font(.system(size: 15))
                    .foregroundStyle(DecisionRow.color(decision))
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(-2))
                    .padding(.top, 13)
            }
            .frame(width: 30)
            HStack(spacing: 6) {
                if nested {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary).padding(.top, 14)
                }
                DecisionRow(
                    model: model, summary: summary, showsProject: model.decisionScopeSpansProjects, showsIcon: false
                )
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(
                        decision.status == .active
                            ? Color.green.opacity(0.07) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10).stroke(
                        decision.status == .active ? Color.green.opacity(0.35) : Color.secondary.opacity(0.2)))
            }
            .padding(.leading, nested ? 18 : 0)
            .padding(.vertical, 5)
        }
    }
}

private struct DecisionFilterBar: View {
    @Bindable var model: AppModel

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 8) {
            FilterChip(title: kindTitle, systemImage: "square.stack", active: !model.decisionQuery.kinds.isEmpty) {
                OptionList(
                    options: [(Decision.Kind?.none, String(localized: "Tutti i tipi"))]
                        + [Decision.Kind.decision, .action, .milestone].map {
                            (Optional($0), Self.kindPlural($0))
                        },
                    selection: Binding(
                        get: { model.decisionQuery.kinds.first },
                        set: { model.decisionQuery.kinds = $0.map { [$0] } ?? [] }))
            }
            FilterChip(title: statusTitle, systemImage: "line.3.horizontal.decrease", active: !onlyActive) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Decision.Status.allCases, id: \.self) { status in
                        OptionCheckRow(
                            label: Self.plural(status), checked: model.decisionQuery.statuses.contains(status)
                        ) {
                            if model.decisionQuery.statuses.contains(status) {
                                if model.decisionQuery.statuses.count > 1 {
                                    model.decisionQuery.statuses.remove(status)
                                }
                            } else {
                                model.decisionQuery.statuses.insert(status)
                            }
                        }
                    }
                }
            }
            FilterChip(title: personTitle, systemImage: "person", active: model.decisionQuery.personID != nil) {
                if model.people.isEmpty {
                    Text(String(localized: "Nessuna persona")).foregroundStyle(.secondary)
                } else {
                    OptionList(
                        options: [(String?.none, String(localized: "Tutte"))]
                            + model.people.map { (Optional($0.id), $0.name) },
                        selection: $model.decisionQuery.personID)
                }
            }
            FilterChip(title: tagTitle, systemImage: "number", active: !model.decisionQuery.tags.isEmpty) {
                if model.tags.isEmpty {
                    Text(String(localized: "Nessun tag")).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(model.tags) { tag in
                                OptionCheckRow(
                                    label: "#\(tag.name)", checked: model.decisionQuery.tags.contains(tag.normalized)
                                ) {
                                    if model.decisionQuery.tags.contains(tag.normalized) {
                                        model.decisionQuery.tags.remove(tag.normalized)
                                    } else {
                                        model.decisionQuery.tags.insert(tag.normalized)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
            }
            ChipButton(
                title: String(localized: "Azzera"), systemImage: "eraser", active: false, showsChevron: false,
                destructive: true
            ) {
                model.decisionQuery = DecisionQuery()
            }
            .disabled(model.decisionQuery == DecisionQuery())
            NewKeyPointMenu(model: model, projectID: model.scopeProjectID, title: String(localized: "Nuovo"))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().stroke(Color.accentColor.opacity(0.6)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.top, 2).padding(.bottom, 10)
    }

    private var onlyActive: Bool { model.decisionQuery.statuses == [.active] }

    private var kindTitle: String {
        model.decisionQuery.kinds.first.map(Self.kindPlural) ?? String(localized: "Tutti i tipi")
    }

    static func kindPlural(_ kind: Decision.Kind) -> String {
        switch kind {
        case .decision: String(localized: "Decisioni")
        case .action: String(localized: "Attività")
        case .milestone: String(localized: "Tappe")
        case .openQuestion: String(localized: "Domande aperte")
        }
    }

    private var statusTitle: String {
        let statuses = Decision.Status.allCases.filter { model.decisionQuery.statuses.contains($0) }
        if statuses.count == Decision.Status.allCases.count { return String(localized: "Tutti gli stati") }
        return statuses.map { Self.plural($0) }.joined(separator: ", ")
    }

    static func plural(_ status: Decision.Status) -> String {
        switch status {
        case .active: String(localized: "Attive / aperte")
        case .done: String(localized: "Fatte")
        case .superseded: String(localized: "Superate")
        case .cancelled: String(localized: "Annullate")
        }
    }

    private var personTitle: String {
        model.people.first { $0.id == model.decisionQuery.personID }?.name ?? String(localized: "Persona")
    }

    private var tagTitle: String {
        let tags = model.decisionQuery.tags
        switch tags.count {
        case 0: return String(localized: "Tag")
        case 1: return "#\(model.tags.first { $0.normalized == tags.first }?.name ?? tags.first!)"
        default: return String(localized: "Tag · \(tags.count)")
        }
    }
}

/// One decision: text, date, people, source (or a warning when it is gone, FR-156) and its evolution.
struct DecisionRow: View {
    let model: AppModel
    let summary: DecisionSummary
    var showsProject = true
    var compact = false
    var showsIcon = true
    @State private var showsDescription = false
    @State private var showsChain = false
    @State private var chain: [Decision] = []
    @State private var deleting = false

    var body: some View {
        let decision = summary.decision
        HStack(alignment: .top, spacing: 10) {
            if showsIcon {
                Image(systemName: Self.icon(decision))
                    .foregroundStyle(Self.color(decision)).font(.title3)
                    .help(Self.label(decision))
            }
            VStack(alignment: .leading, spacing: 5) {
                if showsProject { projectBadge }
                if let name = summary.chainName { ChainNameBadge(name: name) }
                Text(decision.text)
                    .font(.headline)
                    .strikethrough(decision.status != .active, color: .secondary)
                    .foregroundStyle(decision.status == .active ? .primary : .secondary)
                    .lineLimit(compact ? 2 : 3)
                if let description = decision.notes, !description.isEmpty { descriptionView(description) }
                metaLine
                ViaClaudeBadge(model: model, entity: .decision, id: decision.id)
                StreamDots(model: model, streamIDs: summary.streamIDs)
                sourceLine
                if summary.supersedes != nil || summary.supersededBy != nil { chainView }
                if !summary.tags.isEmpty {
                    Text(summary.tags.map { "#\($0)" }.joined(separator: " ")).font(.caption).foregroundStyle(.tint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(
                model.selectedDecisionID == decision.id ? Color.accentColor.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.selectedDecisionID = decision.id }
        .contextMenu { menu }
        .confirmationDialog(String(localized: "Eliminare la decisione?"), isPresented: $deleting) {
            Button(String(localized: "Elimina"), role: .destructive) { model.deleteDecision(decision.id) }
        } message: {
            Text(
                String(
                    localized:
                        "Non si può annullare. Se superava un'altra decisione, quella torna attiva. Per tenerne traccia usa \"Annulla decisione\"."
                ))
        }
    }

    /// Projects are the centre of IAGO: outside a project every decision shows its own, well visible.
    private var projectBadge: some View {
        Label(
            summary.projectName ?? String(localized: "Senza progetto"),
            systemImage: summary.projectName == nil ? "tray" : "folder.fill"
        )
        .help(
            summary.projectName == nil
                ? String(
                    localized:
                        "Nessun progetto: quando classifichi l'elemento da cui è nata, la decisione passa al suo progetto."
                ) : ""
        )
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(
            Capsule().fill(summary.projectName == nil ? Color.orange.opacity(0.18) : Color.accentColor.opacity(0.18))
        )
        .foregroundStyle(summary.projectName == nil ? Color.orange : Color.accentColor)
    }

    private func descriptionView(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                showsDescription.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(showsDescription ? 90 : 0))
                    Text(showsDescription ? String(localized: "Nascondi dettagli") : String(localized: "Dettagli"))
                }
                .font(.caption).foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            if showsDescription {
                MarkdownText(markdown: description)
                    .font(.callout)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
            }
        }
    }

    private var metaLine: some View {
        let decision = summary.decision
        var parts = [decision.decidedAt.formatted(.dateTime.day().month(.abbreviated).year())]
        if decision.status != .active { parts.append(Self.label(decision)) }
        if !summary.people.isEmpty { parts.append(summary.people.joined(separator: ", ")) }
        return Text(parts.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var sourceLine: some View {
        let decision = summary.decision
        switch summary.sourceState {
        case .available:
            HStack(spacing: 4) {
                Image(systemName: decision.sourceAtSec != nil ? "play.circle" : "arrow.up.right.square")
                if decision.sourceNoteId != nil {
                    Text(String(localized: "Da una nota"))
                } else {
                    Text(summary.sourceTitle ?? "")
                    if let at = decision.sourceAtSec { Text("· \(Format.clock(at))").monospacedDigit() }
                }
            }
            .font(.caption).foregroundStyle(.tint)
            .help(
                decision.sourceAtSec != nil
                    ? String(localized: "Clic: ascolta da questo punto") : String(localized: "Clic: apri la fonte"))
        case .trashed:
            Label(String(localized: "Fonte nel cestino"), systemImage: "trash").font(.caption).foregroundStyle(
                .orange)
        case .deleted:
            Label(String(localized: "Fonte eliminata: resta solo la decisione"), systemImage: "link.badge.plus")
                .font(.caption).foregroundStyle(.orange)
        case .none:
            EmptyView()
        }
    }

    private var chainView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                showsChain.toggle()
                if showsChain { chain = (try? model.archive.decisionChain(of: summary.id)) ?? [] }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(showsChain ? 90 : 0))
                    if let later = summary.supersededBy {
                        Text(Self.linkLine(String(localized: "Superata da"), summary.supersededByAll)).lineLimit(1)
                    } else if summary.supersedes != nil {
                        Text(Self.linkLine(String(localized: "Supera"), summary.supersedesAll)).lineLimit(1)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            if showsChain {
                VStack(alignment: .leading, spacing: 3) {
                    if summary.supersededBy != nil, !summary.supersedesAll.isEmpty {
                        Text(Self.linkLine(String(localized: "Supera"), summary.supersedesAll))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if summary.supersededByAll.count > 1 || (summary.supersededBy != nil && summary.supersedes != nil) {
                        Text(Self.linkLine(String(localized: "Superata da"), summary.supersededByAll))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(chain.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(index + 1).").monospacedDigit()
                            Text(step.decidedAt.formatted(.dateTime.day().month(.abbreviated).year()))
                                .foregroundStyle(.secondary)
                            Text(step.text).fontWeight(step.id == summary.id ? .semibold : .regular)
                                .foregroundStyle(step.status == .active ? .primary : .secondary)
                        }
                        .font(.caption)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
            }
        }
    }

    @ViewBuilder
    private var menu: some View {
        let decision = summary.decision
        Button(String(localized: "Modifica…")) { model.editingDecision = DecisionDraft(summary) }
        if decision.kind == .action, decision.status == .active {
            Button(String(localized: "Segna come fatta")) { model.setDecisionStatus(decision.id, .done) }
            Button(String(localized: "Diventa decisione…")) {
                model.editingDecision = .superseding(summary, kind: .decision)
            }
        } else if decision.kind == .action, decision.status == .done {
            Button(String(localized: "Riapri")) { model.setDecisionStatus(decision.id, .active) }
        }
        if decision.status == .active {
            Button(String(localized: "Supera con una nuova decisione…")) {
                model.editingDecision = .superseding(summary)
            }
            Button(String(localized: "Annulla")) { model.setDecisionStatus(decision.id, .cancelled) }
        } else if decision.status == .cancelled {
            Button(String(localized: "Riattiva")) { model.setDecisionStatus(decision.id, .active) }
        }
        Divider()
        Button(String(localized: "Elimina…"), role: .destructive) { deleting = true }
    }

    static func label(_ decision: Decision) -> String { KeyPointLabels.status(decision) }

    /// "Supera: A" or "Supera: A e altre 2" (ADR-0052).
    static func linkLine(_ prefix: String, _ entries: [Decision]) -> String {
        guard let first = entries.first else { return prefix }
        return entries.count == 1
            ? "\(prefix): \(first.text)"
            : String(localized: "\(prefix): \(first.text) e altre \(entries.count - 1)")
    }

    static func kindLabel(_ kind: Decision.Kind) -> String {
        switch kind {
        case .decision: String(localized: "Decisione")
        case .action: String(localized: "Attività")
        case .milestone: String(localized: "Tappa")
        case .openQuestion: String(localized: "Domanda aperta")
        }
    }

    static func icon(_ decision: Decision) -> String {
        switch (decision.kind, decision.status) {
        case (_, .superseded): "arrow.triangle.2.circlepath"
        case (.action, .active): "circle.dashed"
        case (.action, .done): "checkmark.circle.fill"
        case (.action, .cancelled): "xmark.circle"
        case (.milestone, .cancelled): "flag.slash"
        case (.milestone, _): "flag.fill"
        case (_, .cancelled): "xmark.seal"
        default: "checkmark.seal.fill"
        }
    }

    static func color(_ decision: Decision) -> Color {
        switch (decision.kind, decision.status) {
        case (_, .superseded): .secondary
        case (_, .cancelled): .red
        case (.action, .done): .secondary
        case (.action, _): .orange
        case (.milestone, _): .blue
        default: .green
        }
    }

    /// The kind's own colour, for labels and new-item menus.
    static func tint(_ kind: Decision.Kind) -> Color {
        switch kind {
        case .action: .orange
        case .milestone: .blue
        default: .green
        }
    }

    static func kindIcon(_ kind: Decision.Kind) -> String {
        switch kind {
        case .action: "circle.dashed"
        case .milestone: "flag.fill"
        default: "checkmark.seal.fill"
        }
    }
}

/// "+ Nuovo…": decision, activity or milestone (ADR-0046).
struct NewKeyPointMenu: View {
    let model: AppModel
    var projectID: String?
    var title = String(localized: "Aggiungi")

    var body: some View {
        Menu {
            ForEach([Decision.Kind.action, .milestone, .decision], id: \.self) { kind in
                Button {
                    model.newKeyPoint(kind, projectID: projectID)
                } label: {
                    Label(DecisionRow.kindLabel(kind), systemImage: DecisionRow.kindIcon(kind))
                }
            }
        } label: {
            Label(title, systemImage: "plus")
        }
        .menuStyle(.borderlessButton).fixedSize()
    }
}

// MARK: - Editor

struct DecisionEditor: View {
    let model: AppModel
    @State var draft: DecisionDraft
    @State private var candidates: [DecisionSummary] = []
    /// Set when the decision is dated before the one it supersedes: the date the user may switch to.
    @State private var earlierThanTarget: Date?
    /// Set when the chosen decision already comes later in the chain: its title, to confirm the new order.
    @State private var laterInChain: String?
    @State private var suggesting = false
    /// The title the model wrote, while the user has not changed it.
    @State private var suggestedTitle: String?
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, draft: DecisionDraft) {
        self.model = model
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                Self.title(draft), systemImage: DecisionRow.kindIcon(draft.kind)
            )
            .font(.title2).bold()
            .foregroundStyle(DecisionRow.tint(draft.kind))
            Picker("", selection: $draft.kind) {
                ForEach([Decision.Kind.action, .milestone, .decision], id: \.self) { kind in
                    Text(DecisionRow.kindLabel(kind)).tag(kind)
                }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            Text(Self.explanation(draft.kind)).font(.caption).foregroundStyle(.secondary)
            if let source = draft.sourceLabel {
                Label(source, systemImage: draft.sourceAtSec != nil ? "waveform" : "doc.text")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    Self.placeholder(draft.kind), text: $draft.text,
                    prompt: draft.titleHint.map { Text($0) }
                )
                .font(.title3).textFieldStyle(.roundedBorder)
                .onChange(of: draft.text) { _, text in if text != suggestedTitle { suggestedTitle = nil } }
                if suggesting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text(String(localized: "Sto proponendo un titolo…"))
                    }
                    .font(.caption).foregroundStyle(.secondary)
                } else if suggestedTitle != nil {
                    Label(
                        String(localized: "Titolo proposto da Apple Intelligence, sul Mac: modificalo se serve"),
                        systemImage: "sparkles"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                } else if draft.text.isEmpty, draft.titleHint != nil {
                    Text(String(localized: "Scrivi un titolo breve, oppure lascia vuoto per usare la prima frase."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Descrizione (facoltativa)")).font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $draft.notes)
                    .font(.body)
                    .frame(height: 110)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    .overlay(alignment: .topLeading) {
                        if draft.notes.isEmpty {
                            Text(String(localized: "Dettagli, contesto, motivazioni, passaggio della call…"))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 9).padding(.vertical, 4).allowsHitTesting(false)
                        }
                    }
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text(String(localized: "Data")).foregroundStyle(.secondary).fixedSize()
                    DatePicker("", selection: $draft.decidedAt).labelsHidden().fixedSize()
                }
                GridRow {
                    Text(String(localized: "Progetto")).foregroundStyle(needsProject ? .orange : .secondary).fixedSize()
                    Picker("", selection: $draft.projectID) {
                        Text(String(localized: "Nessuno")).tag(String?.none)
                        ForEach(model.projects) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .labelsHidden().fixedSize()
                }
                if let hint = projectHint {
                    GridRow {
                        Color.clear.frame(width: 1, height: 1)
                        Text(hint).font(.caption).foregroundStyle(needsProject ? .orange : .secondary)
                    }
                }
                if let projectID = draft.projectID {
                    GridRow(alignment: .top) {
                        Text(String(localized: "Stream")).foregroundStyle(.secondary).fixedSize()
                        StreamChooser(model: model, projectID: projectID, selection: $draft.streamIDs)
                    }
                }
                GridRow(alignment: .top) {
                    Text(String(localized: "Persone")).foregroundStyle(.secondary).fixedSize()
                    TokenField(
                        values: $draft.people, placeholder: String(localized: "Aggiungi persona"), prefix: "",
                        suggestions: model.people.map(\.name))
                }
                GridRow(alignment: .top) {
                    Text(String(localized: "Tag")).foregroundStyle(.secondary).fixedSize()
                    TokenField(
                        values: $draft.tags, placeholder: String(localized: "Aggiungi tag"), prefix: "#",
                        suggestions: model.tags.map(\.name))
                }
                GridRow(alignment: .top) {
                    Text(String(localized: "Supera")).foregroundStyle(.secondary).fixedSize()
                    supersedeChooser
                }
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Salva")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        (draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.titleHint == nil)
                            || needsProject || suggesting)
            }
        }
        .padding(20)
        .frame(width: 560)
        .onChange(of: draft.projectID) { _, projectID in
            let valid = Set(model.streams(of: projectID).map(\.id))
            draft.streamIDs.removeAll { !valid.contains($0) }
        }
        .alert(
            String(localized: "La data è precedente alla decisione che superi"),
            isPresented: Binding(get: { earlierThanTarget != nil }, set: { if !$0 { earlierThanTarget = nil } }),
            presenting: earlierThanTarget
        ) { date in
            Button(String(localized: "Usa \(date.formatted(date: .abbreviated, time: .shortened))")) {
                draft.decidedAt = date
                commit()
            }
            Button(String(localized: "Mantieni la data")) { commit() }
            Button(String(localized: "Annulla"), role: .cancel) {}
        } message: { date in
            Text(
                String(
                    localized:
                        "Questa decisione è del \(draft.decidedAt.formatted(date: .abbreviated, time: .shortened)), ma quella che supera è del \(date.formatted(date: .abbreviated, time: .shortened)). Vuoi spostarla alla stessa data?"
                ))
        }
        .alert(
            String(localized: "Cambiare l'ordine della catena?"),
            isPresented: Binding(get: { laterInChain != nil }, set: { if !$0 { laterInChain = nil } }),
            presenting: laterInChain
        ) { _ in
            Button(String(localized: "Cambia l'ordine")) {
                draft.reorderingChain = true
                // The date check may show another alert: after this one is gone.
                DispatchQueue.main.async { checkDate() }
            }
            Button(String(localized: "Annulla"), role: .cancel) {}
        } message: { title in
            Text(
                String(
                    localized:
                        "«\(title)» oggi viene dopo questa voce nella catena. Se confermi, questa voce passa dopo «\(title)» e il resto della catena resta in ordine."
                ))
        }
        .task {
            guard draft.existingID == nil, draft.text.isEmpty, draft.titleHint != nil, TitleSuggester.isAvailable
            else { return }
            suggesting = true
            let title = await TitleSuggester.suggest(for: draft.notes)
            suggesting = false
            if let title, draft.text.isEmpty {
                draft.text = title
                suggestedTitle = title
            }
        }
        .onAppear {
            var list = model.supersedableDecisions(projectID: draft.projectID, excluding: draft.existingID)
            // Keep the current targets visible even if they are no longer active.
            for target in draft.supersedesIDs.reversed() where !list.contains(where: { $0.id == target }) {
                if let summary = try? model.archive.decisionSummary(target) { list.insert(summary, at: 0) }
            }
            candidates = list
        }
    }

    /// ADR-0052: any number of entries of any kind, as removable chips, plus "Aggiungi…".
    private var supersedeChooser: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(draft.supersedesIDs, id: \.self) { id in
                HStack(spacing: 4) {
                    Image(systemName: candidate(id).map { DecisionRow.icon($0.decision) } ?? "circle")
                        .foregroundStyle(.secondary)
                    Text(candidate(id).map(Self.short) ?? id).lineLimit(1).truncationMode(.tail)
                    Button {
                        draft.supersedesIDs.removeAll { $0 == id }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Non supera più questa voce"))
                }
                .font(.callout)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            Menu(
                draft.supersedesIDs.isEmpty
                    ? String(localized: "Nessuna voce · Aggiungi…") : String(localized: "Aggiungi…")
            ) {
                let available = candidates.filter { !draft.supersedesIDs.contains($0.id) }
                if available.isEmpty {
                    Text(String(localized: "Nessun'altra voce attiva"))
                }
                ForEach(available) { candidate in
                    Button {
                        draft.supersedesIDs.append(candidate.id)
                    } label: {
                        Label(Self.short(candidate), systemImage: DecisionRow.icon(candidate.decision))
                    }
                }
            }
            .menuStyle(.borderlessButton).fixedSize()
            .help(
                String(
                    localized:
                        "Le voci scelte (decisioni, attività o tappe) diventano \"superate\" e restano nell'evoluzione")
            )
        }
    }

    private func candidate(_ id: String) -> DecisionSummary? {
        candidates.first { $0.id == id }
    }

    /// A decision written by hand belongs to a project; one taken from an item or a note follows its source,
    /// which may still be unclassified.
    private var hasSource: Bool { draft.sourceItemID != nil || draft.sourceNoteID != nil }
    private var needsProject: Bool { draft.projectID == nil && !hasSource }

    private var projectHint: String? {
        if needsProject { return String(localized: "Scegli il progetto a cui appartiene la decisione.") }
        if draft.projectID == nil {
            return String(
                localized: "La fonte non ha ancora un progetto: la decisione lo seguirà quando la classifichi.")
        }
        return nil
    }

    static func title(_ draft: DecisionDraft) -> String {
        switch (draft.existingID == nil, draft.kind) {
        case (true, .action): String(localized: "Nuova attività")
        case (true, .milestone): String(localized: "Nuova tappa")
        case (true, _): String(localized: "Nuova decisione")
        case (false, .action): String(localized: "Modifica attività")
        case (false, .milestone): String(localized: "Modifica tappa")
        case (false, _): String(localized: "Modifica decisione")
        }
    }

    static func placeholder(_ kind: Decision.Kind) -> String {
        switch kind {
        case .action: String(localized: "Titolo: cosa c'è da fare")
        case .milestone: String(localized: "Titolo: cosa è successo")
        default: String(localized: "Titolo: cosa è stato deciso")
        }
    }

    static func explanation(_ kind: Decision.Kind) -> String {
        switch kind {
        case .action:
            String(
                localized:
                    "Qualcosa da fare o in corso: resta in timeline finché non la segni fatta, oppure diventa una decisione."
            )
        case .milestone:
            String(localized: "Un fatto importante da ricordare: firma, consegna, kickoff, cambio di referente.")
        default:
            String(localized: "Qualcosa di deciso: vale finché un'altra decisione non la supera.")
        }
    }

    private func save() {
        if let id = draft.existingID, !draft.reorderingChain,
            let target = draft.supersedesIDs.first(where: { (try? model.archive.comesLater($0, than: id)) == true })
        {
            laterInChain = candidate(target).map { Self.clip($0.decision.text) } ?? ""
            return
        }
        checkDate()
    }

    private func checkDate() {
        if let targetDate = draft.supersedesIDs.compactMap({
            (candidate($0) ?? (try? model.archive.decisionSummary($0)))?.decision.decidedAt
        }).max(),
            draft.decidedAt < targetDate
        {
            earlierThanTarget = targetDate
            return
        }
        commit()
    }

    private func commit() {
        if draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let hint = draft.titleHint {
            draft.text = hint
        }
        model.saveDecision(draft)
        dismiss()
    }

    private static func short(_ summary: DecisionSummary) -> String {
        "\(summary.decision.decidedAt.formatted(.dateTime.day().month(.abbreviated))) · \(clip(summary.decision.text))"
    }

    private static func clip(_ text: String) -> String {
        let text = text.replacingOccurrences(of: "\n", with: " ")
        return text.count > 60 ? "\(text.prefix(60))…" : text
    }
}

/// Chips with a text field and suggestions from existing values (people, tags). A new value that looks like
/// an existing one ("Mario" / "Mario Rossi", "Giula" / "Giulia") is added only after the user confirms it is
/// someone else; otherwise the existing spelling is used.
struct TokenField: View {
    @Binding var values: [String]
    let placeholder: String
    let prefix: String
    let suggestions: [String]
    @State private var input = ""
    /// A typed value waiting for confirmation, with the existing values it resembles.
    @State private var pending: (value: String, similar: [String])?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 6) {
                ForEach(values, id: \.self) { value in
                    HStack(spacing: 3) {
                        Text("\(prefix)\(value)")
                        Button {
                            values.removeAll { $0 == value }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                }
                TextField(placeholder, text: $input)
                    .textFieldStyle(.roundedBorder).frame(width: 170)
                    .onSubmit { submit(input) }
                    .onChange(of: input) { _, value in
                        if value.contains(",") { submit(value.replacingOccurrences(of: ",", with: "")) }
                    }
            }
            if let pending {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "«\(pending.value)» somiglia a:")).font(.caption).foregroundStyle(.orange)
                    HStack(spacing: 6) {
                        ForEach(pending.similar, id: \.self) { name in
                            Button(String(localized: "Usa \(prefix)\(name)")) { append(name) }
                                .buttonStyle(.link).font(.caption)
                        }
                        Text("·").foregroundStyle(.secondary)
                        Button(String(localized: "Aggiungi «\(pending.value)» come nuovo")) { append(pending.value) }
                            .buttonStyle(.link).font(.caption)
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.08)))
            } else {
                let matches = matching
                if !matches.isEmpty {
                    HStack(spacing: 6) {
                        Text(String(localized: "Esistenti:")).font(.caption).foregroundStyle(.secondary)
                        ForEach(matches, id: \.self) { name in
                            Button("\(prefix)\(name)") { append(name) }.buttonStyle(.link).font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var available: [String] {
        let taken = Set(values.map(TagNormalizer.normalize))
        return suggestions.filter { !taken.contains(TagNormalizer.normalize($0)) }
    }

    /// While typing: names containing the text, then names that look alike (typos, first name only).
    private var matching: [String] {
        let query = TagNormalizer.normalize(input)
        guard !query.isEmpty else { return [] }
        let containing = available.filter { TagNormalizer.normalize($0).contains(query) }
        let alike = available.filter { !containing.contains($0) && ProjectNameMatcher.isSimilar(input, $0) }
        return Array((containing + alike).prefix(6))
    }

    private func submit(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            input = ""
            return
        }
        let normalized = TagNormalizer.normalize(trimmed)
        if let existing = suggestions.first(where: { TagNormalizer.normalize($0) == normalized }) {
            append(existing)
            return
        }
        let similar = available.filter { ProjectNameMatcher.isSimilar(trimmed, $0) }
        if similar.isEmpty {
            append(trimmed)
        } else {
            pending = (trimmed, Array(similar.prefix(4)))
            input = ""
        }
    }

    private func append(_ value: String) {
        input = ""
        pending = nil
        let normalized = TagNormalizer.normalize(value)
        if !values.contains(where: { TagNormalizer.normalize($0) == normalized }) { values.append(value) }
    }
}

/// The name the user gave to a chain of decisions, shown on every decision of the chain.
struct ChainNameBadge: View {
    let name: String

    var body: some View {
        Label("«\(name)»", systemImage: "arrow.triangle.branch")
            .font(.caption.weight(.semibold)).foregroundStyle(.green)
            .lineLimit(1)
            .help(String(localized: "Catena di decisioni: \(name)"))
    }
}

/// "Promuovi a decisione" on a note, or, once promoted, a mark that opens the decision: the note stays where it
/// is so it does not vanish from the notes.
struct PromoteNoteButton: View {
    static func became(_ kind: Decision.Kind) -> String {
        switch kind {
        case .action: String(localized: "Diventata attività")
        case .milestone: String(localized: "Diventata tappa")
        default: String(localized: "Diventata decisione")
        }
    }

    let model: AppModel
    let note: Note
    var item: Item?

    var body: some View {
        if let decisionID = model.promotedDecision(ofNote: note.id) {
            let kind = model.decisionKind(decisionID)
            Button {
                model.selectedDecisionID = decisionID
            } label: {
                Label(PromoteNoteButton.became(kind), systemImage: DecisionRow.kindIcon(kind))
            }
            .buttonStyle(.link).foregroundStyle(DecisionRow.tint(model.decisionKind(decisionID)))
            .help(String(localized: "Apri il punto chiave nato da questa nota"))
        } else {
            Menu(String(localized: "Promuovi a…")) {
                ForEach([Decision.Kind.decision, .action, .milestone], id: \.self) { kind in
                    Button(DecisionRow.kindLabel(kind)) {
                        model.editingDecision = DecisionDraft(
                            note: note, item: item ?? model.item(note.itemId ?? ""), kind: kind)
                    }
                }
            }
            .menuStyle(.borderlessButton).fixedSize()
        }
    }
}

/// "Da confermare" (ADR-0049): decisions and activities proposed by the engine in this scope, before the register.
struct PendingKeyPoints: View {
    let model: AppModel
    @State private var pending: [Suggestion] = []
    @AppStorage("pendingKeyPointsCollapsed") private var collapsed = false

    var body: some View {
        Group {
            if !pending.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        collapsed.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: collapsed ? "chevron.right" : "chevron.down").font(.caption)
                            Label(
                                String(localized: "Da confermare (\(pending.count))"), systemImage: "cpu"
                            )
                            .font(.title3.bold()).foregroundStyle(.indigo)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if !collapsed {
                        Text(
                            String(
                                localized:
                                    "Proposte dal motore locale a partire dalle call, dalle email e dai documenti. Diventano punti chiave solo se le confermi."
                            )
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        ForEach(pending) { suggestion in
                            if let item = model.item(suggestion.itemId) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Button(item.title) { model.selectedItemID = item.id }
                                        .buttonStyle(.link).font(.caption)
                                    SuggestionRow(model: model, item: item, suggestion: suggestion)
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.indigo.opacity(0.06)))
                            }
                        }
                    }
                }
                .padding(.top, 14)
            }
        }
        .task(id: "\(model.revision)-\(model.intelligence.revision)") {
            pending = (model.decisionScope.flatMap { try? model.archive.pendingKeyPointSuggestions($0) }) ?? []
        }
    }
}
