import AppKit
import IAGOEngine
import IAGOIntelligence
import IAGOStore
import SwiftUI

/// «Riepilogo» of a project, client or stream (ADR-0074). «Traccia»: the short version (open entries by kind, next
/// due dates, recent decisions and milestones, checklists). «Gestisci»: state and progress, what changed since the
/// last visit, risks by severity, points to clear up, waits, and a written status report.
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if mode == .manage {
                    progress
                    changes
                    risks
                    list(
                        String(localized: "Punti da chiarire"),
                        open.filter { $0.decision.kind == .openQuestion && $0.decision.status != .waiting })
                    list(String(localized: "Attese da altri"), waiting)
                    list(String(localized: "Prossime scadenze"), nextDue)
                    StatusReportBox(model: model, scope: scope, entries: entries)
                } else {
                    openByKind
                    list(String(localized: "Prossime scadenze"), nextDue)
                    list(String(localized: "Attese da altri"), waiting)
                    list(String(localized: "Decisioni e tappe recenti"), recentMemory)
                }
                checklistSection
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) { ViewModePicker(model: model).background(.bar) }
        .task(id: model.revision) { load() }
        .task(id: scope.key) { markSeen() }
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

    // MARK: Traccia

    private var openByKind: some View {
        VStack(alignment: .leading, spacing: 8) {
            WorkSectionTitle(title: String(localized: "Aperte"), count: open.count)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Decision.Kind.work, id: \.self) { kind in
                    countTile(
                        WorkStyle.plural(kind), open.filter { $0.decision.kind == kind }.count,
                        icon: WorkStyle.icon(kind), tint: WorkStyle.tint(kind))
                }
                let overdue = open.filter {
                    OpenWork.due($0.decision.dueAt) == .overdue && $0.decision.status != .waiting
                }
                if !overdue.isEmpty {
                    countTile(
                        String(localized: "In ritardo"), overdue.count, icon: "clock.badge.exclamationmark", tint: .red)
                }
            }
        }
    }

    private func countTile(_ title: String, _ count: Int, icon: String, tint: Color, detail: String? = nil)
        -> some View
    {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text("\(count)").font(.title2.weight(.semibold)).monospacedDigit()
                .foregroundStyle(count == 0 ? .secondary : .primary)
            if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(minWidth: 110, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15)))
    }

    @ViewBuilder
    private func list(_ title: String, _ shown: [DecisionSummary]) -> some View {
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                WorkSectionTitle(title: title, count: shown.count)
                ForEach(shown) { summary in
                    WorkEntryRow(model: model, summary: summary, mode: mode, showsProject: spansProjects)
                }
            }
        }
    }

    // MARK: Gestisci

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            WorkSectionTitle(title: String(localized: "Stato e avanzamento"))
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Decision.Kind.work, id: \.self) { kind in
                    let all = entries.filter { $0.decision.kind == kind && $0.decision.status != .cancelled }
                    let openCount = all.filter { $0.decision.status.isOpen }.count
                    let closedCount = all.count - openCount
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: WorkStyle.icon(kind)).foregroundStyle(WorkStyle.tint(kind))
                            Text(WorkStyle.plural(kind)).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(String(localized: "\(openCount) aperte · \(closedCount) chiuse")).font(.callout)
                            .monospacedDigit()
                        ProgressView(value: all.isEmpty ? 0 : Double(closedCount) / Double(all.count))
                            .tint(WorkStyle.tint(kind)).frame(width: 130)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15)))
                }
                let overdue = open.filter {
                    OpenWork.due($0.decision.dueAt) == .overdue && $0.decision.status != .waiting
                }
                countTile(
                    String(localized: "In ritardo"), overdue.count, icon: "clock.badge.exclamationmark", tint: .red)
                countTile(
                    String(localized: "Bloccate"), open.filter { $0.decision.status == .blocked }.count,
                    icon: "nosign", tint: .red)
            }
            if !nextMilestones.isEmpty {
                Text(String(localized: "Prossime tappe")).font(.subheadline.weight(.semibold)).padding(.top, 4)
                ForEach(nextMilestones) { summary in
                    WorkEntryRow(model: model, summary: summary, mode: mode, showsProject: spansProjects)
                }
            }
        }
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
                    WorkSectionTitle(title: String(localized: "Cosa è cambiato"))
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
                    WorkSectionTitle(title: String(localized: "Cosa è cambiato"))
                    Text(String(localized: "È la prima volta che apri questo riepilogo: da ora qui vedi cosa cambia."))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func changeGroup(_ title: String, _ shown: [DecisionSummary]) -> some View {
        if !shown.isEmpty {
            Text("\(title) (\(shown.count))").font(.subheadline.weight(.semibold)).padding(.top, 6)
            ForEach(shown.prefix(10)) { summary in
                WorkEntryRow(model: model, summary: summary, mode: mode, showsProject: spansProjects)
            }
        }
    }

    @ViewBuilder
    private var risks: some View {
        let risks = open.filter { $0.decision.kind == .risk }
        if !risks.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                WorkSectionTitle(title: String(localized: "Rischi"), count: risks.count)
                ForEach([Decision.Severity?.some(.high), .some(.medium), .some(.low), .none], id: \.self) { severity in
                    let shown = risks.filter { $0.decision.severity == severity }
                    if !shown.isEmpty {
                        Text(
                            severity.map { String(localized: "Gravità \(WorkStyle.severity($0))") }
                                ?? String(localized: "Gravità non indicata")
                        )
                        .font(.subheadline.weight(.semibold)).foregroundStyle(severity == .high ? .red : .secondary)
                        .padding(.top, 6)
                        ForEach(shown) { summary in
                            WorkEntryRow(model: model, summary: summary, mode: mode, showsProject: spansProjects)
                        }
                    }
                }
            }
        }
    }

    // MARK: Checklists

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WorkSectionTitle(
                    title: String(localized: "Checklist"), count: checklists.isEmpty ? nil : checklists.count)
                Spacer()
                if let projectID { NewChecklistButton(model: model, projectID: projectID).padding(.top, 14) }
            }
            if checklists.isEmpty {
                Text(
                    projectID == nil
                        ? String(localized: "Nessuna checklist nei progetti di questo cliente.")
                        : String(
                            localized:
                                "Liste da spuntare del progetto, per esempio «Consegna finale». Fissate, compaiono anche in «Da fare»."
                        )
                )
                .font(.callout).foregroundStyle(.secondary)
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
            HStack {
                WorkSectionTitle(title: String(localized: "Sintesi di stato"))
                Spacer()
            }
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
