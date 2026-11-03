import IAGOStore
import SwiftUI

// Pieces shared by «Inbox», «Riepilogo» and the kanban (ADR-0074).

// MARK: - Mode and people

extension AppModel {
    /// The mode of the global views («Inbox», «Punti chiave»): «Gestisci»; each entry follows its own project.
    var workViewsMode: WorkMode { .manage }

    /// The mode a scope is shown in: a project (or a stream's project) can be kept in «Traccia».
    func workViewsMode(for scope: DecisionQuery.Scope?) -> WorkMode {
        _ = revision
        switch scope {
        case .project(let id): return archive.workMode(projectID: id)
        case .stream(let id): return archive.workMode(projectID: stream(id)?.projectId)
        default: return .manage
        }
    }

    /// «Mostra la kanban» (Impostazioni › Generale): on unless turned off.
    var boardEnabled: Bool {
        _ = revision
        return ((try? archive.setting(Archive.boardEnabledKey)) ?? nil) != "0"
    }

    /// The kanban exists only in «Gestisci», when it is on.
    func boardAvailable(for scope: DecisionQuery.Scope?) -> Bool {
        boardEnabled && workViewsMode(for: scope) == .manage
    }

    /// The scopes with a «Riepilogo» and a board of their own: a project, a client, a stream.
    var workScope: BoardScope? {
        switch sidebar {
        case .library(.project(let id)): .project(id)
        case .library(.client(let id)): .client(id)
        case .library(.stream(let id)): .stream(id)
        default: nil
        }
    }

    /// «Riepilogo breve» in «Traccia» is one column: the page stays split, with the empty inspector on the right until
    /// something is opened.
    var keepsInspector: Bool {
        guard viewMode == .overview, let scope = workScope else { return false }
        return workViewsMode(for: scope.query) == .track
    }

    /// The user as a person: the name of «Il tuo nome» (Impostazioni › Generale), and «Io».
    var meIDs: Set<String> {
        let label = ((try? archive.setting(TranscriptionService.meLabelKey)) ?? nil) ?? MeLabel.defaultName
        let names = Set([TagNormalizer.normalize(label)] + MeLabel.aliases.map(TagNormalizer.normalize))
        return Set(people.filter { names.contains($0.normalized) }.map(\.id))
    }

    /// Name of the scope, for the status report and the request to Claude.
    func workScopeName(_ scope: BoardScope) -> String {
        switch scope {
        case .all: String(localized: "tutti i progetti")
        case .project(let id): project(id)?.name ?? ""
        case .client(let id): client(id)?.name ?? ""
        case .stream(let id): stream(id)?.name ?? ""
        }
    }
}

// MARK: - Kinds and states

/// Sign, colour and names of the six kinds and of the work states (ADR-0074), for the inbox, the overview and the
/// board: the same as the key point rows (`DecisionRow`), plus what only these views need.
enum WorkStyle {
    static func icon(_ kind: Decision.Kind) -> String { DecisionRow.kindIcon(kind) }
    static func tint(_ kind: Decision.Kind) -> Color { DecisionRow.tint(kind) }
    static func icon(_ decision: Decision) -> String { DecisionRow.icon(decision) }
    static func color(_ decision: Decision) -> Color { DecisionRow.color(decision) }
    static func label(_ kind: Decision.Kind) -> String { DecisionRow.kindLabel(kind) }
    static func plural(_ kind: Decision.Kind) -> String { DecisionRow.kindPlural(kind) }
    /// The state as each mode shows it: «Traccia» folds «In corso» and «Bloccata» into «Aperta».
    static func state(_ status: Decision.Status, mode: WorkMode) -> String {
        DecisionRow.statusName(mode == .track ? DecisionRow.trackStatus(status) : status, mode: mode)
    }

    static func severity(_ severity: Decision.Severity) -> String {
        switch severity {
        case .high: String(localized: "alta")
        case .medium: String(localized: "media")
        case .low: String(localized: "bassa")
        }
    }

    static func priority(_ priority: Int) -> String {
        switch priority {
        case 1: String(localized: "priorità alta")
        case 2: String(localized: "priorità media")
        default: String(localized: "priorità bassa")
        }
    }

    /// «oggi», «ieri», «ven», «3 giorni fa», «10 nov».
    static func day(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let days =
            calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day
            ?? 0
        switch days {
        case 0: return String(localized: "oggi")
        case -1: return String(localized: "ieri")
        case 1: return String(localized: "domani")
        case -6 ... -2: return String(localized: "\(-days) giorni fa")
        case 2...6: return date.formatted(.dateTime.weekday(.abbreviated))
        default: return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }

    /// Days a promised date is past (0 if not past).
    static func daysLate(_ date: Date, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        return max(
            0,
            calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now))
                .day ?? 0)
    }
}

// MARK: - Open work, grouped

/// How open work is grouped by its due date, for «Inbox» and the morning notification.
enum OpenWork {
    enum Due: CaseIterable {
        case overdue, today, thisWeek, later, none

        var title: String {
            switch self {
            case .overdue: String(localized: "In ritardo")
            case .today: String(localized: "Oggi")
            case .thisWeek: String(localized: "Questa settimana")
            case .later: String(localized: "Più avanti")
            case .none: String(localized: "Senza data")
            }
        }
    }

    static func due(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> Due {
        guard let date else { return .none }
        let today = calendar.startOfDay(for: now)
        if date < today { return .overdue }
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        if let week = calendar.dateInterval(of: .weekOfYear, for: now), date < week.end { return .thisWeek }
        return .later
    }

    /// Mine: owned by me, or by nobody (the inbox shows those apart, «Senza responsabile»).
    static func isMine(_ decision: Decision, me: Set<String>) -> Bool {
        decision.ownerId.map(me.contains) ?? true
    }

    /// What the morning notification says: due today, overdue, waits past their date.
    struct Counts: Equatable {
        var today = 0
        var overdue = 0
        var waitingLate = 0
        var isEmpty: Bool { today == 0 && overdue == 0 && waitingLate == 0 }
    }

    static func counts(_ entries: [Decision], me: Set<String>, now: Date = Date()) -> Counts {
        var counts = Counts()
        let today = Calendar.current.startOfDay(for: now)
        for decision in entries where decision.kind.isWork && decision.status.isOpen && isMine(decision, me: me) {
            if decision.status == .waiting {
                if let until = decision.waitingUntil, until < today { counts.waitingLate += 1 }
                continue
            }
            switch due(decision.dueAt, now: now) {
            case .overdue: counts.overdue += 1
            case .today: counts.today += 1
            default: break
            }
        }
        return counts
    }

    /// «Da fare ora», the red count of «Inbox»: my entries late or due today, the ones without an owner, and the waits
    /// past their date. The proposals to confirm are counted apart.
    static func needsAction(_ decision: Decision, me: Set<String>, now: Date = Date()) -> Bool {
        guard decision.kind.isWork, decision.status.isOpen, isMine(decision, me: me) else { return false }
        if decision.status == .waiting {
            return decision.waitingUntil.map { $0 < Calendar.current.startOfDay(for: now) } ?? false
        }
        if decision.ownerId == nil { return true }
        return [.overdue, .today].contains(due(decision.dueAt, now: now))
    }

    /// Priority first (in «Gestisci»), then the due date, then the most recent.
    static func sorted(_ entries: [DecisionSummary], byPriority: Bool) -> [DecisionSummary] {
        entries.sorted { a, b in
            if byPriority, (a.decision.priority ?? 9) != (b.decision.priority ?? 9) {
                return (a.decision.priority ?? 9) < (b.decision.priority ?? 9)
            }
            let dueA = a.decision.dueAt ?? .distantFuture
            let dueB = b.decision.dueAt ?? .distantFuture
            if dueA != dueB { return dueA < dueB }
            return a.decision.decidedAt > b.decision.decidedAt
        }
    }
}

// MARK: - A row of work

/// One entry in «Inbox» and in «Riepilogo»: sign, title, where and who, due date. A click opens it in the detail
/// pane, as in «Punti chiave»; the right click changes its state.
struct WorkEntryRow: View {
    let model: AppModel
    let summary: DecisionSummary
    /// The mode of the view; each entry is shown in the mode of its own project (ADR-0076).
    let mode: WorkMode
    var showsProject = true
    /// Shows the owner even when it is the user (the inbox leaves it out: those are mine).
    var showsOwner = true
    @State private var askingWaiting = false

    private var entryMode: WorkMode { model.workMode(for: summary.decision.projectId) }

    var body: some View {
        let decision = summary.decision
        let mode = entryMode
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if WorkCheckbox.applies(decision, mode: mode) {
                WorkCheckbox(model: model, decision: decision)
            } else {
                Image(systemName: WorkStyle.icon(decision)).foregroundStyle(DecisionRow.signal(decision))
                    .help(WorkStyle.label(decision.kind))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(decision.text).lineLimit(2)
                    .foregroundStyle(decision.kind.isWork && !decision.status.isOpen ? .secondary : .primary)
                    .strikethrough(decision.status == .cancelled || decision.status == .superseded, color: .secondary)
                detailLine
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 7).fill(
                model.selectedDecisionID == decision.id ? Color.accentColor.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.selectedDecisionID = decision.id }
        .contextMenu {
            WorkStateMenu(model: model, decision: decision, mode: mode) { askingWaiting = true }
        }
        .popover(isPresented: $askingWaiting, arrowEdge: .trailing) {
            WaitingForm(model: model, decisionID: decision.id) { askingWaiting = false }
        }
    }

    private var detailLine: some View {
        let decision = summary.decision
        let mode = entryMode
        var parts: [String] = []
        if showsProject, let project = summary.projectName { parts.append(project) }
        if showsOwner, let owner = summary.ownerName { parts.append(owner) }
        if mode == .manage, let severity = decision.severity, decision.kind == .risk {
            parts.append(String(localized: "gravità \(WorkStyle.severity(severity))"))
        }
        if mode == .manage, let priority = decision.priority { parts.append(WorkStyle.priority(priority)) }
        if summary.checklist.total > 0 { parts.append("☑ \(summary.checklist.done)/\(summary.checklist.total)") }
        return HStack(spacing: 6) {
            if !parts.isEmpty { Text(parts.joined(separator: " · ")) }
            if decision.status == .blocked || (!summary.blockers.isEmpty && decision.status.isOpen) {
                WorkTag(text: String(localized: "bloccata"), color: .red)
            }
            if mode == .manage, decision.status == .inProgress {
                WorkTag(text: String(localized: "in corso"), color: .accentColor)
            }
            if mode == .manage, decision.happenedAt != nil, decision.kind == .risk {
                WorkTag(text: String(localized: "diventato problema"), color: .red)
            }
        }
        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
    }

    @ViewBuilder
    private var trailing: some View {
        let decision = summary.decision
        if decision.status == .waiting {
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(localized: "attende \(summary.waitingOnName ?? String(localized: "altri"))"))
                if let until = decision.waitingUntil {
                    let late = WorkStyle.daysLate(until)
                    Text(
                        late > 0
                            ? String(localized: "entro \(WorkStyle.day(until)) · \(late) gg di ritardo")
                            : String(localized: "entro \(WorkStyle.day(until))")
                    )
                    .foregroundStyle(late > 0 ? .red : .secondary)
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        } else if let closed = decision.closedAt, !decision.status.isOpen {
            Text(String(localized: "chiusa \(WorkStyle.day(closed))")).font(.caption).foregroundStyle(.secondary)
        } else if let due = decision.dueAt, decision.status.isOpen {
            Text(WorkStyle.day(due)).font(.caption.weight(.medium)).monospacedDigit()
                .foregroundStyle(OpenWork.due(due) == .overdue ? .red : .secondary)
        } else if !decision.kind.isWork {
            Text(decision.decidedAt.formatted(.dateTime.day().month(.abbreviated))).font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// A small coloured label: «bloccata», «in corso».
struct WorkTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text).font(.caption2.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

/// The states one can give by hand, as the mode shows them; «In attesa…» asks whom and until when.
struct WorkStateMenu: View {
    let model: AppModel
    let decision: Decision
    let mode: WorkMode
    let askWaiting: () -> Void

    var body: some View {
        Button(String(localized: "Apri")) { model.selectedDecisionID = decision.id }
        if decision.sourceItemId != nil || decision.sourceNoteId != nil,
            let summary = try? model.archive.decisionSummary(decision.id)
        {
            Button(String(localized: "Vai alla fonte")) { model.openDecisionSource(summary) }
        }
        if decision.kind.isWork, decision.status != .superseded {
            Divider()
            ForEach(states, id: \.self) { status in
                Button(WorkStyle.state(status, mode: mode)) { model.setDecisionStatus(decision.id, status) }
                    .disabled(decision.status == status)
            }
            Button(String(localized: "In attesa…"), action: askWaiting)
            Button(String(localized: "Fatta")) { model.setDecisionStatus(decision.id, .done) }
                .disabled(decision.status == .done)
            Button(String(localized: "Annullata")) { model.setDecisionStatus(decision.id, .cancelled) }
                .disabled(decision.status == .cancelled)
        }
    }

    private var states: [Decision.Status] {
        mode == .manage ? [.active, .inProgress, .blocked] : [.active]
    }
}

/// «In attesa di»: whom (a known person or a new name) and, if promised, until when.
struct WaitingForm: View {
    let model: AppModel
    let decisionID: String
    let done: () -> Void
    @State private var name = ""
    @State private var hasDate = true
    @State private var until = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "In attesa")).font(.headline)
            HStack(spacing: 6) {
                TextField(String(localized: "Da chi"), text: $name).textFieldStyle(.roundedBorder).frame(width: 200)
                if !model.people.isEmpty {
                    Menu {
                        ForEach(model.people) { person in Button(person.name) { name = person.name } }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .help(String(localized: "Scegli tra le persone che IAGO conosce"))
                }
            }
            HStack(spacing: 6) {
                Toggle(String(localized: "Entro"), isOn: $hasDate).toggleStyle(.checkbox)
                DatePicker("", selection: $until, displayedComponents: .date).labelsHidden().disabled(!hasDate)
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), action: done).keyboardShortcut(.cancelAction)
                Button(String(localized: "In attesa")) { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .onAppear {
            guard let decision = try? model.archive.decision(decisionID) else { return }
            name = (try? model.archive.personName(decision.waitingOnId)) ?? nil ?? ""
            if let date = decision.waitingUntil { until = date }
        }
    }

    private func save() {
        let date = hasDate ? Calendar.current.startOfDay(for: until) : nil
        model.perform {
            let person = try model.archive.person(named: name)
            try model.archive.updateDecision(decisionID) {
                $0.status = .waiting
                $0.waitingOnId = person?.id
                $0.waitingUntil = date
            }
        }
        done()
    }
}

// MARK: - Checklists of projects

/// A project's checklist: tick, add, rename, pin to «Inbox», delete.
struct ChecklistCard: View {
    let model: AppModel
    let checklist: Checklist
    var showsProject = false
    /// Rename, pin and delete the list (the overview); the inbox only ticks and adds lines.
    var editable = true
    @State private var items: [ChecklistItem] = []
    @State private var newLine = ""
    @State private var renaming: String?
    @State private var deleting = false
    @State private var editingLine: (id: String, text: String)?
    @AppStorage private var collapsed: Bool

    init(model: AppModel, checklist: Checklist, showsProject: Bool = false, editable: Bool = true) {
        self.model = model
        self.checklist = checklist
        self.showsProject = showsProject
        self.editable = editable
        _collapsed = AppStorage(wrappedValue: false, "checklist.collapsed.\(checklist.id)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if !collapsed {
                ForEach(items) { item in line(item) }
                TextField(String(localized: "Aggiungi una voce"), text: $newLine)
                    .textFieldStyle(.plain).font(.callout).padding(.leading, 24)
                    .onSubmit(add)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(IAGOColor.card))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.18)))
        .task(id: model.revision) { items = (try? model.archive.checklistItems(checklistID: checklist.id)) ?? [] }
        .confirmationDialog(
            String(localized: "Eliminare la checklist «\(checklist.name)»?"), isPresented: $deleting,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Elimina"), role: .destructive) {
                model.perform { try model.archive.deleteChecklist(checklist.id) }
            }
        } message: {
            Text(String(localized: "Le sue voci vengono eliminate con lei."))
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { collapsed.toggle() }
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    .rotationEffect(.degrees(collapsed ? 0 : 90)).frame(width: 12)
            }
            .buttonStyle(.plain)
            Image(systemName: "checklist").foregroundStyle(.orange)
            if let name = renaming {
                TextField(
                    String(localized: "Nome"), text: Binding(get: { name }, set: { renaming = $0 })
                )
                .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                .onSubmit {
                    let value = name
                    model.perform { try model.archive.updateChecklist(checklist.id) { $0.name = value } }
                    renaming = nil
                }
            } else {
                Text(checklist.name).font(.callout.weight(.semibold))
            }
            if showsProject, let project = model.project(checklist.projectId) {
                Text("· \(project.name)").font(.caption).foregroundStyle(.secondary)
            }
            Text("\(items.filter(\.done).count)/\(items.count)").font(.caption).monospacedDigit()
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            if editable {
                Button {
                    model.perform { try model.archive.updateChecklist(checklist.id) { $0.pinned.toggle() } }
                } label: {
                    Image(systemName: checklist.pinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.borderless)
                .help(
                    checklist.pinned
                        ? String(localized: "Togli da «Inbox»") : String(localized: "Fissa in «Inbox»"))
                Menu {
                    Button(String(localized: "Rinomina")) { renaming = checklist.name }
                    Divider()
                    Button(String(localized: "Elimina…"), role: .destructive) { deleting = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
        }
    }

    private func line(_ item: ChecklistItem) -> some View {
        HStack(spacing: 8) {
            Button {
                model.perform { try model.archive.updateChecklistItem(item.id) { $0.done.toggle() } }
            } label: {
                Image(systemName: item.done ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            if let editing = editingLine, editing.id == item.id {
                TextField(
                    "", text: Binding(get: { editing.text }, set: { editingLine = (item.id, $0) })
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let value = editing.text
                    model.perform { try model.archive.updateChecklistItem(item.id) { $0.text = value } }
                    editingLine = nil
                }
            } else {
                Text(item.text).font(.callout).foregroundStyle(item.done ? .secondary : .primary)
                    .onTapGesture(count: 2) { editingLine = (item.id, item.text) }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 18)
        .contextMenu {
            Button(String(localized: "Modifica")) { editingLine = (item.id, item.text) }
            Button(String(localized: "Elimina"), role: .destructive) {
                model.perform { try model.archive.deleteChecklistItem(item.id) }
            }
        }
    }

    private func add() {
        let text = newLine
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.perform { try model.archive.addChecklistItem(text, checklistID: checklist.id) }
        newLine = ""
    }
}

/// «Nuova checklist» of a project: a name, then its lines are added in the card.
struct NewChecklistButton: View {
    let model: AppModel
    let projectID: String
    @State private var asking = false
    @State private var name = ""

    var body: some View {
        Button {
            name = ""
            asking = true
        } label: {
            Label(String(localized: "Nuova checklist"), systemImage: "plus")
        }
        .buttonStyle(.link)
        .popover(isPresented: $asking, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Nuova checklist")).font(.headline)
                TextField(String(localized: "Per esempio: Consegna finale"), text: $name)
                    .textFieldStyle(.roundedBorder).frame(width: 240)
                    .onSubmit(create)
                HStack {
                    Spacer()
                    Button(String(localized: "Annulla")) { asking = false }.keyboardShortcut(.cancelAction)
                    Button(String(localized: "Crea"), action: create).keyboardShortcut(.defaultAction)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(14)
        }
    }

    private func create() {
        let value = name
        guard !value.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.perform { try model.archive.createChecklist(projectID: projectID, name: value) }
        asking = false
    }
}

/// A section title of the work views, with an optional count.
struct WorkSectionTitle: View {
    let title: String
    var count: Int?
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.headline).foregroundStyle(color)
            if let count { Text("\(count)").font(.callout).monospacedDigit().foregroundStyle(.secondary) }
        }
        .padding(.top, 14).padding(.bottom, 2)
    }
}

/// The two counts of «Inbox» (ADR-0076): red with «!» for what asks an action, yellow with a sparkle for the proposals
/// to confirm. The same colour and sign in the sidebar and in the header of the block they count.
enum InboxCount {
    case action, proposals

    var color: Color { self == .action ? .red : .yellow }
    var textColor: Color { self == .action ? .white : .black }
    var systemImage: String { self == .action ? "exclamationmark" : "sparkle" }

    var help: String {
        switch self {
        case .action:
            String(
                localized:
                    "Da fare ora: tue voci in ritardo o in scadenza oggi, voci senza responsabile, attese scadute")
        case .proposals: String(localized: "Proposte del motore da confermare")
        }
    }
}

/// A count of «Inbox» as a coloured capsule with its sign.
struct InboxCountBadge: View {
    let kind: InboxCount
    let count: Int
    var large = false

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: kind.systemImage).font(.system(size: large ? 9 : 8, weight: .heavy))
            Text("\(count)").monospacedDigit()
        }
        .font((large ? Font.callout : .caption).weight(.bold)).foregroundStyle(kind.textColor)
        .padding(.horizontal, large ? 8 : 6).padding(.vertical, 1)
        .background(Capsule().fill(kind.color))
        .help(kind.help)
    }
}

/// The header of a block of «Inbox»: a square sign, the title and, at the end, the count in the block's colour (none
/// for a block nothing counts).
struct InboxBlockHeader<Trailing: View>: View {
    let title: String
    let systemImage: String
    let count: Int
    var kind: InboxCount?
    /// The box's inner padding: the title is inset, the line runs from edge to edge.
    var inset: CGFloat = 0
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .bold))
                    .foregroundStyle(kind?.textColor ?? .secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6).fill(kind?.color ?? Color.secondary.opacity(0.2)))
                Text(title).font(.title3.bold()).foregroundStyle(kind == nil ? .secondary : .primary)
                Spacer()
                trailing()
                if let kind {
                    InboxCountBadge(kind: kind, count: count, large: true)
                } else {
                    Text("\(count)").font(.callout).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, inset)
            Rectangle().fill((kind?.color ?? .secondary).opacity(0.5)).frame(height: 1)
        }
        .padding(.top, inset > 0 ? 12 : 18).padding(.bottom, 2)
    }
}

extension InboxBlockHeader where Trailing == EmptyView {
    init(title: String, systemImage: String, count: Int, kind: InboxCount? = nil, inset: CGFloat = 0) {
        self.init(title: title, systemImage: systemImage, count: count, kind: kind, inset: inset) { EmptyView() }
    }
}

/// A box of «Inbox» (two halves of the column): its header stays, the rows scroll inside with the bar always
/// visible and, at the bottom right, «altre N» while rows are below. An empty box shrinks to its header and a line.
struct InboxBox<Header: View, Content: View>: View {
    /// The rows in their order, each with the same `.id` in the content.
    let ids: [String]
    let isEmpty: Bool
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content
    @State private var visible: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
            if isEmpty {
                VStack(alignment: .leading, spacing: 2) { content() }
                    .padding(.horizontal, 14).padding(.bottom, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) { content() }
                        .scrollTargetLayout()
                        .padding(.leading, 14).padding(.trailing, 18).padding(.bottom, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AlwaysVisibleScroller())
                }
                .scrollIndicators(.visible)
                .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.6) { visible = Set($0) }
                .overlay(alignment: .bottomTrailing) {
                    if below > 0 { InboxMorePill(count: below).padding(.trailing, 26).padding(.bottom, 8) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: isEmpty ? nil : .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 10).fill(IAGOColor.card))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(IAGOColor.divider.opacity(0.7)))
    }

    /// The rows after the last one in view.
    private var below: Int {
        guard let last = ids.lastIndex(where: visible.contains) else { return 0 }
        return ids.count - last - 1
    }
}

/// Keeps the bar of the enclosing scroll view on screen while there is more to see, whatever the Mac's «Mostra barre
/// di scorrimento»: a thin, faint classic scroller, hidden only when everything fits.
private struct AlwaysVisibleScroller: NSViewRepresentable {
    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(
                self, selector: #selector(styleChanged), name: NSScroller.preferredScrollerStyleDidChangeNotification,
                object: nil)
        }

        @objc private func styleChanged() { DispatchQueue.main.async { self.apply() } }

        func apply() {
            guard let scrollView = enclosingScrollView else { return }
            if !(scrollView.verticalScroller is ThinScroller) { scrollView.verticalScroller = ThinScroller() }
            scrollView.scrollerStyle = .legacy
            scrollView.autohidesScrollers = true
            scrollView.hasVerticalScroller = true
        }
    }

    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) { DispatchQueue.main.async { view.apply() } }
}

/// A light scroller: no track, a narrow rounded knob in the text colour at low opacity, a little stronger under the
/// pointer.
final class ThinScroller: NSScroller {
    private var hovering = false
    private var hoverArea: NSTrackingArea?

    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style)
        -> CGFloat
    { 10 }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) { drawKnob() }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func drawKnob() {
        let knob = rect(for: .knob).insetBy(dx: 0, dy: 2)
        guard knob.height > 0 else { return }
        let width: CGFloat = hovering ? 6 : 5
        let bar = NSRect(x: bounds.midX - width / 2, y: knob.minY, width: width, height: knob.height)
        NSColor.labelColor.withAlphaComponent(hovering ? 0.32 : 0.16).setFill()
        NSBezierPath(roundedRect: bar, xRadius: width / 2, yRadius: width / 2).fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
    }
}

/// The two boxes of «Inbox» one over the other, with a handle between them to change their share (kept for the next
/// times; a double click goes back to half and half). An empty box takes only its header and the other the rest.
struct InboxSplit<Top: View, Bottom: View>: View {
    @Binding var ratio: Double
    let topCollapsed: Bool
    let bottomCollapsed: Bool
    @ViewBuilder var top: () -> Top
    @ViewBuilder var bottom: () -> Bottom
    @State private var dragStart: Double?
    @State private var hovering = false
    private static var gripHeight: CGFloat { 14 }

    var body: some View {
        if topCollapsed || bottomCollapsed {
            VStack(spacing: 12) {
                top()
                bottom()
            }
        } else {
            GeometryReader { geometry in
                let height = max(0, geometry.size.height - Self.gripHeight)
                VStack(spacing: 0) {
                    top().frame(height: height * ratio)
                    grip(height)
                    bottom().frame(height: height * (1 - ratio))
                }
            }
        }
    }

    private func grip(_ height: CGFloat) -> some View {
        Capsule().fill(Color.secondary.opacity(hovering || dragStart != nil ? 0.6 : 0.3)).frame(width: 36, height: 4)
            .frame(maxWidth: .infinity).frame(height: Self.gripHeight)
            .contentShape(Rectangle())
            .pointerStyle(.rowResize)
            .onHover { hovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let start = dragStart ?? ratio
                        dragStart = start
                        ratio = min(0.8, max(0.2, start + value.translation.height / max(height, 1)))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) { ratio = 0.5 }
            .help(String(localized: "Trascina per cambiare l'altezza dei due box. Doppio clic: metà e metà."))
    }
}

/// «altre N» at the bottom of a box of «Inbox»: discreet, three small dots that light up once every 10 seconds.
struct InboxMorePill: View {
    let count: Int
    @State private var pulse = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle().fill(.secondary).frame(width: 4, height: 4)
                        .keyframeAnimator(initialValue: 0.35, trigger: pulse) { dot, opacity in
                            dot.opacity(opacity)
                        } keyframes: { _ in
                            LinearKeyframe(0.35, duration: Double(index) * 0.15)
                            CubicKeyframe(1, duration: 0.3)
                            CubicKeyframe(0.35, duration: 0.6)
                        }
                }
            }
            Text(String(localized: "altre \(count)")).font(.subheadline).monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 2)
        .background(Capsule().fill(IAGOColor.bar.opacity(0.85)))
        .overlay(Capsule().strokeBorder(IAGOColor.divider))
        .allowsHitTesting(false)
        .accessibilityLabel(String(localized: "Altre \(count) voci più in basso"))
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(2))
            while !Task.isCancelled {
                pulse += 1
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }
}
