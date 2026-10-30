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
    /// Items whose proposals are all shown, not only the first ones.
    @State private var expanded: Set<String> = []
    @State private var confirmsDismissAll = false
    @AppStorage("inbox.showsClosed") private var showsClosed = false
    @AppStorage("inbox.byPriority") private var byPriority = true
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

    /// Proposals shown per item before «Mostra le altre».
    private static let proposalsShown = 3

    private var mode: WorkMode { model.workViewsMode }
    private var filter: PersonFilter { mode == .manage ? person : .me }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if actionCount > 0 { actionBlock }
                if proposalCount > 0 { proposalBlock }
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
            .padding(.horizontal, 24).padding(.bottom, 24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) { header.background(.bar) }
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

    private var actionBlock: some View {
        Group {
            InboxBlockHeader(
                title: String(localized: "Da fare ora"), systemImage: InboxCount.action.systemImage,
                count: actionCount, kind: .action)
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
        }
    }

    private var proposalBlock: some View {
        Group {
            InboxBlockHeader(
                title: String(localized: "Proposte da confermare"), systemImage: InboxCount.proposals.systemImage,
                count: proposalCount, kind: .proposals
            ) {
                Button(String(localized: "Scarta tutte…")) { confirmsDismissAll = true }
                    .buttonStyle(.link).font(.callout).foregroundStyle(.secondary)
            }
            Text(String(localized: "Diventano punti chiave solo se le confermi."))
                .font(.caption).foregroundStyle(.secondary).padding(.leading, 8).padding(.top, 4)
            ForEach(proposals) { group in
                HStack {
                    Button(group.item.title) { model.selectedItemID = group.item.id }
                        .buttonStyle(.link).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(group.item.occurredAt.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(group.suggestions.count)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    Spacer()
                    Button(String(localized: "Scarta queste")) { model.dismiss(group.suggestions) }
                        .buttonStyle(.link).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 12).padding(.leading, 8)
                let all = expanded.contains(group.id)
                ForEach(all ? group.suggestions : Array(group.suggestions.prefix(Self.proposalsShown))) {
                    suggestion in
                    SuggestionRow(model: model, item: group.item, suggestion: suggestion)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.06)))
                }
                if !all, group.suggestions.count > Self.proposalsShown {
                    Button(String(localized: "Mostra le altre \(group.suggestions.count - Self.proposalsShown)")) {
                        expanded.insert(group.id)
                    }
                    .buttonStyle(.link).font(.callout).padding(.leading, 8)
                }
            }
        }
    }

    private var laterBlock: some View {
        Group {
            InboxBlockHeader(title: String(localized: "Più avanti"), systemImage: "clock", count: laterCount)
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
                        .padding(.vertical, 3)
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
                    Image(systemName: "tray").foregroundStyle(.tint)
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
            WorkEntryRow(model: model, summary: summary, mode: mode, showsOwner: showsOwner)
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
            Image(systemName: "tray").foregroundStyle(.tint)
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
