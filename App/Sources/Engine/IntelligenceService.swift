import Foundation
import IAGOCapture
import IAGOCore
import IAGOEngine
import IAGOExport
import IAGOIntelligence
import IAGOStore
import Observation
import os

/// The background work of blocks 4 and 5 (ADR-0049): indexes what has text for the search by meaning, and proposes
/// decisions, activities, speaker names, tags, project and links for new items. One thing at a time; nothing runs
/// while a call is being recorded or while the user is waiting for a chat answer.
@MainActor
@Observable
final class IntelligenceService {
    private let archive: Archive
    private let engine: EngineService
    private let recorder: RecordingController
    private let notifier: Notifier
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "intelligence")
    let cache = VectorCache()

    /// Indexing in progress: done and total, for the menu bar and Settings.
    private(set) var indexing: (done: Int, total: Int)?
    /// The item whose proposals are being prepared.
    private(set) var proposingFor: String?
    /// Bumped when proposals change, so views reload them.
    private(set) var revision = 0
    /// Set while a chat answer is being written: background work waits.
    var chatBusy = false
    /// The summary being written and how far (ADR-0054).
    private(set) var summarizing: (itemID: String, title: String, fraction: Double)?
    /// Why the last summary of an item failed, shown in its box.
    private(set) var summaryFailures: [String: String] = [:]
    @ObservationIgnored private var summaryRequests: [String] = []
    @ObservationIgnored private var wake: AsyncStream<Void>.Continuation?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var manual: [String] = []
    /// Something was done in this round: on Macs with little memory the models are freed at its end (ADR-0069).
    @ObservationIgnored private var worked = false

    static let autoKey = "intelligence.autoSuggest"
    static let autoSummaryKey = "summaries.auto"
    static let byClaudeKey = "intelligence.byClaude"
    static let sinceKey = "intelligence.since"
    static func doneKey(_ itemID: String) -> String { "intelligence.suggested.\(itemID)" }
    static let summarySinceKey = "summaries.since"
    static func summaryDoneKey(_ itemID: String) -> String { "summaries.done.\(itemID)" }

    init(archive: Archive, engine: EngineService, recorder: RecordingController, notifier: Notifier) {
        self.archive = archive
        self.engine = engine
        self.recorder = recorder
        self.notifier = notifier
    }

    /// "Proponi automaticamente". Until the user chooses, on only on Macs with 32 GB or more (ADR-0069): the default
    /// is worked out on each Mac and never saved, because the archive can move to another Mac.
    var autoSuggest: Bool {
        get {
            !byClaude
                && (Self.choice(archive, Self.autoKey) ?? EnginePolicy.automaticWorkByDefault(ramGB: EnginePolicy.ramGB))
        }
        set {
            try? archive.setSetting(Self.autoKey, newValue ? "1" : "0")
            poke()
        }
    }

    /// "Sintesi automatiche" after each transcription, with the same default as the proposals (ADR-0069).
    var autoSummarize: Bool {
        get {
            !byClaude
                && (Self.choice(archive, Self.autoSummaryKey)
                    ?? EnginePolicy.automaticWorkByDefault(ramGB: EnginePolicy.ramGB))
        }
        set {
            try? archive.setSetting(Self.autoSummaryKey, newValue ? "1" : "0")
            poke()
        }
    }

    /// «Sintesi e proposte fatte da: Claude» (ADR-0071, ADR-0078): the engine of the Mac never starts by itself, and
    /// the item offers «Chiedi a Claude». Saved in the archive, like the other choices about the work.
    var byClaude: Bool {
        get {
            _ = revision
            return Self.choice(archive, Self.byClaudeKey) ?? false
        }
        set {
            try? archive.setSetting(Self.byClaudeKey, newValue ? "1" : "0")
            revision += 1
            poke()
        }
    }

    /// The user turned it on or off; nil: never chosen.
    private static func choice(_ archive: Archive, _ key: String) -> Bool? {
        switch (try? archive.setting(key)).flatMap({ $0 }) {
        case "1": true
        case "0": false
        default: nil
        }
    }

    func start() {
        guard loop == nil else { return }
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        wake = continuation
        loop = Task { [weak self] in
            var iterator = stream.makeAsyncIterator()
            while !Task.isCancelled {
                // A mandatory update past its margin (ADR-0056): no new background jobs either.
                if self?.isBlocked?() != true { await self?.runOnce() }
                // Work again when something changes, or every minute.
                // Cancelled when woken earlier: it must not yield then, or each round would wake the next one at
                // once and the loop would never rest.
                let timeout = Task {
                    guard (try? await Task.sleep(for: .seconds(60))) != nil else { return }
                    continuation.yield()
                }
                _ = await iterator.next()
                timeout.cancel()
            }
        }
    }

    /// True when new jobs must wait: a mandatory update past its margin (ADR-0056). Set by the app model.
    @ObservationIgnored var isBlocked: (() -> Bool)?

    /// Something changed (a transcription, an import, an engine): look for work.
    func poke() { wake?.yield() }

    /// "Cerca proposte" on one item, also an old one.
    func suggestNow(_ itemID: String) {
        guard engine.engine(for: .suggestions) != nil, !(isBlocked?() ?? false) else { return }
        if !manual.contains(itemID) { manual.append(itemID) }
        poke()
    }

    /// "Genera sintesi" / "Rigenera": also for an old item, whatever was tried before.
    func summarize(_ itemID: String) {
        guard engine.engine(for: .summary) != nil, !(isBlocked?() ?? false) else { return }
        summaryFailures[itemID] = nil
        if !summaryRequests.contains(itemID) { summaryRequests.append(itemID) }
        poke()
    }

    /// Waiting to be written (asked, not started yet).
    func isSummaryQueued(_ itemID: String) -> Bool { summaryRequests.contains(itemID) }

    /// The template of a category: the user's version, or the one of the library (ADR-0054).
    static func template(for category: IAGOStore.Category?) -> SummaryTemplate? {
        guard let category else { return nil }
        if let json = category.templateJson, var custom = SummaryTemplate.parse(json) {
            custom.id = category.templateId ?? ""
            return custom
        }
        return SummaryLibrary.template(category.templateId)
    }

    // MARK: Work

    private func runOnce() async {
        worked = false
        defer {
            if worked, EnginePolicy.freesModelAfterBackgroundWork(ramGB: EnginePolicy.ramGB) {
                Task { await engine.freeModels() }
            }
        }
        // ADR-0049 (amended): temporary conversations go after 48 hours.
        if let removed = try? archive.purgeExpiredConversations(), removed > 0 { revision += 1 }
        if let embedder = engine.embedder { await index(with: embedder) }
        if let chat = engine.currentEngine {
            if (try? archive.setting(Self.sinceKey)) == nil {
                // Automatic proposals start with the engine: older items get them only on request.
                try? archive.setSetting(Self.sinceKey, ISO8601DateFormatter().string(from: Date()))
            }
            await propose(with: chat)
            if (try? archive.setting(Self.summarySinceKey)) == nil {
                // Automatic summaries start now: older items get them on request.
                try? archive.setSetting(Self.summarySinceKey, ISO8601DateFormatter().string(from: Date()))
            }
            // Summaries need a 9B model or more (ADR-0054): with the 4B they are not written.
            if let summaries = engine.currentEngine(for: .summary) { await summarize(with: summaries) }
        }
    }

    /// A project in «Raccogli» on a Mac with 16 GB or less gets summaries only when the user asks, or from Claude
    /// (ADR-0098): an archive can hold many recordings, and each summary takes the Mac for minutes.
    static func summarizesByItself(projectMode: WorkMode, ramGB: Int = EnginePolicy.ramGB) -> Bool {
        projectMode != .collect || ramGB > 16
    }

    /// Items asked by hand, and new transcribed items whose category has a template (ADR-0054).
    private func summarize(with chat: any LLMProvider) async {
        var queue: [String] = []
        if autoSummarize,
            let since = (try? archive.setting(Self.summarySinceKey)).flatMap({ $0 }).flatMap(
                ISO8601DateFormatter().date(from:))
        {
            let categories = Dictionary(
                uniqueKeysWithValues: ((try? archive.categories(includeArchived: true)) ?? []).map { ($0.id, $0) })
            let summarized = (try? archive.summarizedItemIDs()) ?? []
            queue = ((try? archive.summaries(.recent)) ?? [])
                .filter { summary in
                    Self.summarizesByItself(projectMode: archive.workMode(projectID: summary.item.projectId))
                        && summary.item.createdAt >= since && summary.hasTranscript && !summarized.contains(summary.id)
                        && Self.template(for: summary.item.categoryId.flatMap { categories[$0] }) != nil
                        && (try? archive.setting(Self.summaryDoneKey(summary.id))) == nil
                }
                .map(\.id)
        }
        while !summaryRequests.isEmpty || !queue.isEmpty {
            guard await waitUntilFree() else { return }
            let asked = !summaryRequests.isEmpty
            let itemID = asked ? summaryRequests.removeFirst() : queue.removeFirst()
            queue.removeAll { $0 == itemID }
            worked = true
            await writeSummary(itemID, with: chat, asked: asked)
        }
    }

    /// `asked`: the user asked for it ("Genera sintesi", or "Rigenera" confirmed), so it may replace what is there.
    private func writeSummary(_ itemID: String, with chat: any LLMProvider, asked: Bool) async {
        guard let item = try? archive.item(itemID) else { return }
        let category = item.categoryId.flatMap { try? archive.category($0) }
        guard let template = Self.template(for: category) else {
            summaryFailures[itemID] = String(localized: "La categoria non ha un modello di sintesi.")
            revision += 1
            return
        }
        guard let input = try? input(for: item), !input.lines.isEmpty else {
            summaryFailures[itemID] = String(localized: "Non c'è ancora un testo da riassumere.")
            revision += 1
            return
        }
        summarizing = (itemID, item.title, 0)
        defer { summarizing = nil }
        let participants = Set(input.speakers.values).filter(DecisionDraft.isPersonName).sorted()
        do {
            let result = try await SummaryGenerator.generate(
                .init(
                    lines: input.lines, template: template, date: item.occurredAt, participants: participants,
                    title: item.title), with: chat
            ) { fraction in
                Task { @MainActor [weak self] in
                    if self?.summarizing?.itemID == itemID { self?.summarizing?.fraction = fraction }
                }
            }
            // An automatic summary takes minutes: one written meanwhile by Claude or edited by hand stays (ADR-0071).
            if !asked, let current = try archive.summary(itemID: itemID), current.origin == .claude || current.edited {
                try? archive.setSetting(Self.summaryDoneKey(itemID), "kept")
                return
            }
            try archive.saveSummary(
                itemID: itemID, categoryID: category?.id, templateID: template.id, markdown: result.markdown,
                model: chat.modelID)
            try? archive.setSetting(Self.summaryDoneKey(itemID), chat.modelID)
            summaryFailures[itemID] = nil
            revision += 1
            notifier.post(title: String(localized: "Sintesi pronta"), body: item.title)
            logger.notice(
                "Summary written with \(chat.modelID, privacy: .public), \(result.discarded.count) points dropped")
        } catch is CancellationError {
        } catch {
            try? archive.setSetting(Self.summaryDoneKey(itemID), "failed")
            summaryFailures[itemID] = ErrorText.describe(error)
            revision += 1
            logger.error("Summary failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// Waits while a call is recorded or a chat answer is being written. False when the task is cancelled.
    private func waitUntilFree() async -> Bool {
        while !Task.isCancelled {
            let recording = await recorder.snapshot().state != .idle
            if !recording, !chatBusy { return true }
            try? await Task.sleep(for: .seconds(3))
        }
        return false
    }

    private func index(with embedder: any TextEmbedder) async {
        try? archive.deleteChunks(notFrom: embedder.modelID)
        guard let pending = try? archive.unindexed(model: embedder.modelID),
            !pending.items.isEmpty || !pending.notes.isEmpty
        else { return }
        let total = pending.items.count + pending.notes.count
        indexing = (0, total)
        defer {
            indexing = nil
            cache.invalidate()
        }
        var done = 0
        worked = true
        for itemID in pending.items {
            guard await waitUntilFree() else { return }
            do {
                if let (drafts, source) = try drafts(for: itemID), !drafts.isEmpty {
                    try await SemanticIndexer.index(
                        drafts, itemID: itemID, noteID: nil, source: source, archive: archive, embedder: embedder)
                } else {
                    try? archive.markNothingToIndex(itemID: itemID, model: embedder.modelID)
                }
            } catch is CancellationError {
                return
            } catch {
                try? archive.markNothingToIndex(itemID: itemID, model: embedder.modelID)
                logger.error("Indexing an item failed: \(String(describing: type(of: error)), privacy: .public)")
            }
            done += 1
            indexing = (done, total)
        }
        for noteID in pending.notes {
            guard await waitUntilFree() else { return }
            if let note = try? archive.note(noteID) {
                try? await SemanticIndexer.index(
                    Chunker.text(note.body), itemID: note.itemId, noteID: noteID, source: .note, archive: archive,
                    embedder: embedder)
            }
            done += 1
            indexing = (done, total)
        }
        logger.notice("Indexed \(total) items and notes")
    }

    /// Chunks of an item: a call by turns of speech, an email or a document by paragraphs.
    private func drafts(for itemID: String) throws -> ([ChunkDraft], Chunk.Source)? {
        guard let item = try archive.item(itemID) else { return nil }
        switch item.type {
        case .call:
            let document = try ItemDocument.load(itemID, from: archive)
            guard let transcript = document.transcript else { return nil }
            return (Chunker.transcript(transcript, labels: document.speakerLabels), .transcript)
        case .email, .document:
            guard let text = try markdown(itemID) else { return nil }
            return (Chunker.text(text), item.type == .email ? .email : .document)
        }
    }

    private func markdown(_ itemID: String) throws -> String? {
        guard let asset = try archive.assets(itemID: itemID).first(where: { $0.kind == .contentMD }) else { return nil }
        return String(decoding: try archive.readAssetData(asset), as: UTF8.self)
    }

    /// New items since the engine arrived (when automatic proposals are on) and items asked by hand.
    private func propose(with chat: any LLMProvider) async {
        var queue = manual
        manual = []
        if autoSuggest,
            let since = (try? archive.setting(Self.sinceKey)).flatMap({ $0 }).flatMap(
                ISO8601DateFormatter().date(from:))
        {
            let candidates = ((try? archive.summaries(.recent)) ?? [])
                .filter {
                    $0.item.createdAt >= since && ($0.hasTranscript || $0.item.type != .call)
                        && (try? archive.setting(Self.doneKey($0.id))) == nil
                }
                .map(\.id)
            queue += candidates.filter { !queue.contains($0) }
        }
        for itemID in queue {
            guard await waitUntilFree() else { return }
            worked = true
            await propose(itemID, with: chat)
        }
    }

    private func propose(_ itemID: String, with chat: any LLMProvider) async {
        guard let item = try? archive.item(itemID), let input = try? input(for: item) else {
            try? archive.setSetting(Self.doneKey(itemID), "skipped")
            return
        }
        proposingFor = item.title
        defer { proposingFor = nil }
        do {
            let proposals = try await SuggestionEngine.propose(
                input, engine: chat, embedder: engine.embedder, archive: archive)
            let added = try archive.replacePendingSuggestions(itemID: itemID, model: chat.modelID, proposals)
            try archive.setSetting(Self.doneKey(itemID), chat.modelID)
            revision += 1
            if !added.isEmpty {
                notifier.post(
                    title: String(localized: "\(added.count) proposte da controllare"),
                    body: String(localized: "In «\(item.title)». Niente viene applicato senza la tua conferma."))
            }
            logger.notice("Proposed \(added.count) suggestions with \(chat.modelID, privacy: .public)")
        } catch {
            logger.error("Proposals failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// The text the engine reads, with the screenshots of a call at their minute (ADR-0072).
    private func input(for item: Item) throws -> SuggestionEngine.Input? {
        try SuggestionEngine.Input.load(item, from: archive)
    }
}
