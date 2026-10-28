import IAGOStore
import SwiftUI

/// «Da fare» (ADR-0074): the open work of every project in one place. My entries by due date, the ones without an
/// owner, what I am waiting for from others, the engine's proposals to confirm, the pinned checklists. In «Traccia»
/// the minimal inbox; in «Gestisci» also priority ordering and a person filter. Projects kept in «Traccia» are here
/// too: entries assigned to me always are.
struct WorkInbox: View {
    @Bindable var model: AppModel
    @State private var open: [DecisionSummary] = []
    @State private var closed: [DecisionSummary] = []
    @State private var proposals = 0
    @State private var checklists: [Checklist] = []
    /// The user as a person («Il tuo nome», «Io»), read once per reload.
    @State private var me: Set<String> = []
    @AppStorage("inbox.showsClosed") private var showsClosed = false
    @AppStorage("inbox.byPriority") private var byPriority = true
    /// «Gestisci»: whose entries; nil = mine.
    @State private var person: PersonFilter = .me

    enum PersonFilter: Hashable {
        case me, everyone
        case person(String)
    }

    private var mode: WorkMode { model.workViewsMode }
    private var filter: PersonFilter { mode == .manage ? person : .me }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(dueGroups, id: \.due) { group in
                    WorkSectionTitle(
                        title: group.due.title, count: group.entries.count,
                        color: group.due == .overdue ? .red : .primary)
                    rows(group.entries, showsOwner: filter == .everyone)
                }
                if !unassigned.isEmpty {
                    WorkSectionTitle(title: String(localized: "Senza responsabile"), count: unassigned.count)
                    rows(unassigned, showsOwner: false)
                }
                if !waiting.isEmpty {
                    WorkSectionTitle(title: String(localized: "Aspetto da altri"), count: waiting.count)
                    rows(waiting, showsOwner: filter != .me)
                }
                if proposals > 0 {
                    WorkSectionTitle(title: String(localized: "Proposte da confermare"), count: proposals)
                    Button {
                        model.select(.decisions)
                    } label: {
                        Label(
                            String(localized: "Rivedile in «Punti chiave»: diventano voci solo se le confermi"),
                            systemImage: "cpu")
                    }
                    .buttonStyle(.link).padding(.leading, 8)
                }
                if !checklists.isEmpty {
                    WorkSectionTitle(title: String(localized: "Checklist fissate"), count: checklists.count)
                    ForEach(checklists) { list in
                        ChecklistCard(model: model, checklist: list, showsProject: true, editable: false)
                            .padding(.vertical, 3)
                    }
                }
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
        .task(id: "\(model.revision)-\(showsClosed)") { load() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(String(localized: "Da fare"), systemImage: "checklist").font(.headline)
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

    private var dueGroups: [(due: OpenWork.Due, entries: [DecisionSummary])] {
        let mine = open.filter { $0.decision.status != .waiting && matches($0.decision) }
        return OpenWork.Due.allCases.compactMap { due in
            let entries = sorted(mine.filter { OpenWork.due($0.decision.dueAt) == due })
            return entries.isEmpty ? nil : (due, entries)
        }
    }

    /// With «Le mie», the entries nobody owns yet, apart.
    private var unassigned: [DecisionSummary] {
        guard filter == .me else { return [] }
        return sorted(open.filter { $0.decision.status != .waiting && $0.decision.ownerId == nil })
    }

    /// Waiting for someone else: my entries and those without an owner, the most late first.
    private var waiting: [DecisionSummary] {
        open.filter { summary in
            summary.decision.status == .waiting
                && (filter == .me ? OpenWork.isMine(summary.decision, me: me) : matches(summary.decision))
        }
        .sorted { ($0.decision.waitingUntil ?? .distantFuture) < ($1.decision.waitingUntil ?? .distantFuture) }
    }

    private var closedShown: [DecisionSummary] {
        closed.filter {
            filter == .me ? OpenWork.isMine($0.decision, me: me) : matches($0.decision)
        }
    }

    private func sorted(_ entries: [DecisionSummary]) -> [DecisionSummary] {
        OpenWork.sorted(entries, byPriority: mode == .manage && byPriority)
    }

    private var isEmpty: Bool {
        dueGroups.isEmpty && unassigned.isEmpty && waiting.isEmpty && proposals == 0 && checklists.isEmpty
            && !showsClosed
    }

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
        proposals = (try? archive.pendingKeyPointSuggestions(.all).count) ?? 0
        checklists = (try? archive.checklists(pinnedOnly: true)) ?? []
    }
}

/// The «Da fare» row of the sidebar, with what is late or due today.
struct WorkInboxSidebarLabel: View {
    let model: AppModel
    @State private var count = 0

    var body: some View {
        Label {
            HStack {
                Text(String(localized: "Da fare"))
                Spacer()
                if count > 0 {
                    Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit()
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                        .help(String(localized: "In ritardo o in scadenza oggi"))
                }
            }
        } icon: {
            Image(systemName: "checklist")
        }
        .task(id: model.revision) {
            let open =
                (try? model.archive.decisions(
                    DecisionQuery(scope: .all, statuses: DecisionQuery.current, kinds: Set(Decision.Kind.work)))) ?? []
            let counts = OpenWork.counts(open.map(\.decision), me: model.meIDs)
            count = counts.today + counts.overdue
        }
    }
}
