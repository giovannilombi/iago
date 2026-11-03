import IAGOStore
import SwiftUI

/// «Inbox» (ADR-0074, ADR-0076): the open work of every project in one place, whatever the project's mode, in three
/// blocks. «Da fare ora» (the red count): my entries late or due today, the ones without an owner, the waits past
/// their date. «Proposte da confermare» (the yellow count): the engine's proposals, each one here to confirm or
/// dismiss. «Più avanti», counted by neither: the next days, the waits not yet due, the pinned checklists. In
/// «Traccia» the minimal inbox; in «Gestisci» also priority ordering and a person filter. Projects kept in «Traccia»
/// are here too: entries assigned to me always are.
struct WorkInbox: View {
    @Bindable var model: AppModel
    @State private var open: [DecisionSummary] = []
    @State private var closed: [DecisionSummary] = []
    @State private var proposals: [ProposalGroup] = []
    @State private var checklists: [Checklist] = []
    /// The user as a person («Il tuo nome», «Io»), read once per reload.
    @State private var me: Set<String> = []
    @State private var confirmsDismissAll = false
    @AppStorage("inbox.showsClosed") private var showsClosed = false
    @AppStorage("inbox.byPriority") private var byPriority = true
    /// The share of the upper box, moved with the handle between the two (ADR-0087).
    @AppStorage("inbox.split") private var split = 0.5
    /// «Gestisci»: whose entries; nil = mine.
    @State private var person: PersonFilter = .me

    enum PersonFilter: Hashable {
        case me, everyone
        case person(String)
    }

    /// The proposals of one item, in the order of the archive (most recent item first).
    struct ProposalGroup: Identifiable {
        let item: Item
        let suggestions: [Suggestion]
        var id: String { item.id }
    }

    private var mode: WorkMode { model.workViewsMode }
    private var filter: PersonFilter { mode == .manage ? person : .me }

    var body: some View {
        // A stack, not a group: an empty group would drop `.task` and nothing would ever load.
        VStack(spacing: 0) {
            if !isEmpty {
                InboxSplit(ratio: $split, topCollapsed: actionIsEmpty, bottomCollapsed: proposalCount == 0) {
                    InboxBox(ids: actionIDs, isEmpty: actionIsEmpty) {
                        InboxBlockHeader(
                            title: String(localized: "Da fare ora"), systemImage: InboxCount.action.systemImage,
                            count: actionCount, kind: .action, inset: 14)
                    } content: {
                        actionBox
                    }
                } bottom: {
                    InboxBox(ids: proposalIDs, isEmpty: proposalCount == 0) {
                        proposalHeader
                    } content: {
                        proposalBlock
                    }
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
        .frame(maxWidth: 900, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) { header.iagoBar() }
        .overlay {
            if isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Niente da fare"), systemImage: "checkmark.circle")
                } description: {
                    Text(
                        String(
                            localized:
                                "Qui arrivano le attività, i punti da chiarire, i rischi e le richieste aperti di tutti i progetti, assegnati a te o senza responsabile."
                        ))
                }
            }
        }
        .confirmationDialog(
            String(localized: "Scartare tutte le \(proposalCount) proposte?"), isPresented: $confirmsDismissAll
        ) {
            Button(String(localized: "Scarta tutte"), role: .destructive) {
                model.dismiss(proposals.flatMap(\.suggestions))
            }
        } message: {
            Text(String(localized: "Nessuna diventa un punto chiave. Il motore non le propone di nuovo."))
        }
        .task(id: "\(model.revision)-\(model.intelligence.revision)-\(showsClosed)") { load() }
    }

    // MARK: Blocks

    /// The upper box: «Da fare ora», then «Più avanti» and, if asked, the closed ones, in the same scroll.
    private var actionBox: some View {
        Group {
            if actionCount == 0 {
                Text(String(localized: "Niente in ritardo, per oggi o senza responsabile."))
                    .font(.callout).foregroundStyle(.secondary).padding(.leading, 8).padding(.top, 8)
            }
            ForEach(urgentGroups, id: \.due) { group in
                WorkSubsectionTitle(
                    title: group.due.title, count: group.entries.count,
                    color: group.due == .overdue ? .red : .secondary)
                rows(group.entries, showsOwner: filter == .everyone)
            }
            if !unassigned.isEmpty {
                WorkSubsectionTitle(title: String(localized: "Senza responsabile"), count: unassigned.count)
                rows(unassigned, showsOwner: false)
            }
            if !waitingLate.isEmpty {
                WorkSubsectionTitle(title: String(localized: "Attese scadute"), count: waitingLate.count)
                rows(waitingLate, showsOwner: filter != .me)
            }
            if laterCount > 0 { laterBlock }
            if showsClosed {
                WorkSectionTitle(
                    title: String(localized: "Chiuse negli ultimi \(Archive.boardArchiveDays) giorni"),
                    count: closedShown.count, color: .secondary)
                if closedShown.isEmpty {
                    Text(String(localized: "Nessuna voce chiusa di recente.")).font(.callout)
                        .foregroundStyle(.secondary).padding(.leading, 8)
                }
                rows(closedShown, showsOwner: filter != .me)
            }
        }
    }

    private var proposalHeader: some View {
        InboxBlockHeader(
            title: String(localized: "Proposte da confermare"), systemImage: InboxCount.proposals.systemImage,
            count: proposalCount, kind: .proposals, inset: 14
        ) {
            if proposalCount > 0 {
                Button(String(localized: "Scarta tutte…")) { confirmsDismissAll = true }
                    .buttonStyle(.link).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var proposalBlock: some View {
        Group {
            if proposalCount == 0 {
                Text(String(localized: "Nessuna proposta da confermare."))
                    .font(.callout).foregroundStyle(.secondary).padding(.leading, 8).padding(.top, 8)
            } else {
                Text(String(localized: "Un box per elemento: aprilo per vedere e confermare le sue proposte a destra."))
                    .font(.caption).foregroundStyle(.secondary).padding(.leading, 8).padding(.top, 6)
            }
            ForEach(proposals) { group in
                ProposalItemCard(
                    item: group.item, suggestions: group.suggestions,
                    projectName: model.project(group.item.projectId)?.name,
                    selected: model.proposalsItemID == group.id
                ) { model.proposalsItemID = group.id }
                .id(group.id)
            }
        }
    }

    private var laterBlock: some View {
        Group {
            WorkSectionTitle(title: String(localized: "Più avanti"), count: laterCount, color: .secondary)
            ForEach(laterGroups, id: \.due) { group in
                WorkSubsectionTitle(
                    title: group.due == .later ? String(localized: "Dopo questa settimana") : group.due.title,
                    count: group.entries.count)
                rows(group.entries, showsOwner: filter == .everyone)
            }
            if !waiting.isEmpty {
                WorkSubsectionTitle(title: String(localized: "Aspetto da altri"), count: waiting.count)
                rows(waiting, showsOwner: filter != .me)
            }
            if !checklists.isEmpty {
                WorkSubsectionTitle(title: String(localized: "Checklist fissate"), count: checklists.count)
                ForEach(checklists) { list in
                    ChecklistCard(model: model, checklist: list, showsProject: true, editable: false)
                        .padding(.vertical, 3).id(list.id)
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label {
                    Text(String(localized: "Inbox"))
                } icon: {
                    Image(systemName: "tray")
                }
                .font(.headline)
                Spacer(minLength: 8)
                if model.boardAvailable(for: .all) {
                    Picker(String(localized: "Vista"), selection: $model.viewMode) {
                        Label(String(localized: "Elenco"), systemImage: "list.bullet").tag(AppModel.ViewMode.list)
                        Label(String(localized: "Kanban"), systemImage: "rectangle.split.3x1").tag(
                            AppModel.ViewMode.board)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
            }
            FlowLayout(spacing: 6, lineSpacing: 8) {
                if mode == .manage {
                    FilterChip(title: personTitle, systemImage: "person", active: person != .me) {
                        OptionList(
                            options: [
                                (PersonFilter.me, String(localized: "Le mie")),
                                (.everyone, String(localized: "Di tutti")),
                            ] + model.people.filter { !me.contains($0.id) }.map { (.person($0.id), $0.name) },
                            selection: $person)
                    }
                    ChipButton(
                        title: String(localized: "Per priorità"), systemImage: "arrow.up.arrow.down",
                        active: byPriority, showsChevron: false
                    ) { byPriority.toggle() }
                }
                ChipButton(
                    title: String(localized: "Mostra chiuse"), systemImage: "checkmark.circle", active: showsClosed,
                    showsChevron: false
                ) { showsClosed.toggle() }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private var personTitle: String {
        switch person {
        case .me: String(localized: "Le mie")
        case .everyone: String(localized: "Di tutti")
        case .person(let id): model.people.first { $0.id == id }?.name ?? String(localized: "Persona")
        }
    }

    private func rows(_ entries: [DecisionSummary], showsOwner: Bool) -> some View {
        ForEach(entries) { summary in
            WorkEntryRow(model: model, summary: summary, mode: mode, showsOwner: showsOwner).id(summary.id)
        }
    }

    // MARK: Groups

    /// Whose entries the dated groups show.
    private func matches(_ decision: Decision) -> Bool {
        switch filter {
        case .me: decision.ownerId.map(me.contains) ?? false
        case .everyone: true
        case .person(let id): decision.ownerId == id
        }
    }

    private func dueGroups(_ dues: [OpenWork.Due]) -> [(due: OpenWork.Due, entries: [DecisionSummary])] {
        let mine = open.filter { $0.decision.status != .waiting && matches($0.decision) }
        return dues.compactMap { due in
            let entries = sorted(mine.filter { OpenWork.due($0.decision.dueAt) == due })
            return entries.isEmpty ? nil : (due, entries)
        }
    }

    /// «Da fare ora»: late and due today.
    private var urgentGroups: [(due: OpenWork.Due, entries: [DecisionSummary])] { dueGroups([.overdue, .today]) }

    /// «Più avanti»: this week, later, without a date.
    private var laterGroups: [(due: OpenWork.Due, entries: [DecisionSummary])] {
        dueGroups([.thisWeek, .later, .none])
    }

    /// With «Le mie», the entries nobody owns yet, apart: they ask to be assigned, so they are in «Da fare ora».
    private var unassigned: [DecisionSummary] {
        guard filter == .me else { return [] }
        return sorted(open.filter { $0.decision.status != .waiting && $0.decision.ownerId == nil })
    }

    /// Waiting for someone else: my entries and those without an owner, the most late first.
    private var allWaiting: [DecisionSummary] {
        open.filter { summary in
            summary.decision.status == .waiting
                && (filter == .me ? OpenWork.isMine(summary.decision, me: me) : matches(summary.decision))
        }
        .sorted { ($0.decision.waitingUntil ?? .distantFuture) < ($1.decision.waitingUntil ?? .distantFuture) }
    }

    private func isLate(_ summary: DecisionSummary) -> Bool {
        summary.decision.waitingUntil.map { $0 < Calendar.current.startOfDay(for: Date()) } ?? false
    }

    /// Waits past the promised day: time to ask again.
    private var waitingLate: [DecisionSummary] { allWaiting.filter(isLate) }
    private var waiting: [DecisionSummary] { allWaiting.filter { !isLate($0) } }

    private var closedShown: [DecisionSummary] {
        closed.filter {
            filter == .me ? OpenWork.isMine($0.decision, me: me) : matches($0.decision)
        }
    }

    private func sorted(_ entries: [DecisionSummary]) -> [DecisionSummary] {
        OpenWork.sorted(entries, byPriority: mode == .manage && byPriority)
    }

    private var actionCount: Int {
        urgentGroups.reduce(0) { $0 + $1.entries.count } + unassigned.count + waitingLate.count
    }

    private var proposalCount: Int { proposals.reduce(0) { $0 + $1.suggestions.count } }

    private var laterCount: Int {
        laterGroups.reduce(0) { $0 + $1.entries.count } + waiting.count + checklists.count
    }

    /// The upper box has nothing: it shrinks to its header and the proposals take the room.
    private var actionIsEmpty: Bool { actionCount == 0 && laterCount == 0 && !showsClosed }

    /// The rows of each box in their order, for «altre N» (the ones below the last visible).
    private var actionIDs: [String] {
        (urgentGroups.flatMap(\.entries) + unassigned + waitingLate + laterGroups.flatMap(\.entries) + waiting).map(
            \.id)
            + checklists.map(\.id) + (showsClosed ? closedShown.map(\.id) : [])
    }

    private var proposalIDs: [String] { proposals.map(\.id) }

    private var isEmpty: Bool { actionCount == 0 && proposalCount == 0 && laterCount == 0 && !showsClosed }

    private func load() {
        let archive = model.archive
        me = model.meIDs
        open =
            (try? archive.decisions(
                DecisionQuery(scope: .all, statuses: DecisionQuery.current, kinds: Set(Decision.Kind.work)))) ?? []
        if showsClosed {
            let since = Calendar.current.date(byAdding: .day, value: -Archive.boardArchiveDays, to: Date()) ?? Date()
            closed =
                ((try? archive.decisions(
                    DecisionQuery(
                        scope: .all, statuses: [.done, .cancelled, .superseded], kinds: Set(Decision.Kind.work)))) ?? [])
                .filter { ($0.decision.closedAt ?? .distantPast) >= since }
                .sorted { ($0.decision.closedAt ?? .distantPast) > ($1.decision.closedAt ?? .distantPast) }
        } else {
            closed = []
        }
        let pending = (try? archive.pendingKeyPointSuggestions(.all)) ?? []
        var order: [String] = []
        var byItem: [String: [Suggestion]] = [:]
        for suggestion in pending {
            if byItem[suggestion.itemId] == nil { order.append(suggestion.itemId) }
            byItem[suggestion.itemId, default: []].append(suggestion)
        }
        proposals = order.compactMap { id in
            model.item(id).map { ProposalGroup(item: $0, suggestions: byItem[id] ?? []) }
        }
        checklists = (try? archive.checklists(pinnedOnly: true)) ?? []
    }
}

/// A group inside a block of «Inbox» («In ritardo», «Oggi», …).
struct WorkSubsectionTitle: View {
    let title: String
    let count: Int
    var color: Color = .secondary

    var body: some View {
        Text(verbatim: "\(title.uppercased()) · \(count)").font(.caption.weight(.bold)).foregroundStyle(color)
            .padding(.top, 10).padding(.bottom, 2).padding(.leading, 8)
    }
}

/// The «Inbox» row of the sidebar (ADR-0076): first, in bold, with its sign in the accent colour and two counts, red
/// for what asks an action now and yellow for the proposals to confirm. Each is the count of its block in «Inbox».
struct WorkInboxSidebarLabel: View {
    let model: AppModel
    @State private var actions = 0
    @State private var proposals = 0

    var body: some View {
        Label {
            HStack(spacing: 4) {
                Text(String(localized: "Inbox")).fontWeight(.semibold)
                Spacer()
                if actions > 0 { InboxCountBadge(kind: .action, count: actions) }
                if proposals > 0 { InboxCountBadge(kind: .proposals, count: proposals) }
            }
        } icon: {
            Image(systemName: "tray")
        }
        .task(id: "\(model.revision)-\(model.intelligence.revision)") {
            let open =
                (try? model.archive.decisions(
                    DecisionQuery(scope: .all, statuses: DecisionQuery.current, kinds: Set(Decision.Kind.work)))) ?? []
            let me = model.meIDs
            actions = open.filter { OpenWork.needsAction($0.decision, me: me) }.count
            proposals = (try? model.archive.pendingKeyPointSuggestions(.all).count) ?? 0
        }
    }
}
