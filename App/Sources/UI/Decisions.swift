import IAGOExport
import IAGOIntelligence
import IAGOStore
import SwiftUI

/// What the decision editor works on: a new decision (from a bookmark, a selection, a note or by hand) or an
/// existing one (FR-152).
struct DecisionDraft: Identifiable {
    let id = UUID()
    var existingID: String?
    /// Decision, milestone, activity, point to clear up, risk or request (ADR-0046, ADR-0074).
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
    // Open work (ADR-0074). People by name: they become person entities when saved.
    var ownerName: String?
    var dueAt: Date?
    var waitingOnName: String?
    var waitingUntil: Date?
    /// 1 high, 2 medium, 3 low.
    var priority: Int?
    var severity: Decision.Severity?
    var status = Decision.Status.active
    var startsAt: Date?
    var estimate: String?
    var recurrence: Decision.Recurrence?
    var outcome: String?
    var outcomeKind: Decision.Outcome?
    var derivedFromID: String?
    /// "Dipende da": open entries this one waits for.
    var blockerIDs: [String] = []
    var checklist: [ChecklistLine] = []
    /// The state and dependencies as loaded: saving writes them only when the user changed them, so a state set
    /// by the dependencies ("Bloccata") or hidden by "Traccia" is never overwritten by chance.
    var loadedStatus: Decision.Status?
    var loadedBlockerIDs: [String] = []
    /// An existing entry's checklist is read when the editor opens; until then saving leaves it alone.
    var checklistLoaded = false
    /// «Trasforma in…» (ADR-0074): the request this new entry replaces, closed as converted once it is saved.
    var convertsID: String?

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
        ownerName = summary.ownerName
        dueAt = decision.dueAt
        waitingOnName = summary.waitingOnName
        waitingUntil = decision.waitingUntil
        priority = decision.priority
        severity = decision.severity
        status = decision.status
        loadedStatus = decision.status
        startsAt = decision.startsAt
        estimate = decision.estimate
        recurrence = decision.recurrence
        outcome = decision.outcome
        outcomeKind = decision.outcomeKind
        derivedFromID = decision.derivedFromId
        blockerIDs = summary.blockers.map(\.id)
        loadedBlockerIDs = blockerIDs
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

    /// "Nuova attività da questo": an activity born from `summary`, in its project and streams (ADR-0074).
    static func derived(from summary: DecisionSummary, kind: Decision.Kind = .action) -> DecisionDraft {
        var draft = DecisionDraft(projectID: summary.decision.projectId, kind: kind)
        draft.derivedFromID = summary.id
        draft.streamIDs = summary.streamIDs
        draft.tags = summary.tags
        return draft
    }

    /// «Trasforma in…»: the request becomes an entry of another kind, born from it; the request is closed as
    /// converted when this one is saved.
    static func converting(_ summary: DecisionSummary, to kind: Decision.Kind) -> DecisionDraft {
        var draft = derived(from: summary, kind: kind)
        draft.text = summary.decision.text
        draft.notes = summary.decision.notes ?? ""
        draft.people = summary.people
        draft.ownerName = summary.ownerName
        draft.dueAt = summary.decision.dueAt
        draft.convertsID = summary.id
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

    /// The entry to write. Owner and who it waits for are resolved to people when saving (`AppModel.saveDecision`).
    var decision: Decision {
        var decision = Decision(
            text: text, decidedAt: decidedAt, projectId: projectID, sourceItemId: sourceItemID,
            sourceAtSec: sourceAtSec, sourceNoteId: sourceNoteID, origin: origin,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes, kind: kind)
        let work = kind.isWork
        decision.status = status
        decision.dueAt = work ? dueAt : nil
        decision.waitingUntil = work ? waitingUntil : nil
        decision.priority = work ? priority : nil
        decision.severity = kind == .risk ? severity : nil
        decision.startsAt = work ? startsAt : nil
        let estimate = estimate?.trimmingCharacters(in: .whitespacesAndNewlines)
        decision.estimate = work && estimate?.isEmpty == false ? estimate : nil
        decision.recurrence = work ? recurrence : nil
        decision.outcome = outcome
        decision.outcomeKind = outcomeKind
        decision.derivedFromId = derivedFromID
        return decision
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
                Image(systemName: DecisionRow.icon(summary))
                    .font(.system(size: 15))
                    .foregroundStyle(DecisionRow.color(summary))
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
                        decision.status.isOpen
                            ? DecisionRow.tint(decision.kind).opacity(0.07) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10).stroke(
                        decision.status.isOpen
                            ? DecisionRow.tint(decision.kind).opacity(0.35) : Color.secondary.opacity(0.2)))
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
                        + DecisionRow.allKinds.map { (Optional($0), DecisionRow.kindPlural($0)) },
                    selection: Binding(
                        get: { model.decisionQuery.kinds.first },
                        set: { model.decisionQuery.kinds = $0.map { [$0] } ?? [] }))
            }
            FilterChip(title: statusTitle, systemImage: "line.3.horizontal.decrease", active: !onlyActive) {
                VStack(alignment: .leading, spacing: 2) {
                    OptionCheckRow(label: String(localized: "Attivi"), checked: onlyActive) {
                        model.decisionQuery.statuses = DecisionQuery.current
                    }
                    Divider()
                    ForEach(statusGroups.indices, id: \.self) { index in
                        let group = statusGroups[index]
                        OptionCheckRow(
                            label: group.label, checked: group.statuses.isSubset(of: model.decisionQuery.statuses)
                        ) {
                            if group.statuses.isSubset(of: model.decisionQuery.statuses) {
                                let rest = model.decisionQuery.statuses.subtracting(group.statuses)
                                if !rest.isEmpty { model.decisionQuery.statuses = rest }
                            } else {
                                model.decisionQuery.statuses.formUnion(group.statuses)
                            }
                        }
                    }
                }
            }
            FilterChip(title: ownerTitle, systemImage: "person.crop.circle", active: model.decisionQuery.ownerID != nil)
            {
                if model.people.isEmpty {
                    Text(String(localized: "Nessuna persona")).foregroundStyle(.secondary)
                } else {
                    OptionList(
                        options: [(String?.none, String(localized: "Tutti"))]
                            + model.people.map { (Optional($0.id), $0.name) },
                        selection: $model.decisionQuery.ownerID)
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

    /// "Attivi" (ADR-0074): valid decisions and milestones, and work still open.
    private var onlyActive: Bool { model.decisionQuery.statuses == DecisionQuery.current }

    private var kindTitle: String {
        model.decisionQuery.kinds.first.map(DecisionRow.kindPlural) ?? String(localized: "Tutti i tipi")
    }

    /// The states of the filter as the mode shows them: in "Traccia" under way and blocked are "Aperte".
    private var statusGroups: [(label: String, statuses: Set<Decision.Status>)] {
        typealias Group = (label: String, statuses: Set<Decision.Status>)
        let track = model.workMode(for: model.scopeProjectID) == .track
        var groups: [Group] = []
        if track {
            groups.append((String(localized: "Attive / aperte"), [.active, .inProgress, .blocked]))
        } else {
            groups.append((String(localized: "Attive / da fare"), [.active]))
            groups.append((String(localized: "In corso"), [.inProgress]))
        }
        groups.append((String(localized: "In attesa"), [.waiting]))
        if !track { groups.append((String(localized: "Bloccate"), [.blocked])) }
        groups.append((String(localized: "Fatte / chiuse con esito"), [.done]))
        groups.append((String(localized: "Superate"), [.superseded]))
        groups.append((String(localized: "Annullate"), [.cancelled]))
        return groups
    }

    private var statusTitle: String {
        let statuses = model.decisionQuery.statuses
        if onlyActive { return String(localized: "Attivi") }
        if statuses == Set(Decision.Status.allCases) { return String(localized: "Tutti gli stati") }
        return statusGroups.filter { $0.statuses.isSubset(of: statuses) }.map(\.label).joined(separator: ", ")
    }

    private var ownerTitle: String {
        model.people.first { $0.id == model.decisionQuery.ownerID }.map {
            String(localized: "Responsabile: \($0.name)")
        } ?? String(localized: "Responsabile")
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
                Image(systemName: Self.icon(summary))
                    .foregroundStyle(Self.color(summary)).font(.title3)
                    .help("\(Self.kindLabel(decision.kind)) · \(Self.label(summary, mode: mode))")
            }
            VStack(alignment: .leading, spacing: 5) {
                if showsProject { projectBadge }
                if let name = summary.chainName { ChainNameBadge(name: name) }
                // Done work is a good end: grey, not struck (ADR-0074).
                Text(decision.text)
                    .font(.headline)
                    .strikethrough(Self.look(decision, closedBy: closedBy) == .struck, color: .secondary)
                    .foregroundStyle(decision.status.isOpen ? .primary : .secondary)
                    .lineLimit(compact ? 2 : 3)
                if let description = decision.notes, !description.isEmpty { descriptionView(description) }
                metaLine
                KeyPointWorkLine(model: model, summary: summary)
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
        .confirmationDialog(
            String(localized: "Eliminare «\(Self.clip(decision.text, 60))»?"), isPresented: $deleting
        ) {
            Button(String(localized: "Elimina"), role: .destructive) { model.deleteDecision(decision.id) }
        } message: {
            Text(
                String(
                    localized:
                        "Non si può annullare. Se superava un'altra voce, quella torna attiva. Per tenerne traccia usa \"Annulla\"."
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
        if decision.status != .active || decision.kind.isWork { parts.append(Self.label(summary, mode: mode)) }
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
                    if summary.supersededBy != nil {
                        Text(Self.linkLine(closedByPrefix, summary.supersededByAll)).lineLimit(1)
                    } else if summary.supersedes != nil {
                        Text(Self.linkLine(supersedesPrefix, summary.supersedesAll)).lineLimit(1)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            if showsChain {
                VStack(alignment: .leading, spacing: 3) {
                    if summary.supersededBy != nil, !summary.supersedesAll.isEmpty {
                        Text(Self.linkLine(supersedesPrefix, summary.supersedesAll))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if summary.supersededByAll.count > 1 || (summary.supersededBy != nil && summary.supersedes != nil) {
                        Text(Self.linkLine(closedByPrefix, summary.supersededByAll))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(chain.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(index + 1).").monospacedDigit()
                            Text(step.decidedAt.formatted(.dateTime.day().month(.abbreviated).year()))
                                .foregroundStyle(.secondary)
                            Text(step.text).fontWeight(step.id == summary.id ? .semibold : .regular)
                                .foregroundStyle(step.status.isOpen ? .primary : .secondary)
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
        Button(String(localized: "Modifica…")) { model.editingDecision = DecisionDraft(summary) }
        KeyPointActions(model: model, summary: summary)
        Divider()
        Button(String(localized: "Elimina…"), role: .destructive) { deleting = true }
    }

    private var mode: WorkMode { model.workMode(for: summary.decision.projectId) }
    private var closedBy: Decision.Kind? { summary.supersededBy?.kind }

    /// "Sostituisce", "Risponde a", "Accoglie", "Completa", "Supera": the verb of the most recent closed entry.
    private var supersedesPrefix: String {
        guard let older = summary.supersedesAll.first else { return String(localized: "Supera") }
        return Self.verb(newer: summary.decision.kind, older: older.kind).capitalizedFirst
    }

    private var closedByPrefix: String {
        guard let newer = summary.supersededBy else { return String(localized: "Superata da") }
        return Self.closedByLabel(older: summary.decision.kind, by: newer.kind)
    }

    /// "Supera: A" or "Supera: A e altre 2" (ADR-0052).
    static func linkLine(_ prefix: String, _ entries: [Decision]) -> String {
        guard let first = entries.first else { return prefix }
        return entries.count == 1
            ? "\(prefix): \(first.text)"
            : String(localized: "\(prefix): \(first.text) e altre \(entries.count - 1)")
    }
}

/// "+ Nuovo…": any of the six kinds (ADR-0046, ADR-0074).
struct NewKeyPointMenu: View {
    let model: AppModel
    var projectID: String?
    var title = String(localized: "Aggiungi")

    var body: some View {
        Menu {
            ForEach(DecisionRow.allKinds, id: \.self) { kind in
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
    /// Open entries this one can depend on ("Dipende da").
    @State private var blockerCandidates: [DecisionSummary] = []
    @State private var showsDetails = false
    /// Set when the chosen dependencies would make a circle: the message to show, nothing is saved.
    @State private var cycleError: String?
    @State private var derivedFrom: Decision?
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, draft: DecisionDraft) {
        self.model = model
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label(
                    Self.title(draft), systemImage: DecisionRow.kindIcon(draft.kind)
                )
                .font(.title2).bold()
                .foregroundStyle(DecisionRow.tint(draft.kind))
                if mode == .track, draft.kind.isWork, hasManageDetails {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
                        .help(
                            String(
                                localized:
                                    "Ha dettagli della Modalità Gestisci (priorità, dipendenze, gravità, stima, inizio, ricorrenza o «in corso»): restano salvati."
                            ))
                }
            }
            Picker("", selection: $draft.kind) {
                ForEach(DecisionRow.allKinds, id: \.self) { kind in
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
            if draft.kind.isWork { workFields }
            if draft.kind.isWork, mode == .manage {
                DisclosureGroup(String(localized: "Altri dettagli"), isExpanded: $showsDetails) {
                    manageFields.padding(.top, 6)
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
        .frame(width: 640)
        .onChange(of: draft.projectID) { _, projectID in
            let valid = Set(model.streams(of: projectID).map(\.id))
            draft.streamIDs.removeAll { !valid.contains($0) }
        }
        // Waiting for someone is a state: naming the person sets it, removing the person ends it.
        .onChange(of: draft.waitingOnName) { before, after in
            if before == nil, after != nil, draft.status == .active || draft.status == .inProgress {
                draft.status = .waiting
            } else if after == nil, draft.status == .waiting {
                draft.status = .active
            }
        }
        .onChange(of: draft.kind) { _, kind in
            // Memory has no work states.
            if !kind.isWork, draft.status != .superseded, draft.status != .cancelled { draft.status = .active }
        }
        .alert(
            String(localized: "Dipendenza circolare"),
            isPresented: Binding(get: { cycleError != nil }, set: { if !$0 { cycleError = nil } })
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(cycleError ?? "")
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
            blockerCandidates = model.dependableEntries(projectID: draft.projectID, excluding: draft.existingID)
            for target in draft.blockerIDs.reversed() where !blockerCandidates.contains(where: { $0.id == target }) {
                if let summary = try? model.archive.decisionSummary(target) {
                    blockerCandidates.insert(summary, at: 0)
                }
            }
            if let id = draft.existingID, !draft.checklistLoaded {
                draft.checklist = ((try? model.archive.checklistItems(decisionID: id)) ?? []).map {
                    ChecklistLine(itemID: $0.id, text: $0.text, done: $0.done)
                }
                draft.checklistLoaded = true
            }
            if let id = draft.derivedFromID { derivedFrom = try? model.archive.decision(id) }
            showsDetails = hasManageDetails
        }
    }

    /// The mode of the entry's project (ADR-0074).
    private var mode: WorkMode { model.workMode(for: draft.projectID) }

    private var hasManageDetails: Bool {
        draft.priority != nil || !draft.blockerIDs.isEmpty || !(draft.estimate ?? "").isEmpty
            || draft.startsAt != nil || draft.recurrence != nil || draft.status == .inProgress
            || draft.severity != nil || draft.derivedFromID != nil
    }

    /// Owner, due date, waiting for, checklist: in both modes. Severity and «nata da» only in «Gestisci» (ADR-0076).
    private var workFields: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text(String(localized: "Stato")).foregroundStyle(.secondary).fixedSize()
                statusPicker
            }
            GridRow(alignment: .top) {
                Text(String(localized: "Responsabile")).foregroundStyle(.secondary).fixedSize()
                PersonField(model: model, name: $draft.ownerName, placeholder: String(localized: "Chi se ne occupa"))
            }
            GridRow {
                Text(String(localized: "Scadenza")).foregroundStyle(.secondary).fixedSize()
                OptionalDateField(
                    date: $draft.dueAt, late: draft.status.isOpen && (draft.dueAt.map(isPast) ?? false))
            }
            GridRow(alignment: .top) {
                Text(String(localized: "In attesa di")).foregroundStyle(.secondary).fixedSize()
                HStack(alignment: .top, spacing: 8) {
                    PersonField(model: model, name: $draft.waitingOnName, placeholder: String(localized: "Persona"))
                    if draft.waitingOnName != nil {
                        Text(String(localized: "entro")).foregroundStyle(.secondary).padding(.top, 3)
                        OptionalDateField(date: $draft.waitingUntil)
                    }
                }
            }
            if draft.kind == .risk, mode == .manage {
                GridRow {
                    Text(String(localized: "Gravità")).foregroundStyle(.secondary).fixedSize()
                    Picker("", selection: $draft.severity) {
                        Text(String(localized: "—")).tag(Decision.Severity?.none)
                        ForEach(Decision.Severity.allCases, id: \.self) {
                            Text(DecisionRow.severityLabel($0)).tag(Optional($0))
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
            }
            GridRow(alignment: .top) {
                Text(String(localized: "Checklist")).foregroundStyle(.secondary).fixedSize()
                ChecklistEditor(lines: $draft.checklist)
            }
            if let derivedFrom, mode == .manage {
                GridRow {
                    Text(String(localized: "Nata da")).foregroundStyle(.secondary).fixedSize()
                    HStack(spacing: 4) {
                        Image(systemName: DecisionRow.icon(derivedFrom)).foregroundStyle(.secondary)
                        Text(DecisionRow.clip(derivedFrom.text, 60)).lineLimit(1)
                        Button {
                            draft.derivedFromID = nil
                            self.derivedFrom = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "Non ricordare più da dove nasce"))
                    }
                    .font(.callout)
                }
            }
        }
    }

    /// "Traccia" (ADR-0076): one box, done or not; waiting follows «In attesa di». "Gestisci": all six states. A new
    /// entry starts open.
    @ViewBuilder
    private var statusPicker: some View {
        if mode == .track { doneBox } else { fullStatusPicker }
    }

    /// The box of «Traccia»: «Fatta» for an activity, the outcome of the others («Chiarito», «Accolta», «Risolto»).
    /// An entry closed by another one or cancelled says so and keeps its state.
    @ViewBuilder
    private var doneBox: some View {
        if draft.status == .superseded || draft.status == .cancelled {
            Text(DecisionRow.statusName(draft.status, mode: mode)).foregroundStyle(.secondary)
        } else {
            Toggle(
                Self.doneTitle(draft.kind),
                isOn: Binding(
                    get: { draft.status == .done },
                    set: { done in
                        draft.status = done ? .done : (draft.waitingOnName != nil ? .waiting : .active)
                    })
            )
            .toggleStyle(.checkbox)
        }
    }

    static func doneTitle(_ kind: Decision.Kind) -> String {
        switch kind {
        case .openQuestion: String(localized: "Chiarito")
        case .request: String(localized: "Accolta")
        case .risk: String(localized: "Risolto")
        default: String(localized: "Fatta")
        }
    }

    private var fullStatusPicker: some View {
        let statuses = DecisionRow.workStatuses(mode).filter { draft.existingID != nil || $0.isOpen }
        let binding = Binding<Decision.Status>(
            get: { mode == .track ? DecisionRow.trackStatus(draft.status) : draft.status },
            set: { status in
                let shown = mode == .track ? DecisionRow.trackStatus(draft.status) : draft.status
                if status != shown { draft.status = status }
            })
        return HStack(spacing: 8) {
            Picker("", selection: binding) {
                ForEach(statuses, id: \.self) { Text(DecisionRow.statusName($0, mode: mode)).tag($0) }
                // A state the picker does not offer (closed by another entry): shown, not choosable.
                if !statuses.contains(binding.wrappedValue) {
                    Text(DecisionRow.statusName(binding.wrappedValue, mode: mode)).tag(binding.wrappedValue)
                }
            }
            .labelsHidden().fixedSize()
        }
    }

    /// "Altri dettagli", only in "Gestisci": priority, dependencies, estimate, start, recurrence.
    private var manageFields: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text(String(localized: "Priorità")).foregroundStyle(.secondary).fixedSize()
                Picker("", selection: $draft.priority) {
                    Text(String(localized: "—")).tag(Int?.none)
                    ForEach([1, 2, 3], id: \.self) { Text(DecisionRow.priorityLabel($0)).tag(Optional($0)) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            }
            GridRow(alignment: .top) {
                Text(String(localized: "Dipende da")).foregroundStyle(.secondary).fixedSize()
                dependencyChooser
            }
            GridRow {
                Text(String(localized: "Stima")).foregroundStyle(.secondary).fixedSize()
                TextField(
                    String(localized: "Es. 3 giorni"),
                    text: Binding(get: { draft.estimate ?? "" }, set: { draft.estimate = $0.isEmpty ? nil : $0 })
                )
                .textFieldStyle(.roundedBorder).frame(width: 160)
            }
            GridRow {
                Text(String(localized: "Inizio")).foregroundStyle(.secondary).fixedSize()
                OptionalDateField(date: $draft.startsAt)
            }
            GridRow {
                Text(String(localized: "Ricorrenza")).foregroundStyle(.secondary).fixedSize()
                Picker("", selection: $draft.recurrence) {
                    Text(String(localized: "Nessuna")).tag(Decision.Recurrence?.none)
                    ForEach(Decision.Recurrence.allCases, id: \.self) {
                        Text(DecisionRow.recurrenceLabel($0)).tag(Optional($0))
                    }
                }
                .labelsHidden().fixedSize()
                .help(String(localized: "Quando la segni fatta, IAGO crea la successiva con la scadenza spostata"))
            }
        }
    }

    /// "Dipende da": open entries, as removable chips plus "Aggiungi…" (like «Supera»).
    private var dependencyChooser: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(draft.blockerIDs, id: \.self) { id in
                let blocker = blockerCandidates.first { $0.id == id }
                HStack(spacing: 4) {
                    Image(systemName: blocker.map { DecisionRow.icon($0) } ?? "circle").foregroundStyle(.secondary)
                    Text(blocker.map(Self.short) ?? id).lineLimit(1).truncationMode(.tail)
                    Button {
                        draft.blockerIDs.removeAll { $0 == id }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Non dipende più da questa voce"))
                }
                .font(.callout)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            Menu(
                draft.blockerIDs.isEmpty
                    ? String(localized: "Nessuna voce · Aggiungi…") : String(localized: "Aggiungi…")
            ) {
                let available = blockerCandidates.filter {
                    !draft.blockerIDs.contains($0.id) && $0.decision.status.isOpen
                }
                if available.isEmpty { Text(String(localized: "Nessun'altra voce aperta")) }
                ForEach(available) { candidate in
                    Button {
                        draft.blockerIDs.append(candidate.id)
                    } label: {
                        Label(Self.short(candidate), systemImage: DecisionRow.icon(candidate))
                    }
                }
            }
            .menuStyle(.borderlessButton).fixedSize()
            .help(String(localized: "Finché una di queste voci è aperta, questa resta «bloccata»"))
        }
    }

    private func isPast(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
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
        case (true, .openQuestion): String(localized: "Nuovo punto da chiarire")
        case (true, .risk): String(localized: "Nuovo rischio")
        case (true, .request): String(localized: "Nuova richiesta")
        case (true, .decision): String(localized: "Nuova decisione")
        case (false, .action): String(localized: "Modifica attività")
        case (false, .milestone): String(localized: "Modifica tappa")
        case (false, .openQuestion): String(localized: "Modifica punto da chiarire")
        case (false, .risk): String(localized: "Modifica rischio")
        case (false, .request): String(localized: "Modifica richiesta")
        case (false, .decision): String(localized: "Modifica decisione")
        }
    }

    static func placeholder(_ kind: Decision.Kind) -> String {
        switch kind {
        case .action: String(localized: "Titolo: cosa c'è da fare")
        case .milestone: String(localized: "Titolo: cosa è successo")
        case .openQuestion: String(localized: "Titolo: la domanda che aspetta risposta")
        case .risk: String(localized: "Titolo: cosa può andare storto")
        case .request: String(localized: "Titolo: cosa chiede il cliente")
        case .decision: String(localized: "Titolo: cosa è stato deciso")
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
        case .openQuestion:
            String(
                localized:
                    "Una domanda che aspetta risposta: resta aperta finché non la chiarisci, anche con una decisione.")
        case .risk:
            String(
                localized:
                    "Cosa può andare storto, con la sua gravità: se accade diventa un problema, poi si chiude come risolto o non più rilevante."
            )
        case .request:
            String(
                localized:
                    "Cosa chiede il cliente: si accoglie (anche con le attività che ne nascono), si rifiuta o si trasforma."
            )
        case .decision:
            String(localized: "Qualcosa di deciso: vale finché un'altra decisione non la supera.")
        }
    }

    private func save() {
        if draft.kind.isWork, let id = draft.existingID,
            let blocker = draft.blockerIDs.first(where: { model.dependsOn($0, id) })
        {
            let title = blockerCandidates.first { $0.id == blocker }.map { Self.clip($0.decision.text) } ?? ""
            cycleError = String(
                localized:
                    "«\(title)» dipende già da questa voce, direttamente o tramite altre: non può anche bloccarla. Togli «\(title)» da «Dipende da»."
            )
            return
        }
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
        case .openQuestion: String(localized: "Diventata punto da chiarire")
        case .risk: String(localized: "Diventata rischio")
        case .request: String(localized: "Diventata richiesta")
        case .decision: String(localized: "Diventata decisione")
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
                ForEach(DecisionRow.allKinds, id: \.self) { kind in
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
