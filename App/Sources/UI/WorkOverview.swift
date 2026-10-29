import AppKit
import IAGOEngine
import IAGOIntelligence
import IAGOStore
import SwiftUI

/// «Riepilogo» of a project, client or stream (ADR-0074, ADR-0076). «Traccia»: the short version, one column with what
/// to do, what to keep an eye on and the latest decisions and milestones. «Gestisci»: state and progress, what changed
/// since the last visit, risks by severity, points to clear up, waits, and a written status report.
struct WorkOverview: View {
    @Bindable var model: AppModel
    let scope: BoardScope
    @State private var entries: [DecisionSummary] = []
    @State private var checklists: [Checklist] = []
    /// When this overview was opened before this time (nil: never).
    @State private var lastSeen: Date?
    @State private var seenLoaded = false

    private var mode: WorkMode { model.workViewsMode(for: scope.query) }
    /// The project new checklists go in: the project, or the stream's.
    private var projectID: String? {
        switch scope {
        case .project(let id): id
        case .stream(let id): model.stream(id)?.projectId
        default: nil
        }
    }
    private var spansProjects: Bool { if case .client = scope { true } else { false } }

    /// Width of the page: two columns when there is room (ADR-0075), one below it.
    @State private var width: CGFloat = 1000
    private var twoColumns: Bool { width >= 860 }

    var body: some View {
        ScrollView {
            if mode == .track { brief } else { full }
        }
        .safeAreaInset(edge: .top, spacing: 0) { ViewModePicker(model: model).background(.bar) }
        .task(id: model.revision) { load() }
        .task(id: scope.key) { markSeen() }
    }

    /// «Riepilogo breve» (ADR-0076): «Da fare», «Da tenere d'occhio», «Ultime decisioni e tappe»; an empty block is
    /// left out.
    private var brief: some View {
        let actions = open.filter { $0.decision.kind == .action }
            .sorted { ($0.decision.dueAt ?? .distantFuture) < ($1.decision.dueAt ?? .distantFuture) }
        let watch = open.filter { $0.decision.kind != .action }
            .sorted { ($0.decision.dueAt ?? $0.decision.decidedAt) < ($1.decision.dueAt ?? $1.decision.decidedAt) }
        let latest = Array(recentMemory.prefix(5))
        return VStack(alignment: .leading, spacing: 16) {
            if !actions.isEmpty {
                card(
                    String(localized: "Da fare"), count: actions.count, icon: "checklist", tint: WorkStyle.tint(.action)
                ) {
                    rows(actions)
                }
            }
            if !watch.isEmpty {
                card(String(localized: "Da tenere d'occhio"), count: watch.count, icon: "eye", tint: .purple) {
                    rows(watch)
                }
            }
            if !latest.isEmpty {
                card(
                    String(localized: "Ultime decisioni e tappe"), count: latest.count, icon: "checkmark.seal",
                    tint: .green
                ) { rows(latest) }
            }
            if actions.isEmpty && watch.isEmpty && latest.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Niente da fare, per ora"), systemImage: "checkmark.circle")
                } description: {
                    Text(
                        String(
                            localized:
                                "Qui compaiono le attività aperte, i rischi, le domande e le richieste del progetto, e le ultime decisioni. Aggiungili con «Aggiungi»."
                        ))
                }
                .padding(.top, 40)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 20)
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    /// The complete page of «Gestisci».
    private var full: some View {
        VStack(alignment: .leading, spacing: 16) {
            numbers
            if twoColumns {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) { actionCards }.frame(maxWidth: .infinity)
                    VStack(spacing: 16) { contextCards }.frame(width: min(440, width * 0.4))
                }
            } else {
                VStack(spacing: 16) {
                    actionCards
                    contextCards
                }
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 20)
        .frame(maxWidth: 1400, alignment: .leading)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            width = $0
        }
    }

    /// Left: what to act on, most urgent first.
    @ViewBuilder
    private var actionCards: some View {
        let overdue = open.filter { OpenWork.due($0.decision.dueAt) == .overdue && $0.decision.status != .waiting }
        let blocked = open.filter { $0.decision.status == .blocked }
        card(
            String(localized: "Scadenze"), count: nextDue.count, icon: "calendar",
            tint: overdue.isEmpty ? .accentColor : .red,
            empty: String(localized: "Nessuna voce aperta con una scadenza.")
        ) { rows(nextDue) }
        if mode == .manage, !blocked.isEmpty {
            card(String(localized: "Bloccate"), count: blocked.count, icon: "nosign", tint: .red) { rows(blocked) }
        }
        if !waiting.isEmpty {
            card(String(localized: "Attese da altri"), count: waiting.count, icon: "hourglass", tint: .purple) {
                rows(waiting)
            }
        }
        let questions = open.filter { $0.decision.kind == .openQuestion && $0.decision.status != .waiting }
        let risks = open.filter { $0.decision.kind == .risk }
        HStack(alignment: .top, spacing: 16) {
            card(
                String(localized: "Rischi"), count: risks.count, icon: WorkStyle.icon(.risk),
                tint: WorkStyle.tint(.risk),
                empty: String(localized: "Nessun rischio aperto."), fills: true
            ) { riskRows(risks) }
            card(
                String(localized: "Punti da chiarire"), count: questions.count, icon: WorkStyle.icon(.openQuestion),
                tint: WorkStyle.tint(.openQuestion), empty: String(localized: "Nessuna domanda in sospeso."),
                fills: true
            ) { rows(questions) }
        }
        .fixedSize(horizontal: false, vertical: true)
        if mode == .manage, !nextMilestones.isEmpty {
            card(String(localized: "Prossime tappe"), count: nextMilestones.count, icon: "flag", tint: .teal) {
                rows(nextMilestones)
            }
        }
    }

    /// Right: what changed, the written status, the checklists.
    @ViewBuilder
    private var contextCards: some View {
        if mode == .manage {
            card(String(localized: "Cosa è cambiato"), icon: "clock.arrow.circlepath", tint: .secondary) { changes }
            card(String(localized: "Sintesi di stato"), icon: "text.quote", tint: .indigo) {
                StatusReportBox(model: model, scope: scope, entries: entries)
            }
        } else {
            card(
                String(localized: "Decisioni e tappe recenti"), count: recentMemory.count, icon: "checkmark.seal",
                tint: .green, empty: String(localized: "Nessuna decisione o tappa recente.")
            ) { rows(recentMemory) }
        }
        card(
            String(localized: "Checklist"), count: checklists.isEmpty ? nil : checklists.count, icon: "checklist",
            tint: .accentColor
        ) {
            checklistSection
        } accessory: {
            if let projectID { NewChecklistButton(model: model, projectID: projectID) }
        }
    }

    /// A block of the page: title, count and action on one line, then its content.
    private func card<Content: View, Accessory: View>(
        _ title: String, count: Int? = nil, icon: String, tint: Color, empty: String? = nil, fills: Bool = false,
        @ViewBuilder content: () -> Content, @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.headline)
                if let count, count > 0 {
                    Text("\(count)").font(.callout).monospacedDigit().foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                accessory()
            }
            if let empty, count == 0 {
                Text(empty).font(.callout).foregroundStyle(.secondary)
            } else {
                content()
            }
        }
        .padding(14)
        // Side by side, two cards take the height of the taller one.
        .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
    }

    private func rows(_ shown: [DecisionSummary]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(shown) { summary in
                WorkEntryRow(model: model, summary: summary, mode: mode, showsProject: spansProjects)
                    .padding(.horizontal, -8)
            }
        }
    }

    /// Highest severity first; each row says its severity.
    private func riskRows(_ risks: [DecisionSummary]) -> some View {
        func rank(_ severity: Decision.Severity?) -> Int {
            switch severity {
            case .high: 0
            case .medium: 1
            case .low: 2
            case nil: 3
            }
        }
        return rows(risks.sorted { rank($0.decision.severity) < rank($1.decision.severity) })
    }

    // MARK: Data

    private var open: [DecisionSummary] { entries.filter { $0.decision.kind.isWork && $0.decision.status.isOpen } }

    private var waiting: [DecisionSummary] {
        open.filter { $0.decision.status == .waiting }
            .sorted { ($0.decision.waitingUntil ?? .distantFuture) < ($1.decision.waitingUntil ?? .distantFuture) }
    }

    private var nextDue: [DecisionSummary] {
        Array(
            open.filter { $0.decision.dueAt != nil && $0.decision.status != .waiting }
                .sorted { $0.decision.dueAt! < $1.decision.dueAt! }.prefix(8))
    }

    private var recentMemory: [DecisionSummary] {
        Array(
            entries.filter {
                !$0.decision.kind.isWork && $0.decision.status == .active && $0.decision.decidedAt <= Date()
            }
            .sorted { $0.decision.decidedAt > $1.decision.decidedAt }.prefix(6))
    }

    private var nextMilestones: [DecisionSummary] {
        let today = Calendar.current.startOfDay(for: Date())
        return Array(
            entries.filter {
                $0.decision.kind == .milestone && $0.decision.status == .active && $0.decision.decidedAt >= today
            }
            .sorted { $0.decision.decidedAt < $1.decision.decidedAt }.prefix(5))
    }

    private func load() {
        entries = (try? model.archive.decisions(DecisionQuery(scope: scope.query, statuses: []))) ?? []
        switch scope {
        case .project, .stream:
            checklists = projectID.flatMap { try? model.archive.checklists(projectID: $0) } ?? []
        case .client(let id):
            let projects = Set(model.projects.filter { $0.clientId == id }.map(\.id))
            checklists = ((try? model.archive.checklists()) ?? []).filter { projects.contains($0.projectId) }
        case .all:
            checklists = (try? model.archive.checklists(pinnedOnly: true)) ?? []
        }
    }

    /// «Cosa è cambiato»: since the previous visit; this visit is remembered for the next one.
    private func markSeen() {
        let key = "work.overview.seen.\(scope.key)"
        lastSeen = ((try? model.archive.setting(key)) ?? nil).flatMap(Double.init).map(
            Date.init(timeIntervalSince1970:))
        seenLoaded = true
        model.perform { try model.archive.setSetting(key, String(Date().timeIntervalSince1970)) }
    }

    // MARK: Numbers

    /// One row across the page: open and closed per kind, then late and blocked.
    private var numbers: some View {
        let overdue = open.filter { OpenWork.due($0.decision.dueAt) == .overdue && $0.decision.status != .waiting }
        return HStack(spacing: 10) {
            ForEach(Decision.Kind.work, id: \.self) { kind in
                let all = entries.filter { $0.decision.kind == kind && $0.decision.status != .cancelled }
                let openCount = all.filter { $0.decision.status.isOpen }.count
                tile(
                    WorkStyle.plural(kind), openCount, icon: WorkStyle.icon(kind), tint: WorkStyle.tint(kind),
                    detail: String(localized: "aperte · \(all.count - openCount) chiuse"),
                    progress: mode == .manage && !all.isEmpty ? Double(all.count - openCount) / Double(all.count) : nil)
            }
            tile(
                String(localized: "In ritardo"), overdue.count, icon: "clock.badge.exclamationmark",
                tint: overdue.isEmpty ? .secondary : .red, detail: String(localized: "scadenze passate"))
            if mode == .manage {
                let blocked = open.filter { $0.decision.status == .blocked }.count
                tile(
                    String(localized: "Bloccate"), blocked, icon: "nosign", tint: blocked == 0 ? .secondary : .red,
                    detail: String(localized: "aspettano altre voci"))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tile(
        _ title: String, _ count: Int, icon: String, tint: Color, detail: String, progress: Double? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
            }
            Text("\(count)").font(.title.weight(.semibold)).monospacedDigit()
                .foregroundStyle(count == 0 ? .secondary : .primary)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            if let progress {
                ProgressView(value: progress).tint(tint).controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
    }

    @ViewBuilder
    private var changes: some View {
        if seenLoaded {
            VStack(alignment: .leading, spacing: 2) {
                if let lastSeen {
                    let created = entries.filter { $0.decision.createdAt > lastSeen }
                    let closed = entries.filter {
                        ($0.decision.closedAt ?? .distantPast) > lastSeen && $0.decision.createdAt <= lastSeen
                    }
                    let updated = entries.filter {
                        $0.decision.updatedAt > lastSeen && $0.decision.createdAt <= lastSeen
                            && ($0.decision.closedAt ?? .distantPast) <= lastSeen
                    }
                    Text(
                        String(
                            localized:
                                "Dall'ultima volta che hai aperto il riepilogo, \(lastSeen.formatted(date: .abbreviated, time: .shortened))."
                        )
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if created.isEmpty && closed.isEmpty && updated.isEmpty {
                        Text(String(localized: "Nulla di nuovo.")).font(.callout).foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    changeGroup(String(localized: "Nuove"), created)
                    changeGroup(String(localized: "Chiuse"), closed)
                    changeGroup(String(localized: "Aggiornate"), updated)
                } else {
                    Text(String(localized: "È la prima volta che apri questo riepilogo: da ora qui vedi cosa cambia."))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func changeGroup(_ title: String, _ shown: [DecisionSummary]) -> some View {
        if !shown.isEmpty {
            Text("\(title) (\(shown.count))").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.top, 6)
            rows(Array(shown.prefix(10)))
        }
    }

    // MARK: Checklists

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if checklists.isEmpty {
                Text(
                    projectID == nil
                        ? String(localized: "Nessuna checklist nei progetti di questo cliente.")
                        : String(
                            localized:
                                "Liste da spuntare del progetto, per esempio «Consegna finale». Fissate, compaiono anche in «Inbox»."
                        )
                )
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(checklists) { list in
                ChecklistCard(model: model, checklist: list, showsProject: spansProjects)
            }
        }
    }
}

// MARK: - Status report

/// «Sintesi di stato»: written by the local engine from the key points of the scope only, each line checked against
/// them (ADR-0054); copied as text for an email, or asked to Claude with «Copia per Claude».
private struct StatusReportBox: View {
    let model: AppModel
    let scope: BoardScope
    let entries: [DecisionSummary]
    @State private var report: Stored?
    @State private var failure: String?
    @State private var copied: String?
    @State private var showsDropped = false

    struct Stored: Codable {
        var text: String
        var dropped: [String]
        var model: String
        var at: Date
    }

    private var key: String { "work.overview.report.\(scope.key)" }
    private var name: String { model.workScopeName(scope) }
    private var running: Bool {
        model.activity.running.contains { $0.kind == .statusReport && $0.title == name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized:
                        "Un testo breve sullo stato, da copiare in una mail. Il motore del Mac lo scrive solo dai punti chiave e IAGO toglie le frasi che non trovano riscontro."
                )
            )
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if running {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "Sto scrivendo la sintesi di stato… la trovi anche in Attività."))
                        .font(.callout)
                }
            } else if let report {
                Text(report.text).font(.callout).textSelection(.enabled)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.indigo.opacity(0.06)))
                HStack(spacing: 12) {
                    Text(
                        String(
                            localized:
                                "\(report.model) · \(report.at.formatted(date: .abbreviated, time: .shortened))")
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if !report.dropped.isEmpty {
                        Button(String(localized: "\(report.dropped.count) frasi tolte")) { showsDropped.toggle() }
                            .font(.caption)
                            .popover(isPresented: $showsDropped) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(String(localized: "Tolte perché non citano punti chiave esistenti"))
                                        .font(.headline)
                                    ForEach(report.dropped, id: \.self) { Text($0).font(.callout) }
                                }
                                .padding(14).frame(maxWidth: 420)
                            }
                    }
                    Spacer(minLength: 8)
                    Button(copied == "text" ? String(localized: "Copiata") : String(localized: "Copia")) {
                        put(report.text, as: "text")
                    }
                }
                .buttonStyle(.link)
            }
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
            HStack(spacing: 14) {
                Button(report == nil ? String(localized: "Scrivi la sintesi di stato") : String(localized: "Riscrivi"))
                {
                    generate()
                }
                .buttonStyle(.borderedProminent).tint(.indigo).disabled(running)
                Button(
                    copied == "claude"
                        ? String(localized: "Copiato: incollalo in Claude") : String(localized: "Copia per Claude")
                ) {
                    put(claudeRequest, as: "claude")
                }
                .buttonStyle(.link)
                .help(String(localized: "Riferimento e richiesta pronti, perché Claude scriva la sintesi da IAGO"))
            }
        }
        .task(id: "\(model.revision)-\(scope.key)") {
            report = ((try? model.archive.setting(key)) ?? nil).flatMap {
                try? JSONDecoder().decode(Stored.self, from: Data($0.utf8))
            }
        }
    }

    private func generate() {
        failure = nil
        let facts = StatusReport.facts(entries, now: Date())
        guard !facts.isEmpty else {
            failure = String(localized: "Non ci sono punti chiave aperti o recenti da riassumere.")
            return
        }
        guard let engine = model.engine.engine(for: .summary) else { return }
        let name = self.name
        let key = self.key
        let model = self.model
        Task {
            do {
                let result = try await model.activity.track(.statusReport, name) { _ in
                    // The user is waiting: before background work in the engine lane (ADR-0069).
                    try await EngineLane.$interactive.withValue(true) {
                        try await StatusReport.generate(scopeName: name, facts: facts, now: Date(), with: engine)
                    }
                }
                guard !result.text.isEmpty else {
                    failure = String(localized: "Il motore non ha scritto frasi verificabili: riprova.")
                    return
                }
                let stored = Stored(text: result.text, dropped: result.dropped, model: engine.modelName, at: Date())
                let json = String(decoding: try JSONEncoder().encode(stored), as: UTF8.self)
                model.perform { try model.archive.setSetting(key, json) }
                report = stored
            } catch is CancellationError {
            } catch {
                failure = ErrorText.describe(error)
            }
        }
    }

    /// What Claude needs to write the report itself through IAGO's tools (ADR-0071).
    private var claudeRequest: String {
        let place: String
        switch scope {
        case .project(let id):
            place = String(localized: "Progetto di IAGO: «\(name)»") + "\nproject_id: \(id)"
        case .client(let id):
            place = String(localized: "Cliente di IAGO: «\(name)»") + "\nclient_id: \(id)"
        case .stream(let id):
            let project = model.stream(id).flatMap { model.project($0.projectId)?.name } ?? ""
            place = String(localized: "Stream di IAGO: «\(name)» del progetto «\(project)»") + "\nstream_id: \(id)"
        case .all:
            place = String(localized: "Tutti i progetti di IAGO")
        }
        return place + "\n"
            + String(
                localized:
                    "Scrivi una sintesi di stato da mandare per mail: leggi i punti chiave con list_decisions (aperti, chiusi di recente, rischi, punti da chiarire, attese, scadenze) e, se serve, le ultime call con get_item. Usa solo fatti presenti in IAGO: In breve, Avanzamento, Rischi e punti aperti, Prossimi passi."
            )
    }

    private func put(_ text: String, as what: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = what
        Task {
            try? await Task.sleep(for: .seconds(3))
            copied = nil
        }
    }
}
