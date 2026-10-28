import IAGOStore
import SwiftUI

/// The kanban (ADR-0074), only in «Gestisci»: one board per project, client and stream, and a global one. The fixed
/// columns are the work states: dragging a card between them changes its state («In attesa» asks whom and until
/// when). The free columns of each board come after them: a card dropped there keeps its state. Only work kinds are
/// on the board. «Fatta» hides what was closed more than 14 days ago, until «Mostra tutte».
struct WorkBoard: View {
    @Bindable var model: AppModel
    let scope: BoardScope
    @State private var entries: [DecisionSummary] = []
    @State private var columns: [BoardColumn] = []
    @State private var places: [String: String] = [:]
    @State private var showsArchived = false
    /// Filters: project (boards that span projects), owner, kind.
    @State private var projectFilter: String?
    @State private var personFilter: String?
    @State private var kindFilter: Decision.Kind?
    /// A card dropped on «In attesa»: whom and until when, before its state changes.
    @State private var waitingFor: String?
    @State private var addingColumn = false
    @State private var newColumn = ""

    static let fixed: [Decision.Status] = [.active, .inProgress, .waiting, .blocked, .done]
    static let columnWidth: CGFloat = 230

    private var spansProjects: Bool {
        switch scope {
        case .all, .client: true
        default: false
        }
    }

    var body: some View {
        Group {
            if model.boardAvailable(for: scope.query) {
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(Self.fixed, id: \.self) { status in fixedColumn(status) }
                        if !columns.isEmpty {
                            Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 2).padding(.vertical, 4)
                        }
                        ForEach(columns) { column in freeColumn(column) }
                        addColumnButton
                    }
                    .padding(12)
                }
            } else {
                ContentUnavailableView {
                    Label(String(localized: "Kanban non disponibile"), systemImage: "rectangle.split.3x1")
                } description: {
                    Text(
                        String(
                            localized:
                                "La kanban c'è nella modalità Gestisci, quando è accesa (Impostazioni › Generale). Un progetto tenuto in Traccia non ha la kanban."
                        ))
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if case .all = scope {
                    globalHeader
                } else {
                    ViewModePicker(model: model)
                }
                filterBar
            }
            .background(.bar)
        }
        .task(id: "\(model.revision)-\(scope.key)") { load() }
    }

    // MARK: Header and filters

    /// The global board, from «Da fare» or from «Punti chiave».
    private var globalHeader: some View {
        HStack(spacing: 10) {
            Label(String(localized: "Kanban di tutti i progetti"), systemImage: "rectangle.split.3x1").font(.headline)
            Spacer(minLength: 8)
            Picker(String(localized: "Vista"), selection: $model.viewMode) {
                Label(String(localized: "Elenco"), systemImage: "list.bullet").tag(
                    model.sidebar == .decisions ? AppModel.ViewMode.decisions : AppModel.ViewMode.list)
                Label(String(localized: "Kanban"), systemImage: "rectangle.split.3x1").tag(AppModel.ViewMode.board)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)
    }

    private var filterBar: some View {
        FlowLayout(spacing: 6, lineSpacing: 8) {
            if spansProjects {
                FilterChip(
                    title: model.project(projectFilter)?.name ?? String(localized: "Tutti i progetti"),
                    systemImage: "folder", active: projectFilter != nil
                ) {
                    OptionList(
                        options: [(String?.none, String(localized: "Tutti i progetti"))]
                            + boardProjects.map { (Optional($0.id), $0.name) },
                        selection: $projectFilter)
                }
            }
            FilterChip(
                title: model.people.first { $0.id == personFilter }?.name ?? String(localized: "Tutte le persone"),
                systemImage: "person", active: personFilter != nil
            ) {
                OptionList(
                    options: [(String?.none, String(localized: "Tutte le persone"))]
                        + model.people.map { (Optional($0.id), $0.name) },
                    selection: $personFilter)
            }
            FilterChip(
                title: kindFilter.map(WorkStyle.plural) ?? String(localized: "Tutti i tipi"),
                systemImage: "square.stack", active: kindFilter != nil
            ) {
                OptionList(
                    options: [(Decision.Kind?.none, String(localized: "Tutti i tipi"))]
                        + Decision.Kind.work.map { (Optional($0), WorkStyle.plural($0)) },
                    selection: $kindFilter)
            }
            if projectFilter != nil || personFilter != nil || kindFilter != nil {
                ChipButton(
                    title: String(localized: "Azzera"), systemImage: "eraser", active: false, showsChevron: false,
                    destructive: true
                ) {
                    projectFilter = nil
                    personFilter = nil
                    kindFilter = nil
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.top, 2).padding(.bottom, 10)
    }

    private var boardProjects: [Project] {
        let ids = Set(entries.compactMap(\.decision.projectId))
        return model.projects.filter { ids.contains($0.id) }
    }

    // MARK: Data

    private func load() {
        let archive = model.archive
        entries =
            (try? archive.decisions(
                DecisionQuery(
                    scope: scope.query, statuses: Set(Self.fixed + [.superseded]), kinds: Set(Decision.Kind.work))))
            ?? []
        columns = (try? archive.boardColumns(scope)) ?? []
        places = (try? archive.boardPlaces(scope)) ?? [:]
        showsArchived = ((try? archive.setting(Archive.boardShowArchivedKey)) ?? nil) == "1"
    }

    private var filtered: [DecisionSummary] {
        entries.filter { summary in
            let decision = summary.decision
            if let projectFilter, decision.projectId != projectFilter { return false }
            if let personFilter, decision.ownerId != personFilter { return false }
            if let kindFilter, decision.kind != kindFilter { return false }
            return true
        }
    }

    /// Closed for more than 14 days: out of «Fatta» until «Mostra tutte».
    private func isArchived(_ decision: Decision) -> Bool {
        guard !decision.status.isOpen, let closed = decision.closedAt else { return false }
        return closed < Calendar.current.date(byAdding: .day, value: -Archive.boardArchiveDays, to: Date())!
    }

    /// The free column a card is in, if that column still exists.
    private func freeColumn(of id: String) -> String? {
        guard let column = places[id], columns.contains(where: { $0.id == column }) else { return nil }
        return column
    }

    private func cards(_ status: Decision.Status) -> [DecisionSummary] {
        filtered.filter { summary in
            guard freeColumn(of: summary.id) == nil else { return false }
            // Entries closed by another one («completa», «risponde a») are done too.
            let column: Decision.Status = summary.decision.status == .superseded ? .done : summary.decision.status
            return column == status && (showsArchived || !isArchived(summary.decision))
        }
        .sorted(by: order)
    }

    private func cards(inColumn id: String) -> [DecisionSummary] {
        filtered.filter { freeColumn(of: $0.id) == id && (showsArchived || !isArchived($0.decision)) }.sorted(by: order)
    }

    private func order(_ a: DecisionSummary, _ b: DecisionSummary) -> Bool {
        if a.decision.status == .done || a.decision.status == .superseded {
            return (a.decision.closedAt ?? .distantPast) > (b.decision.closedAt ?? .distantPast)
        }
        return OpenWork.sorted([a, b], byPriority: true).first?.id == a.id
    }

    // MARK: Columns

    private func fixedColumn(_ status: Decision.Status) -> some View {
        let shown = cards(status)
        let archived =
            status == .done
            ? filtered.filter { freeColumn(of: $0.id) == nil && !$0.decision.status.isOpen && isArchived($0.decision) }
                .count : 0
        return BoardColumnView(
            title: WorkStyle.state(status, mode: .manage), count: shown.count, tint: tint(status),
            onDrop: { id in drop(id, on: status) }
        ) {
            ForEach(shown) { summary in card(summary) }
            if status == .done, archived > 0 || showsArchived {
                archiveLine(archived)
            }
        }
        .popover(
            isPresented: Binding(
                get: { status == .waiting && waitingFor != nil }, set: { if !$0 { waitingFor = nil } }),
            arrowEdge: .bottom
        ) {
            if let id = waitingFor {
                WaitingForm(model: model, decisionID: id) { waitingFor = nil }
            }
        }
    }

    private func freeColumn(_ column: BoardColumn) -> some View {
        let shown = cards(inColumn: column.id)
        return BoardColumnView(
            title: column.name, count: shown.count, tint: .secondary,
            onDrop: { id in
                model.perform { try model.archive.placeOnBoard(id, column: column.id, scope: scope) }
                model.reload()
            },
            menu: AnyView(columnMenu(column))
        ) {
            ForEach(shown) { summary in card(summary) }
        }
    }

    @ViewBuilder
    private func columnMenu(_ column: BoardColumn) -> some View {
        FreeColumnMenu(model: model, column: column, columns: columns)
    }

    private var addColumnButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            if addingColumn {
                TextField(String(localized: "Nome della colonna"), text: $newColumn)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addColumn)
                HStack {
                    Button(String(localized: "Annulla")) {
                        addingColumn = false
                        newColumn = ""
                    }
                    Button(String(localized: "Aggiungi"), action: addColumn).buttonStyle(.borderedProminent)
                        .disabled(newColumn.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .controlSize(.small)
            } else {
                Button {
                    addingColumn = true
                } label: {
                    Label(String(localized: "Colonna"), systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help(
                    String(
                        localized:
                            "Una colonna libera di questa board, per esempio «Da discutere venerdì»: raggruppa le voci senza cambiare il loro stato."
                    ))
            }
        }
        .frame(width: 180, alignment: .leading)
        .padding(.top, 6)
    }

    private func addColumn() {
        let name = newColumn
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.perform { try model.archive.addBoardColumn(scope, name: name) }
        newColumn = ""
        addingColumn = false
    }

    private func archiveLine(_ archived: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(
                showsArchived
                    ? String(localized: "Archivia attività chiuse \(Archive.boardArchiveDays)+ giorni")
                    : String(localized: "Attività chiuse \(Archive.boardArchiveDays)+ giorni archiviate (\(archived))")
            )
            .font(.caption2).foregroundStyle(.secondary)
            Button(showsArchived ? String(localized: "Archivia") : String(localized: "Mostra tutte")) {
                let value = !showsArchived
                model.perform { try model.archive.setSetting(Archive.boardShowArchivedKey, value ? "1" : nil) }
                showsArchived = value
            }
            .buttonStyle(.link).font(.caption)
        }
        .padding(.top, 6)
    }

    private func tint(_ status: Decision.Status) -> Color {
        switch status {
        case .inProgress: .accentColor
        case .waiting: .purple
        case .blocked: .red
        case .done: .green
        default: .secondary
        }
    }

    private func card(_ summary: DecisionSummary) -> some View {
        BoardCard(model: model, summary: summary, showsProject: spansProjects)
            // Entries closed by another one follow that one: they are not moved by hand.
            .draggable(BoardCard.payload(summary.id)) {
                BoardCard(model: model, summary: summary, showsProject: spansProjects)
                    .frame(width: Self.columnWidth - 16)
            }
    }

    // MARK: Moving

    /// A card on a fixed column: out of any free column, and in the column's state.
    private func drop(_ id: String, on status: Decision.Status) {
        guard let summary = entries.first(where: { $0.id == id }) else { return }
        model.perform { try model.archive.placeOnBoard(id, column: nil, scope: scope) }
        let current = summary.decision.status == .superseded ? .done : summary.decision.status
        if current != status, summary.decision.status != .superseded {
            if status == .waiting {
                waitingFor = id
            } else {
                model.setDecisionStatus(id, status)
            }
        }
        model.reload()
    }
}

/// One column: its title and count, its cards, and the drop target.
private struct BoardColumnView<Content: View>: View {
    let title: String
    let count: Int
    let tint: Color
    let onDrop: (String) -> Void
    var menu: AnyView?
    @ViewBuilder let content: () -> Content
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(count)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let menu { menu }
            }
            .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 6) { content() }
            Spacer(minLength: 40)
        }
        .padding(8)
        .frame(width: WorkBoard.columnWidth, alignment: .top)
        .frame(minHeight: 300, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(
                targeted ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(targeted ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 2)
        )
        .dropDestination(for: String.self) { values, _ in
            let ids = values.compactMap(BoardCard.decisionID)
            guard !ids.isEmpty else { return false }
            ids.forEach(onDrop)
            return true
        } isTargeted: {
            targeted = $0
        }
    }
}

/// Rename, move left or right, delete a free column.
private struct FreeColumnMenu: View {
    let model: AppModel
    let column: BoardColumn
    let columns: [BoardColumn]
    @State private var renaming = false
    @State private var name = ""
    @State private var deleting = false

    var body: some View {
        let index = columns.firstIndex { $0.id == column.id } ?? 0
        Menu {
            Button(String(localized: "Rinomina…")) {
                name = column.name
                renaming = true
            }
            Button(String(localized: "Sposta a sinistra")) { move(from: index, by: -1) }.disabled(index == 0)
            Button(String(localized: "Sposta a destra")) { move(from: index, by: 1) }
                .disabled(index >= columns.count - 1)
            Divider()
            Button(String(localized: "Elimina colonna…"), role: .destructive) { deleting = true }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .popover(isPresented: $renaming) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(String(localized: "Nome della colonna"), text: $name).textFieldStyle(.roundedBorder)
                    .frame(width: 220).onSubmit(rename)
                HStack {
                    Spacer()
                    Button(String(localized: "Annulla")) { renaming = false }.keyboardShortcut(.cancelAction)
                    Button(String(localized: "Rinomina"), action: rename).keyboardShortcut(.defaultAction)
                }
            }
            .padding(14)
        }
        .confirmationDialog(
            String(localized: "Eliminare la colonna «\(column.name)»?"), isPresented: $deleting,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Elimina"), role: .destructive) {
                model.perform { try model.archive.deleteBoardColumn(column.id) }
            }
        } message: {
            Text(String(localized: "Le voci tornano nella colonna del loro stato."))
        }
    }

    private func rename() {
        let value = name
        model.perform { try model.archive.renameBoardColumn(column.id, to: value) }
        renaming = false
    }

    private func move(from index: Int, by offset: Int) {
        var ids = columns.map(\.id)
        let target = index + offset
        guard ids.indices.contains(target) else { return }
        ids.swapAt(index, target)
        model.perform { try model.archive.reorderBoardColumns(ids) }
    }
}

/// A card: kind, title, owner, due date (red when late), checklist, «bloccata», waits.
struct BoardCard: View {
    let model: AppModel
    let summary: DecisionSummary
    var showsProject = false
    @State private var askingWaiting = false

    /// What a dragged card carries: a prefix, so text dragged from elsewhere is not taken for a card.
    static func payload(_ id: String) -> String { "iago-board-card:\(id)" }
    static func decisionID(_ payload: String) -> String? {
        let prefix = "iago-board-card:"
        return payload.hasPrefix(prefix) ? String(payload.dropFirst(prefix.count)) : nil
    }

    var body: some View {
        let decision = summary.decision
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: WorkStyle.icon(decision)).foregroundStyle(WorkStyle.color(decision))
                    .help(WorkStyle.label(decision.kind))
                Text(decision.text).font(.callout).lineLimit(3)
                    .foregroundStyle(decision.status.isOpen ? .primary : .secondary)
            }
            if showsProject, let project = summary.projectName {
                Text(project).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: 6) {
                if let owner = summary.ownerName {
                    Label(owner, systemImage: "person").labelStyle(.titleAndIcon).lineLimit(1)
                }
                if let due = decision.dueAt, decision.status.isOpen {
                    Text(WorkStyle.day(due)).foregroundStyle(OpenWork.due(due) == .overdue ? .red : .secondary)
                }
                if summary.checklist.total > 0 {
                    Text("☑ \(summary.checklist.done)/\(summary.checklist.total)").monospacedDigit()
                }
                if let severity = decision.severity, decision.kind == .risk {
                    Text(WorkStyle.severity(severity)).foregroundStyle(severity == .high ? .red : .secondary)
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            if decision.status == .waiting {
                Text(waitingText).font(.caption).foregroundStyle(.purple).lineLimit(1)
            }
            if decision.status == .blocked || (!summary.blockers.isEmpty && decision.status.isOpen) {
                WorkTag(text: String(localized: "bloccata"), color: .red)
                    .help(summary.blockers.map(\.text).joined(separator: "\n"))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(
                model.selectedDecisionID == decision.id
                    ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(
                model.selectedDecisionID == decision.id ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2))
        )
        .overlay(alignment: .leading) {
            if let priority = decision.priority, priority == 1, decision.status.isOpen {
                RoundedRectangle(cornerRadius: 2).fill(Color.red).frame(width: 3).padding(.vertical, 6)
                    .help(WorkStyle.priority(priority))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedDecisionID = decision.id }
        .contextMenu {
            WorkStateMenu(model: model, decision: decision, mode: .manage) { askingWaiting = true }
        }
        .popover(isPresented: $askingWaiting, arrowEdge: .trailing) {
            WaitingForm(model: model, decisionID: decision.id) { askingWaiting = false }
        }
    }

    private var waitingText: String {
        let who = summary.waitingOnName ?? String(localized: "altri")
        guard let until = summary.decision.waitingUntil else { return String(localized: "attende \(who)") }
        return String(localized: "attende \(who) · entro \(WorkStyle.day(until))")
    }
}
