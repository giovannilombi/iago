import IAGOCapture
import IAGOEngine
import IAGOStore
import IAGOTranscription
import SwiftUI

/// "Attività" (ADR-0055): everything IAGO is doing, waiting to do, and did in the last 24 hours, with progress.
struct ActivityView: View {
    let model: AppModel
    @State private var queued: [Job] = []
    @State private var runningJob: Job?
    @State private var finished: [Job] = []

    private var activity: ActivityCenter { model.activity }

    /// Calls, emails and documents of each of the last 7 days (oldest first), and the transcriptions done in them.
    @State private var week: [Int] = Array(repeating: 0, count: 7)
    @State private var weekTranscriptions = 0
    @State private var archiveSize: Int64 = 0
    @State private var width: CGFloat = 1000

    /// The side column (last 7 days, ready to work) beside the lists when there is room, under them otherwise.
    private var sideBySide: Bool { width >= 1000 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(String(localized: "Attività")).font(.title2.bold())
                    DetailTiles(tiles: tiles) { key in
                        // The failed ones are among the last 24 hours.
                        withAnimation { proxy.scrollTo("activity.\(key == "failed" ? "recent" : key)", anchor: .top) }
                    }
                    if sideBySide {
                        HStack(alignment: .top, spacing: 20) {
                            lists.frame(maxWidth: 760, alignment: .leading)
                            side.frame(width: 340)
                        }
                    } else {
                        lists
                        side
                    }
                }
                .padding(20)
                .frame(maxWidth: 1140, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width
            } action: {
                width = $0
            }
        }
        .task(id: model.revision) { load() }
        .task(id: activity.runningJob) { load() }
    }

    /// The tiles of the page (ADR-0084 style): a number each, a click goes to the section.
    private var tiles: [DetailTile] {
        let running = ActivityCount.inProgress(model)
        let recent = finished.count + activity.recent.count
        let failed = finished.filter { $0.status == .failed }.count + activity.recent.filter { $0.failure != nil }.count
        return [
            DetailTile(
                key: "running", title: String(localized: "In corso"), value: "\(running)", tint: .blue,
                isEmpty: running == 0),
            DetailTile(
                key: "queued", title: String(localized: "In coda"), value: "\(queued.count)", tint: .orange,
                isEmpty: queued.isEmpty),
            DetailTile(
                key: "recent", title: String(localized: "Ultime 24 ore"), value: "\(recent)", tint: .green,
                isEmpty: recent == 0),
            DetailTile(
                key: "failed", title: String(localized: "Non riuscite"), value: "\(failed)", tint: .red,
                isEmpty: failed == 0),
        ]
    }

    private var lists: some View {
        VStack(alignment: .leading, spacing: 14) {
            let running = ActivityCount.inProgress(model)
            SectionBox(
                String(localized: "In corso"), systemImage: "gauge.with.dots.needle.67percent", tint: .blue,
                detail: running == 0 ? nil : "\(running)",
                emptyText: running == 0 ? String(localized: "Niente in corso: IAGO è libero") : nil
            ) {
                VStack(alignment: .leading, spacing: 8) { inProgress }
            }
            .id("activity.running")
            SectionBox(
                String(localized: "In coda"), systemImage: "clock", tint: .orange,
                detail: queued.isEmpty ? nil : "\(queued.count)",
                emptyText: queued.isEmpty ? String(localized: "Nessun lavoro in attesa") : nil
            ) {
                ForEach(Array(queued.enumerated()), id: \.element.id) { index, job in
                    queuedRow(job, first: index == 0)
                }
            }
            .id("activity.queued")
            let recent = finished.count + activity.recent.count
            SectionBox(
                String(localized: "Ultime 24 ore"), systemImage: "checkmark.circle", tint: .green,
                detail: recent == 0 ? nil : "\(recent)",
                emptyText: recent == 0 ? String(localized: "Nessun lavoro finito nelle ultime 24 ore") : nil
            ) {
                recentRows
            }
            .id("activity.recent")
        }
    }

    // MARK: Side column

    private var side: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionBox(String(localized: "Ultimi 7 giorni"), systemImage: "chart.bar", tint: .blue) {
                WeekBars(counts: week)
                Text(
                    String(
                        localized:
                            "\(week.reduce(0, +)) tra call, email e documenti · \(weekTranscriptions) trascrizioni")
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            SectionBox(String(localized: "Pronto per lavorare"), systemImage: "checkmark.seal", tint: .gray) {
                readiness(
                    String(localized: "Motore del Mac"), value: model.engine.activeModel?.name,
                    missing: String(localized: "non scelto"))
                readiness(String(localized: "Spazio dell'archivio"), value: Format.bytes(archiveSize), missing: "")
                readiness(
                    String(localized: "Spazio dei modelli"), value: Format.bytes(model.engine.totalDiskSize),
                    missing: "")
            }
        }
    }

    private func readiness(_ title: String, value: String?, missing: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: value == nil ? "exclamationmark.circle" : "checkmark.circle.fill")
                .foregroundStyle(value == nil ? Color.orange : Color.green)
            Text(title)
            Spacer(minLength: 8)
            Text(value ?? missing).foregroundStyle(.secondary).lineLimit(1)
        }
        .font(.callout)
    }

    @ViewBuilder
    private var inProgress: some View {
        if let recording = model.recording, recording.state != .idle { recordingRow(recording) }
        if let recording = model.recording, recording.finalizingCount > 0 {
            row(
                symbol: "tray.and.arrow.down", title: String(localized: "Salvataggio della registrazione"),
                detail: String(localized: "Le tracce vengono messe in archivio"), fraction: nil, busy: true)
        }
        if let job = runningJob { transcriptionRow(job) }
        ForEach(EngineCatalog.models + [EngineCatalog.embedding], id: \.id) { entry in
            if let progress = model.engine.progress[entry.id] {
                row(
                    symbol: "arrow.down.circle", title: String(localized: "Download di \(entry.name)"),
                    detail: Self.bytes(progress), fraction: progress.fraction
                ) {
                    Button(String(localized: "Annulla")) { model.engine.cancel(entry) }
                }
            }
        }
        if let indexing = model.intelligence.indexing, indexing.total > 0 {
            row(
                symbol: "magnifyingglass", title: String(localized: "Indicizzazione per la ricerca per significato"),
                detail: String(localized: "\(indexing.done) di \(indexing.total) elementi"),
                fraction: Double(indexing.done) / Double(indexing.total))
        }
        if let summary = model.intelligence.summarizing {
            row(
                symbol: "text.alignleft", title: String(localized: "Sintesi"), detail: "«\(summary.title)»",
                fraction: summary.fraction
            ) {
                Button(String(localized: "Apri")) { model.selectedItemID = summary.itemID }
            }
        }
        if let title = model.intelligence.proposingFor {
            row(
                symbol: "sparkles", title: String(localized: "Cerca punti chiave e proposte"),
                detail: "«\(title)»", fraction: nil, busy: true)
        }
        if model.folderImporter.scanning {
            row(
                symbol: "folder.badge.gearshape", title: String(localized: "Controllo delle cartelle sorvegliate"),
                detail: nil, fraction: nil, busy: true)
        }
        ForEach(activity.running) { work in
            row(
                symbol: work.kind.symbol, title: work.kind.label, detail: work.title.isEmpty ? nil : work.title,
                fraction: work.fraction, busy: work.fraction == nil, startedAt: work.startedAt)
        }
    }

    private func recordingRow(_ recording: RecordingController.Snapshot) -> some View {
        var details = [Format.clock(recording.elapsed)]
        if let mic = recording.micName { details.append(mic) }
        if recording.micMuted { details.append(String(localized: "mute di Teams: silenzio sulla tua traccia")) }
        return row(
            symbol: recording.state == .paused ? "pause.circle.fill" : "record.circle.fill",
            tint: recording.state == .paused ? .orange : .red,
            title: recording.state == .paused
                ? String(localized: "Registrazione in pausa") : String(localized: "Registrazione in corso"),
            detail: details.joined(separator: " · "), fraction: nil
        ) {
            Button(recording.state == .paused ? String(localized: "Riprendi") : String(localized: "Pausa")) {
                model.togglePause()
            }
            Button(String(localized: "Ferma")) { model.stopRecording() }
        }
    }

    private func transcriptionRow(_ job: Job) -> some View {
        let live = activity.runningJob?.id == job.id ? activity.runningJob : nil
        return row(
            symbol: "text.bubble", title: String(localized: "Trascrizione"), detail: itemTitle(job),
            fraction: live?.progress ?? job.progress, startedAt: live?.startedAt
        ) {
            if let itemID = job.itemId { Button(String(localized: "Apri")) { model.selectedItemID = itemID } }
            Button(String(localized: "Annulla")) { try? model.transcription.queue.cancel(job.id) }
        }
    }

    private func queuedRow(_ job: Job, first: Bool) -> some View {
        row(symbol: "clock", title: Self.jobLabel(job), detail: itemTitle(job), fraction: nil) {
            if !first {
                Button(String(localized: "Fai prima questo")) {
                    model.perform { try model.archive.prioritizeJob(job.id) }
                    load()
                }
            }
            Button(String(localized: "Annulla")) {
                try? model.transcription.queue.cancel(job.id)
                load()
            }
        }
    }

    @ViewBuilder
    private var recentRows: some View {
        ForEach(finished) { job in
            let failed = job.status == .failed
            row(
                symbol: failed
                    ? "exclamationmark.triangle.fill"
                    : job.status == .cancelled ? "xmark.circle" : "checkmark.circle.fill",
                tint: failed ? .orange : job.status == .cancelled ? .secondary : .green,
                title: Self.jobLabel(job) + " · " + Self.statusLabel(job.status),
                detail: [itemTitle(job), job.updatedAt.formatted(date: .omitted, time: .shortened)]
                    .compactMap { $0 }.joined(separator: " · ")
                    + (failed ? "\n" + (job.error ?? "") : ""),
                fraction: nil
            ) {
                if let itemID = job.itemId { Button(String(localized: "Apri")) { model.selectedItemID = itemID } }
                if failed || job.status == .cancelled, let itemID = job.itemId {
                    Button(String(localized: "Riprova")) { retry(job, itemID) }
                }
            }
        }
        ForEach(activity.recent) { work in
            row(
                symbol: work.failure == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tint: work.failure == nil ? .green : .orange,
                title: work.kind.label,
                detail: ([work.title.isEmpty ? nil : work.title, work.at.formatted(date: .omitted, time: .shortened)]
                    .compactMap { $0 }.joined(separator: " · ")) + (work.failure.map { "\n" + $0 } ?? ""),
                fraction: nil
            ) {
                if let itemID = work.itemID { Button(String(localized: "Apri")) { model.selectedItemID = itemID } }
            }
        }
        Button(String(localized: "Pulisci l'elenco")) { activity.clearRecent() }
            .buttonStyle(.link).font(.caption)
            .opacity(activity.recent.isEmpty ? 0 : 1)
    }

    // MARK: Row

    private func row(
        symbol: String, tint: Color = .accentColor, title: String, detail: String?, fraction: Double?,
        busy: Bool = false, startedAt: Date? = nil
    ) -> some View {
        row(
            symbol: symbol, tint: tint, title: title, detail: detail, fraction: fraction, busy: busy,
            startedAt: startedAt
        ) {
            EmptyView()
        }
    }

    /// `busy`: going on without a percentage (a spinner).
    private func row<Actions: View>(
        symbol: String, tint: Color = .accentColor, title: String, detail: String?, fraction: Double?,
        busy: Bool = false, startedAt: Date? = nil, @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                if let detail, !detail.isEmpty {
                    Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let fraction {
                    HStack(spacing: 8) {
                        ProgressView(value: fraction).frame(maxWidth: 320)
                        Text(Self.percent(fraction, startedAt: startedAt)).font(.caption).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } else if busy {
                    ProgressView().controlSize(.small)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) { actions() }.controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.07)))
    }

    // MARK: Data

    private func load() {
        let active = (try? model.archive.activeJobs()) ?? []
        runningJob = active.first { $0.status == .running }
        queued = active.filter { $0.status == .queued }
        finished = (try? model.archive.finishedJobs(since: Date().addingTimeInterval(-86_400))) ?? []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var counts = Array(repeating: 0, count: 7)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        for date in (try? model.archive.itemDates(since: start)) ?? [] {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? 99
            if (0..<7).contains(days) { counts[6 - days] += 1 }
        }
        week = counts
        weekTranscriptions =
            ((try? model.archive.finishedJobs(since: start, limit: 1_000)) ?? []).filter { $0.status == .done }.count
        let root = model.archiveService.paths.root
        Task {
            archiveSize = await Task.detached {
                ModelManager.diskSize(root.appendingPathComponent("Items"))
                    + ModelManager.diskSize(root.appendingPathComponent("iago.sqlite"))
            }.value
        }
    }

    private func itemTitle(_ job: Job) -> String? {
        job.itemId.flatMap { model.item($0)?.title }
    }

    private func retry(_ job: Job, _ itemID: String) {
        let payload = job.payload.flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(TranscriptionService.Payload.self, from: $0) }
        model.transcribe(itemID, deleteAudio: payload?.deleteAudio ?? false, roomMode: payload?.roomMode ?? false)
        load()
    }

    static func jobLabel(_ job: Job) -> String {
        job.type == TranscriptionService.jobType ? String(localized: "Trascrizione") : job.type
    }

    static func statusLabel(_ status: Job.Status) -> String {
        switch status {
        case .done: String(localized: "fatta")
        case .failed: String(localized: "non riuscita")
        case .cancelled: String(localized: "annullata")
        case .queued: String(localized: "in coda")
        case .running: String(localized: "in corso")
        }
    }

    /// "42%", with the time left once it can be estimated.
    static func percent(_ fraction: Double, startedAt: Date?) -> String {
        let percent = "\(Int(fraction * 100))%"
        guard let startedAt, fraction > 0.05, fraction < 1 else { return percent }
        let elapsed = Date().timeIntervalSince(startedAt)
        let left = elapsed / fraction * (1 - fraction)
        guard left.isFinite, left > 0 else { return percent }
        let minutes = Int((left / 60).rounded(.up))
        return minutes <= 1
            ? String(localized: "\(percent) · meno di un minuto")
            : String(localized: "\(percent) · circa \(minutes) min")
    }

    static func bytes(_ progress: EngineProgress) -> String {
        let speed = progress.bytesPerSecond > 0 ? " · \(Format.bytes(Int64(progress.bytesPerSecond)))/s" : ""
        return "\(Format.bytes(progress.bytes)) di \(Format.bytes(progress.total))\(speed)"
    }
}

/// The number on the sidebar entry: what is going on or waiting.
enum ActivityCount {
    @MainActor
    static func inProgress(_ model: AppModel) -> Int {
        var count = model.activity.running.count + model.engine.progress.count
        if let recording = model.recording, recording.state != .idle { count += 1 }
        if model.activity.runningJob != nil { count += 1 }
        if model.intelligence.indexing != nil { count += 1 }
        if model.intelligence.proposingFor != nil { count += 1 }
        if model.intelligence.summarizing != nil { count += 1 }
        return count
    }

    @MainActor
    static func badge(_ model: AppModel) -> Int {
        _ = model.revision
        let queued = ((try? model.archive.activeJobs()) ?? []).filter { $0.status == .queued }.count
        return inProgress(model) + queued
    }
}

/// Seven small bars, today last and in the accent colour.
private struct WeekBars: View {
    let counts: [Int]

    var body: some View {
        let top = max(counts.max() ?? 0, 1)
        let calendar = Calendar.current
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                let day = calendar.date(byAdding: .day, value: index - 6, to: Date()) ?? Date()
                VStack(spacing: 4) {
                    Text("\(count)").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index == 6 ? Color.accentColor : Color.accentColor.opacity(0.35))
                        .frame(width: 18, height: max(4, 64 * CGFloat(count) / CGFloat(top)))
                    Text(index == 6 ? String(localized: "oggi") : day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 100, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized:
                    "Call, email e documenti negli ultimi 7 giorni: \(counts.map(String.init).joined(separator: ", "))")
        )
    }
}
