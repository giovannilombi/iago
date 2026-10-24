import IAGOCapture
import IAGOEngine
import IAGOStore
import SwiftUI

/// "Attività" (ADR-0055): everything IAGO is doing, waiting to do, and did in the last 24 hours, with progress.
struct ActivityView: View {
    let model: AppModel
    @State private var queued: [Job] = []
    @State private var runningJob: Job?
    @State private var finished: [Job] = []

    private var activity: ActivityCenter { model.activity }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(String(localized: "Attività")).font(.title2.bold())
                group(String(localized: "In corso"), empty: String(localized: "Niente in corso.")) {
                    inProgress
                }
                if !queued.isEmpty {
                    group(String(localized: "In coda"), empty: "") {
                        ForEach(Array(queued.enumerated()), id: \.element.id) { index, job in
                            queuedRow(job, first: index == 0)
                        }
                    }
                }
                if !finished.isEmpty || !activity.recent.isEmpty {
                    group(String(localized: "Ultime 24 ore"), empty: "") { recentRows }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: model.revision) { load() }
        .task(id: activity.runningJob) { load() }
    }

    // MARK: Groups

    private func group<Content: View>(_ title: String, empty: String, @ViewBuilder _ content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            if !empty.isEmpty, ActivityCount.inProgress(model) == 0 {
                Text(empty).font(.callout).foregroundStyle(.secondary)
            }
        }
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
