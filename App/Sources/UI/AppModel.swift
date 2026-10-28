import AppKit
import Foundation
import IAGOCapture
import IAGOCore
import IAGOEngine
import IAGOExport
import IAGOIngest
import IAGOIntelligence
import IAGOStore
import IAGOTranscription
import Observation
import UniformTypeIdentifiers
import os

/// State and actions of the main window (FR-70) and the post-recording panel (FR-20). Reloads from the
/// database after every change, so menu bar, jobs and windows stay in sync.
@MainActor
@Observable
final class AppModel {
    let archiveService: ArchiveService
    let transcription: TranscriptionService
    let recorder: RecordingController
    /// The local engine (ADR-0048); IAGO works without one.
    let engine: EngineService
    /// Indexing and proposals in the background (ADR-0049).
    let intelligence: IntelligenceService
    /// Watched folders of emails (ADR-0050).
    let folderImporter: FolderImporter
    /// Meetings: proposals to record, titles, Teams mute (ADR-0051).
    let calls: CallDetector
    /// Imports, backups, exports, downloads: the "Attività" view (ADR-0055).
    let activity: ActivityCenter
    /// Pending proposals per item, for the marks in lists and timelines.
    private(set) var pendingSuggestions: [String: Int] = [:]
    /// The pane to show when Settings opens (e.g. "Motore" from "Serve un motore locale").
    var settingsPane: SettingsView.Pane?
    /// Live recording state, shown in the window too (polled once a second).
    private(set) var recording: RecordingController.Snapshot?
    var archive: Archive { archiveService.archive }

    enum SidebarSelection: Hashable {
        case library(LibraryScope)
        /// The global decision register (FR-153).
        case decisions
        /// «Da fare»: the open work of every project (ADR-0074).
        case inbox
        /// "Importa": drop area and every way to bring material in (files, clipboard, text, emails).
        case importer
        /// "Attività" (ADR-0055).
        case activity
        /// "Categorie e tag": every category and tag, to browse across projects.
        case labels
        case trash
    }

    var sidebar: SidebarSelection? = .library(.unclassified)

    /// Combined filters and sorting of the library (FR-71, FR-72), applied to list and timeline.
    struct LibraryFilter: Equatable {
        enum Status: String, CaseIterable { case all, audioOnly, transcribed }
        enum Sort: String, CaseIterable { case date, title, duration, project }
        var categoryID: String?
        var tags: Set<String> = []
        /// ADR-0038: items in at least one of these streams.
        var streamIDs: Set<String> = []
        var type: Item.Kind?
        var status = Status.all
        var from: Date?
        var to: Date?
        var sort = Sort.date

        var isActive: Bool {
            categoryID != nil || !tags.isEmpty || !streamIDs.isEmpty || type != nil || status != .all || from != nil
                || to != nil
        }

        func apply(_ summaries: [ItemSummary]) -> [ItemSummary] {
            let filtered = summaries.filter { summary in
                if let categoryID, summary.item.categoryId != categoryID { return false }
                if !tags.isEmpty, !tags.isSubset(of: Set(summary.tags)) { return false }
                if !streamIDs.isEmpty, streamIDs.isDisjoint(with: summary.streamIDs) { return false }
                if let type, summary.item.type != type { return false }
                switch status {
                case .all: break
                case .audioOnly: if summary.hasTranscript || !summary.hasAudio { return false }
                case .transcribed: if !summary.hasTranscript { return false }
                }
                if let from, summary.item.occurredAt < Calendar.current.startOfDay(for: from) { return false }
                if let to,
                    summary.item.occurredAt >= Calendar.current.date(
                        byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: to))!
                {
                    return false
                }
                return true
            }
            switch sort {
            case .date: return filtered.sorted { $0.item.occurredAt > $1.item.occurredAt }
            case .title:
                return filtered.sorted {
                    $0.item.title.localizedCaseInsensitiveCompare($1.item.title) == .orderedAscending
                }
            case .duration: return filtered.sorted { ($0.item.durationSec ?? 0) > ($1.item.durationSec ?? 0) }
            case .project:
                return filtered.sorted {
                    ($0.projectName ?? "\u{10FFFF}", $1.item.occurredAt) < (
                        $1.projectName ?? "\u{10FFFF}", $0.item.occurredAt
                    )
                }
            }
        }
    }

    var filter = LibraryFilter() { didSet { if filter != oldValue { reload() } } }

    // MARK: Search (ADR-0036)

    var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            let active = !searchText.trimmingCharacters(in: .whitespaces).isEmpty
            if active, !showsSearch {
                // A new search starts in the project being viewed, if any.
                searchScope = currentSearchScope
                searchOriginScope = searchScope
            }
            showsSearch = active
            scheduleSearch()
        }
    }
    private(set) var searchHits: [SearchHit] = []
    /// The results replace the content column; switching section hides them but keeps the search, and the
    /// toolbar icon brings them back.
    var showsSearch = false
    /// Where the search looks: a client, a project, a stream, or everything.
    var searchScope = SearchScope.all { didSet { if searchScope != oldValue { scheduleSearch() } } }
    /// Where the search started from, to offer it again after "Cerca ovunque".
    private(set) var searchOriginScope = SearchScope.all

    /// "Chiedi" (ADR-0049): the side panel and what it looks at.
    var showsChat = false
    var chatScope: SearchScope { currentSearchScope }

    /// The sidebar selection as a search scope.
    private var currentSearchScope: SearchScope {
        switch sidebar {
        case .library(.project(let id)): .project(id)
        case .library(.client(let id)): .client(id)
        case .library(.stream(let id)): .stream(id)
        default: .all
        }
    }
    /// Kind of content searched; nil = everything.
    var searchSource: SearchHit.Source? { didSet { if searchSource != oldValue { scheduleSearch() } } }
    /// Set when a search result is opened: the item view starts the audio there.
    var pendingSeek: (itemID: String, atSec: Double)?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = searchText
        let scope = searchScope
        let sources: Set<SearchHit.Source> = searchSource.map { [$0] } ?? []
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            // Words first, at once; then words and meaning together when the search model is there (ADR-0049).
            searchHits = (try? archive.search(text, scope: scope, sources: sources)) ?? []
            guard let embedder = engine.embedder else { return }
            // The user is waiting: the search goes before the next background block, without interrupting the one
            // in progress, which would start over at every key (ADR-0069).
            let hybrid = try? await EngineLane.$interactive.withValue(true) {
                try await EngineLane.$preempts.withValue(false) {
                    try await HybridSearch.search(
                        text, scope: scope, sources: sources, archive: archive, embedder: embedder,
                        cache: intelligence.cache)
                }
            }
            guard !Task.isCancelled, let hybrid else { return }
            searchHits = hybrid
        }
    }

    func openHit(_ hit: SearchHit) {
        if hit.source == .decision {
            if let summary = try? archive.decisionSummary(hit.sourceID) { openDecisionSource(summary) }
            return
        }
        guard let itemID = hit.itemID else { return }
        if let at = hit.atSec { pendingSeek = (itemID, at) }
        selectedItemID = itemID
    }
    var selectedItemID: String? {
        didSet {
            guard let selectedItemID else { return }
            lastItemID = selectedItemID
            selectedDecisionID = nil
            selectedNoteID = nil
        }
    }
    /// A decision or a note opened in the detail pane, instead of an item (one thing at a time).
    var selectedDecisionID: String? {
        didSet {
            guard selectedDecisionID != nil else { return }
            selectedItemID = nil
            selectedNoteID = nil
        }
    }
    var selectedNoteID: String? {
        didSet {
            guard selectedNoteID != nil else { return }
            selectedItemID = nil
            selectedDecisionID = nil
        }
    }
    /// Last item created or opened: default target of "Nota vocale…" from the menu bar (FR-216).
    var lastItemID: String?
    private(set) var summaries: [ItemSummary] = []
    private(set) var projects: [Project] = []
    private(set) var clients: [Client] = []
    /// Streams of every project, in their order (ADR-0038).
    private(set) var streams: [ProjectStream] = []
    private(set) var categories: [IAGOStore.Category] = []
    private(set) var tags: [Tag] = []
    private(set) var trashedItems: [Item] = []
    private(set) var discardedItems: [Item] = []
    /// Recordings the user discarded while recording: moved to "Scartate temporanee" once saved.
    @ObservationIgnored private var pendingDiscards: Set<String> = []
    private(set) var trashedAssets: [Asset] = []
    private(set) var unclassifiedCount = 0
    /// Bumped on every database change; detail views reload when it changes.
    private(set) var revision = 0
    var lastError: String?
    /// Set by the menu bar: asks to download the models when they are missing (spec 7.5).
    var requestModelDownload: (() -> Void)?
    /// Set by the menu bar: applies a fixed microphone (nil = automatic).
    var setMicOverride: ((String?) -> Void)?
    /// Set by the window manager: opens an item in the main window.
    var openItem: ((String) -> Void)?
    /// Set by the window manager: opens the settings window (gear next to the title).
    var openSettings: (() -> Void)?
    /// "Guida di IAGO" and the welcome tour.
    var openHelp: (() -> Void)?
    var openTour: (() -> Void)?
    /// Updates from GitHub Releases (ADR-0056).
    var updates: UpdateService?
    /// The global shortcuts (ADR-0072), set by the app delegate.
    @ObservationIgnored var shortcuts: GlobalShortcuts?

    /// Voice notes (FR-210…218): temporary audio, transcription, leftovers.
    let voiceNotes: VoiceNoteService
    /// The audio player, shared by every item and by the playback bar.
    let player: AudioPlayerModel

    init(
        archiveService: ArchiveService, transcription: TranscriptionService, recorder: RecordingController,
        engine: EngineService, intelligence: IntelligenceService, folderImporter: FolderImporter,
        calls: CallDetector, activity: ActivityCenter
    ) {
        self.activity = activity
        self.archiveService = archiveService
        self.transcription = transcription
        self.recorder = recorder
        self.engine = engine
        self.intelligence = intelligence
        self.folderImporter = folderImporter
        self.calls = calls
        self.voiceNotes = VoiceNoteService(
            transcription: transcription, archive: archiveService.archive,
            folder: archiveService.paths.voiceNotes)
        self.player = AudioPlayerModel(archive: archiveService.archive, scratch: archiveService.paths.scratch)
        reload()
        Task { [weak self, recorder] in
            while !Task.isCancelled {
                let snapshot = await recorder.snapshot()
                guard let self else { return }
                if snapshot != self.recording { self.recording = snapshot }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        // Writes made by another process (Claude through the MCP server, ADR-0044) are not seen by `changes()`.
        Task { [weak self, archive = archiveService.archive] in
            var last = (try? archive.externalChangeCounter()) ?? 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                let current = (try? archive.externalChangeCounter()) ?? last
                guard current != last else { continue }
                last = current
                guard let self else { return }
                self.reload()
                self.scheduleObsidianSync()
            }
        }
        Task { [weak self, archive = archiveService.archive] in
            for await _ in archive.changes() {
                self?.reload()
                self?.intelligence.poke()
                self?.scheduleObsidianSync()
            }
        }
    }

    func reload() {
        do {
            projects = try archive.projects()
            clients = try archive.clients()
            streams = try archive.streams()
            categories = try archive.categories()
            tags = try archive.allTags()
            trashedItems = try archive.trashedItems()
            discardedItems = try archive.discardedItems()
            trashedAssets = try archive.trashedAssets()
            unclassifiedCount = try archive.summaries(.unclassified).count
            if case .library(let scope) = sidebar {
                summaries = filter.apply(try archive.summaries(scope))
            } else {
                summaries = []
            }
            people = try archive.people()
            workMode = archive.workMode()
            if let scope = decisionScope {
                var query = decisionQuery
                query.scope = scope
                decisions = try archive.decisions(query)
                // The timeline shows every decision of the scope, whatever the register's filters.
                timelineDecisions =
                    showsTimeline ? try archive.decisions(DecisionQuery(scope: scope, statuses: [])) : []
            } else {
                decisions = []
                timelineDecisions = []
            }
            if showsTimeline {
                if case .library(.stream(let id)) = sidebar {
                    timelineNotes = try archive.notes(streamID: id, itemIDs: summaries.map(\.id))
                } else {
                    var projectID: String?
                    if case .library(.project(let id)) = sidebar { projectID = id }
                    timelineNotes = try archive.notes(projectID: projectID, itemIDs: summaries.map(\.id))
                }
            } else {
                timelineNotes = []
            }
            pendingSuggestions = (try? archive.pendingSuggestionCounts()) ?? [:]
            revision += 1
        } catch {
            lastError = ErrorText.describe(error)
        }
    }

    /// List, timeline or decision register for the current scope; a project opens on its timeline. «Riepilogo» and
    /// the kanban (ADR-0074) are for projects, clients and streams; the kanban also for «Da fare» and «Punti chiave».
    enum ViewMode: Hashable { case list, timeline, decisions, graph, overview, board }
    var viewMode = ViewMode.list { didSet { if viewMode != oldValue { reload() } } }
    var showsTimeline: Bool { viewMode == .timeline }
    var showsDecisions: Bool { viewMode == .decisions || sidebar == .decisions }
    var showsGraph: Bool { viewMode == .graph && sidebar != .decisions }

    // MARK: Decisions (FR-150…157, ADR-0037)

    var decisionQuery = DecisionQuery() { didSet { if decisionQuery != oldValue { reload() } } }
    private(set) var decisions: [DecisionSummary] = []
    private(set) var timelineDecisions: [DecisionSummary] = []
    /// Notes shown at their date on the timeline (FR-175): project notes and notes of the listed items.
    private(set) var timelineNotes: [Note] = []
    private(set) var people: [Entity] = []
    /// "Impostazioni" of a project or client, shown by the main window.
    var scopeSettings: ScopeSettingsTarget?
    /// The decision editor, shown by the main window whoever asks for it.
    var editingDecision: DecisionDraft? {
        didSet {
            // A new decision taken from an item starts in the item's streams.
            guard var draft = editingDecision, draft.existingID == nil, draft.streamIDs.isEmpty,
                let itemID = draft.sourceItemID, oldValue?.id != draft.id
            else { return }
            draft.streamIDs = (try? archive.streamIDs(itemID: itemID)) ?? []
            if !draft.streamIDs.isEmpty { editingDecision = draft }
        }
    }

    /// Decisions of the current sidebar selection: a project, the items without a project, or everything.
    var decisionScope: DecisionQuery.Scope? {
        switch sidebar {
        case .decisions: return .all
        case .library(.project(let id)): return .project(id)
        case .library(.client(let id)): return .client(id)
        case .library(.stream(let id)): return .stream(id)
        case .library(.unclassified), .library(.undefinedProject): return .noProject
        case .library: return .all
        case .importer, .activity, .labels, .trash, .inbox, nil: return nil
        }
    }

    /// The project badge is shown when the register mixes projects (everything, a client, the unclassified).
    var decisionScopeSpansProjects: Bool {
        switch decisionScope {
        case .project, .stream: false
        default: true
        }
    }

    /// Clicking a decision: the audio starts at its timestamp, or its source opens (FR-153).
    func openDecisionSource(_ summary: DecisionSummary) {
        let decision = summary.decision
        guard summary.sourceState == .available || summary.sourceState == .trashed else { return }
        // A decision promoted from a note opens that note in the detail pane (item notes and project notes alike).
        if let noteID = decision.sourceNoteId, (try? archive.note(noteID)).flatMap({ $0 }) != nil {
            selectedNoteID = noteID
            return
        }
        guard let itemID = decision.sourceItemId, summary.sourceState == .available else {
            if summary.sourceState == .trashed { select(.trash) }
            return
        }
        if let at = decision.sourceAtSec { pendingSeek = (itemID, at) }
        selectedItemID = itemID
    }

    /// The decision a note became, if it was promoted ("Promuovi a decisione"): the note stays, marked.
    /// How a note, decision or item came through Claude (ADR-0044): nil when it did not.
    func viaClaude(_ entity: MCPChange.Entity, _ id: String) -> MCPChange.Action? {
        _ = revision
        return (try? archive.mcpProvenance(entity, ids: [id]))?[id]
    }

    /// Reads `revision` so the views that ask are redrawn when a decision is saved.
    func promotedDecision(ofNote noteID: String) -> String? {
        _ = revision
        return (try? archive.promotedDecisions(noteIDs: [noteID]))?[noteID]
    }

    /// Writes the editor's draft: the entry, its owner and who it waits for (people created if new), what it depends
    /// on and its checklist (ADR-0074).
    func saveDecision(_ draft: DecisionDraft) {
        var proposed = draft.decision
        // A confirmed proposal keeps the model that proposed it (ADR-0070).
        if let suggestionID = draft.suggestionID, let suggestion = try? archive.suggestion(suggestionID) {
            proposed.model = Provenance.decisionModel(of: suggestion)
        }
        perform {
            if proposed.kind.isWork {
                proposed.ownerId = try draft.ownerName.flatMap { try archive.person(named: $0)?.id }
                proposed.waitingOnId = try draft.waitingOnName.flatMap { try archive.person(named: $0)?.id }
            }
            let decision = proposed
            // The state only when the user changed it: "Bloccata" comes from the dependencies, and "Traccia" shows
            // under way and blocked as "Aperta".
            let status = draft.status != draft.loadedStatus ? draft.status : nil
            let id: String
            if let existing = draft.existingID {
                try archive.updateDecision(
                    existing, people: draft.people, tags: draft.tags, streams: draft.streamIDs,
                    supersedes: draft.supersedesIDs, reorderingChain: draft.reorderingChain
                ) { current in
                    current.text = decision.text
                    current.kind = decision.kind
                    current.decidedAt = decision.decidedAt
                    current.projectId = decision.projectId
                    current.notes = decision.notes
                    current.ownerId = decision.ownerId
                    current.dueAt = decision.dueAt
                    current.waitingOnId = decision.waitingOnId
                    current.waitingUntil = decision.waitingUntil
                    current.priority = decision.priority
                    current.severity = decision.severity
                    current.startsAt = decision.startsAt
                    current.estimate = decision.estimate
                    current.recurrence = decision.recurrence
                    current.derivedFromId = decision.derivedFromId
                    if let status { current.status = status }
                    if !current.kind.isWork, current.status != .superseded, current.status != .cancelled {
                        current.status = .active
                    }
                    if current.status.isOpen {
                        current.outcome = nil
                        current.outcomeKind = nil
                    }
                }
                id = existing
            } else {
                if let suggestionID = draft.suggestionID { try archive.setSuggestionStatus(suggestionID, .accepted) }
                id = try archive.createDecision(
                    decision, people: draft.people, tags: draft.tags, streams: draft.streamIDs,
                    markerID: draft.markerID,
                    supersedes: draft.supersedesIDs
                ).id
            }
            if decision.kind.isWork, draft.blockerIDs != draft.loadedBlockerIDs {
                try archive.setBlockers(draft.blockerIDs, of: id)
            } else if !decision.kind.isWork, !draft.loadedBlockerIDs.isEmpty {
                try archive.setBlockers([], of: id)
            }
            if draft.existingID == nil || draft.checklistLoaded {
                try saveChecklist(decision.kind.isWork ? draft.checklist : [], decisionID: id)
            }
            if let convertsID = draft.convertsID {
                let into = DecisionRow.kindLabel(decision.kind).lowercased()
                try archive.updateDecision(convertsID) { request in
                    request.status = .done
                    request.outcomeKind = .converted
                    request.outcome = String(localized: "trasformata in \(into)")
                }
            }
        }
        if let itemID = draft.sourceItemID { refreshTextAssets(itemID) }
    }

    /// The lines of an activity as edited: removed ones deleted, changed ones updated, new ones added, in order.
    private func saveChecklist(_ lines: [ChecklistLine], decisionID: String) throws {
        let current = try archive.checklistItems(decisionID: decisionID)
        let kept = lines.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let keptIDs = Set(kept.compactMap(\.itemID))
        for item in current where !keptIDs.contains(item.id) { try archive.deleteChecklistItem(item.id) }
        var order: [String] = []
        for line in kept {
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let itemID = line.itemID, let saved = current.first(where: { $0.id == itemID }) {
                if saved.text != text || saved.done != line.done {
                    try archive.updateChecklistItem(itemID) {
                        $0.text = text
                        $0.done = line.done
                    }
                }
                order.append(itemID)
            } else {
                let item = try archive.addChecklistItem(text, decisionID: decisionID)
                if line.done { try archive.updateChecklistItem(item.id) { $0.done = true } }
                order.append(item.id)
            }
        }
        if order != current.filter({ keptIDs.contains($0.id) }).map(\.id) { try archive.reorderChecklist(order) }
    }

    /// The stream being viewed, for new notes in it (ADR-0047).
    var scopeStreamIDs: [String] {
        if case .library(.stream(let id)) = sidebar { [id] } else { [] }
    }

    /// The project of the sidebar selection (a stream's project too), for new notes and key points.
    var scopeProjectID: String? {
        switch sidebar {
        case .library(.project(let id)): id
        case .library(.stream(let id)): stream(id)?.projectId
        default: nil
        }
    }

    /// A new decision, activity or milestone (ADR-0046), in the given project or the one being viewed.
    func newKeyPoint(_ kind: Decision.Kind, projectID: String? = nil) {
        var draft = DecisionDraft(projectID: projectID ?? scopeProjectID, kind: kind)
        if case .library(.stream(let id)) = sidebar { draft.streamIDs = [id] }
        editingDecision = draft
    }

    func decisionKind(_ id: String) -> Decision.Kind {
        (try? archive.decision(id))??.kind ?? .decision
    }

    /// "Nuova decisione" from the register: in the project being viewed, if any.
    func newDecision() {
        if case .project(let id) = decisionScope {
            editingDecision = DecisionDraft(projectID: id)
        } else {
            editingDecision = DecisionDraft()
        }
    }

    func setDecisionStatus(_ id: String, _ status: Decision.Status) {
        perform { try archive.setDecisionStatus(id, status) }
    }

    func deleteDecision(_ id: String) {
        perform { try archive.deleteDecision(id) }
    }

    /// Current entries a new one can replace or close (valid decisions and milestones, open work): same project
    /// first.
    func supersedableDecisions(projectID: String?, excluding id: String?) -> [DecisionSummary] {
        let all = (try? archive.decisions(DecisionQuery(scope: .all, statuses: DecisionQuery.current))) ?? []
        let candidates = all.filter { $0.id != id }
        return candidates.filter { $0.decision.projectId == projectID }
            + candidates.filter { $0.decision.projectId != projectID }
    }

    // MARK: Open work (ADR-0074)

    /// "Traccia" or "Gestisci", as chosen in Impostazioni › Generale.
    private(set) var workMode = WorkMode.track

    func setWorkMode(_ mode: WorkMode) {
        perform { try archive.setWorkMode(mode) }
        reload()
    }

    /// The mode a project is shown in: the app's, unless the project is kept in "Traccia" ("Tieni semplice").
    func workMode(for projectID: String?) -> WorkMode {
        guard workMode == .manage else { return .track }
        return project(projectID)?.workMode ?? .manage
    }

    func setProjectWorkMode(_ projectID: String, _ mode: WorkMode?) {
        perform { try archive.setProjectWorkMode(projectID, mode) }
        reload()
    }

    /// The user's name ("Io" in the transcripts), first among the people of a key point.
    var meName: String {
        _ = revision
        let name = ((try? archive.setting(TranscriptionService.meLabelKey)) ?? nil)?
            .trimmingCharacters(in: .whitespaces)
        return name?.isEmpty == false ? name! : "Io"
    }

    /// A closing that asks for a few words (answer, activities, reason), shown by the main window.
    var closingKeyPoint: KeyPointClosing?

    /// Closes a work entry with its outcome: resolved, not relevant, rejected (with the reason).
    func closeKeyPoint(_ id: String, _ outcome: Decision.Outcome, text: String? = nil) {
        let text = text?.isEmpty == false ? text : nil
        perform {
            try archive.updateDecision(id) {
                $0.status = .done
                $0.outcomeKind = outcome
                $0.outcome = text
            }
        }
    }

    /// "Riapri": back to open, without the outcome.
    func reopenKeyPoint(_ id: String) {
        perform {
            try archive.updateDecision(id) {
                $0.status = .active
                $0.outcomeKind = nil
                $0.outcome = nil
            }
        }
    }

    /// «Diventato problema»: the risk happened today; it stays open, with its story, until it is closed.
    func riskHappened(_ id: String) {
        let now = Date()
        perform { try archive.updateDecision(id) { $0.happenedAt = now } }
    }

    /// «Chiarisci…»: the answer closes the point. «Diventa decisione»: the answer becomes a decision that "risponde
    /// a" the point (the point reads "chiarito" through the link).
    func clarify(_ summary: DecisionSummary, answer: String, becomesDecision: Bool) {
        perform {
            try archive.updateDecision(summary.id) {
                $0.outcome = answer
                $0.outcomeKind = .answered
                if !becomesDecision { $0.status = .done }
            }
            guard becomesDecision else { return }
            try archive.createDecision(
                Decision(
                    text: answer, decidedAt: Date(), projectId: summary.decision.projectId, origin: .manual,
                    kind: .decision),
                people: summary.people, tags: summary.tags, streams: summary.streamIDs, supersedes: [summary.id])
        }
    }

    /// «Accogli»: the request is accepted; each line becomes an activity born from it.
    func accept(_ summary: DecisionSummary, activities: [String]) {
        perform {
            for text in activities {
                var activity = Decision(
                    text: text, decidedAt: Date(), projectId: summary.decision.projectId, origin: .manual,
                    kind: .action)
                activity.derivedFromId = summary.id
                try archive.createDecision(
                    activity, people: summary.people, tags: summary.tags, streams: summary.streamIDs)
            }
            let count = activities.count
            try archive.updateDecision(summary.id) {
                $0.status = .done
                $0.outcomeKind = .accepted
                $0.outcome = count == 0 ? nil : String(localized: "\(count) attività")
            }
        }
    }

    /// Open work an entry can depend on: same project first.
    func dependableEntries(projectID: String?, excluding id: String?) -> [DecisionSummary] {
        let open = Set(DecisionQuery.current)
        let all =
            (try? archive.decisions(DecisionQuery(scope: .all, statuses: open, kinds: Set(Decision.Kind.work)))) ?? []
        let candidates = all.filter { $0.id != id }
        return candidates.filter { $0.decision.projectId == projectID }
            + candidates.filter { $0.decision.projectId != projectID }
    }

    /// True if `blocker` already depends on `id`, directly or through others: it cannot also block it.
    func dependsOn(_ blocker: String, _ id: String) -> Bool {
        if blocker == id { return true }
        var stack = [blocker]
        var seen: Set<String> = []
        while let current = stack.popLast() {
            for next in (try? archive.blockers(of: current)) ?? [] {
                if next.id == id { return true }
                if seen.insert(next.id).inserted { stack.append(next.id) }
            }
        }
        return false
    }

    // MARK: Categories and tags in "In evidenza"

    static let pinnedLabelsKey = "sidebar.pinnedLabels"

    /// Tags, categories and streams pinned at the top of the sidebar, as "tag:<id>", "category:<id>", "stream:<id>".
    var pinnedLabels: [String] {
        _ = revision
        return ((try? archive.setting(Self.pinnedLabelsKey)) ?? nil)?.split(separator: ",").map(String.init) ?? []
    }

    func isPinnedLabel(_ key: String) -> Bool { pinnedLabels.contains(key) }

    func togglePinnedLabel(_ key: String) {
        var keys = pinnedLabels
        if let index = keys.firstIndex(of: key) { keys.remove(at: index) } else { keys.append(key) }
        perform { try archive.setSetting(Self.pinnedLabelsKey, keys.isEmpty ? nil : keys.joined(separator: ",")) }
        reload()
    }

    func setPinned(_ project: Project, _ pinned: Bool) {
        perform { try archive.setProjectPinned(project.id, pinned) }
        reload()
    }

    func select(_ selection: SidebarSelection?) {
        if case .library(.project(let id)) = selection { try? archive.touchProject(id) }
        if selection != sidebar {
            switch selection {
            case .library(.project), .library(.undefinedProject), .library(.client), .library(.stream):
                viewMode = .timeline
            case .decisions: viewMode = .decisions
            default: viewMode = .list
            }
            selectedItemID = nil
            selectedDecisionID = nil
            selectedNoteID = nil
        }
        sidebar = selection
        showsSearch = false
        reload()
    }

    // MARK: Previews (first lines of the transcript, FR-80)

    @ObservationIgnored private var previews: [String: (version: Int, text: String)] = [:]

    func preview(_ itemID: String) async -> String? {
        let archive = self.archive
        let assets = (try? archive.assets(itemID: itemID)) ?? []
        // Calls: the first lines of the transcript. Emails and documents: the start of their text.
        guard
            let asset = assets.first(where: { $0.kind == .transcriptJSON })
                ?? assets.first(where: { $0.kind == .contentMD })
        else { return nil }
        if let cached = previews[itemID], cached.version == asset.version { return cached.text }
        let text = await Task.detached(priority: .utility) { () -> String? in
            guard let data = try? archive.readAssetData(asset) else { return nil }
            if asset.kind == .transcriptJSON {
                guard let transcript = try? Transcript.decode(from: data) else { return nil }
                return transcript.segments.prefix(3).map(\.text).joined(separator: " ")
            }
            let skipped = ["#", "**Da:**", "**A:**", "**Cc:**", "**Data:**", "---"]
            let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { line in !line.isEmpty && !skipped.contains(where: line.hasPrefix) }
            let joined = lines.prefix(6).joined(separator: " ")
            return joined.isEmpty ? nil : String(joined.prefix(300))
        }.value
        if let text { previews[itemID] = (asset.version, text) }
        return text
    }

    /// Runs an archive operation, reporting errors in the window instead of failing silently.
    func perform(_ body: () throws -> Void) {
        do {
            try body()
        } catch {
            lastError = ErrorText.describe(error)
        }
    }

    // MARK: Items

    func item(_ id: String) -> Item? { try? archive.item(id) }

    func update(_ id: String, _ change: @escaping @Sendable (inout Item) -> Void) {
        perform {
            let item = try archive.updateItem(id, change)
            if let project = item.projectId { try archive.touchProject(project) }
        }
        refreshTextAssets(id)
    }

    func setTags(_ names: [String], for id: String) {
        perform { try archive.setTags(names, for: id) }
        refreshTextAssets(id)
    }

    // MARK: Recording controls in the window

    func togglePause() {
        Task {
            try? await recorder.toggle()
            recording = await recorder.snapshot()
        }
    }

    func stopRecording() {
        Task {
            await recorder.stop()
            recording = await recorder.snapshot()
        }
    }

    /// "Scarta" (ADR-0032): stops the recording; once saved it goes to "Scartate temporanee" for one
    /// hour instead of opening the post-recording panel.
    func discardRecording() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = String(localized: "Scartare la registrazione?")
        alert.informativeText = String(
            localized:
                "La registrazione si ferma e resta per 1 ora nel Cestino, in \"Scartate temporanee\", poi viene eliminata definitivamente."
        )
        alert.addButton(withTitle: String(localized: "Scarta"))
        alert.addButton(withTitle: String(localized: "Annulla"))
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            guard let id = await recorder.snapshot().itemID?.rawValue else { return }
            pendingDiscards.insert(id)
            await recorder.stop()
            recording = await recorder.snapshot()
        }
    }

    /// Called when a recording has been archived: true if it was discarded (and now is).
    func applyPendingDiscard(_ itemID: String) -> Bool {
        guard pendingDiscards.remove(itemID) != nil else { return false }
        perform { try archive.discardItem(itemID) }
        return true
    }

    /// "Scarta" from the post-recording panel (ADR-0032).
    func discardItem(_ itemID: String) {
        perform { try archive.discardItem(itemID) }
    }

    func minutesLeft(discardedAt: Date) -> Int {
        max(0, Int(ceil(archive.purgeDate(forDiscardedAt: discardedAt).timeIntervalSinceNow / 60)))
    }

    func addBookmark() {
        Task { _ = await recorder.addBookmark() }
    }

    // MARK: Projects

    /// Existing projects whose name looks like `name` (avoids "Progetto Alfa" / "Progeto Alfa").
    func similarProjects(to name: String) -> [Project] {
        ProjectNameMatcher.similar(to: name, among: projects)
    }

    func assign(_ itemID: String, toProject projectID: String?) {
        update(itemID) { $0.projectId = projectID }
    }

    func createProject(named name: String, clientID: String? = nil) -> Project? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var project: Project?
        perform {
            project = try archive.createProject(name: trimmed)
            if let clientID, let id = project?.id {
                try archive.setProjectClient(id, clientID)
                project?.clientId = clientID
            }
        }
        reload()
        return project
    }

    // MARK: Obsidian mirror (FR-122)

    static let obsidianVaultKey = "obsidian_vault"
    static let obsidianProjectsKey = "obsidian_projects"
    private(set) var obsidianStatus: String?
    @ObservationIgnored private var obsidianTask: Task<Void, Never>?

    var obsidianVault: URL? {
        (try? archive.setting(Self.obsidianVaultKey)).map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    var obsidianProjects: Set<String> {
        guard let json = try? archive.setting(Self.obsidianProjectsKey),
            let ids = try? JSONDecoder().decode([String].self, from: Data(json.utf8))
        else { return [] }
        return Set(ids)
    }

    func setObsidian(vault: URL?, projects: Set<String>) {
        perform {
            try archive.setSetting(Self.obsidianVaultKey, vault?.path)
            try archive.setSetting(
                Self.obsidianProjectsKey,
                String(decoding: try JSONEncoder().encode(projects.sorted()), as: UTF8.self))
            try archive.audit(.export, action: "obsidian_settings", detail: "\(projects.count) projects")
        }
        syncObsidianNow()
    }

    /// After changes, a quiet moment, then the vault is brought up to date (never writes the database, so it
    /// does not trigger itself).
    func scheduleObsidianSync() {
        guard obsidianVault != nil, !obsidianProjects.isEmpty else { return }
        obsidianTask?.cancel()
        obsidianTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            await runObsidianSync()
        }
    }

    func syncObsidianNow() {
        obsidianTask?.cancel()
        obsidianTask = Task { await runObsidianSync() }
    }

    private func runObsidianSync() async {
        guard let vault = obsidianVault else { return }
        let projects = obsidianProjects
        let archive = self.archive
        do {
            let result = try await Task.detached(priority: .utility) {
                try ObsidianMirror.sync(archive: archive, vault: vault, projectIDs: projects)
            }.value
            obsidianStatus = String(
                localized:
                    "Aggiornato alle \(Date().formatted(date: .omitted, time: .shortened)): \(result.total) file di IAGO nel vault (\(result.written) cambiati ora, \(result.removed) rimossi)"
            )
        } catch {
            obsidianStatus = String(localized: "Errore: \(ErrorText.describe(error))")
        }
    }

    // MARK: Voice notes left behind (FR-215)

    /// At launch: recordings whose text was never saved (failed transcription, crash) are offered again.
    func offerVoiceNoteLeftovers() async {
        for (audio, target) in voiceNotes.leftovers() {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = String(localized: "C'è una nota vocale non salvata")
            alert.informativeText = String(
                localized:
                    "Registrata il \(target.startedAt.formatted(date: .abbreviated, time: .shortened)). Vuoi trascriverla e salvarla adesso?"
            )
            alert.addButton(withTitle: String(localized: "Trascrivi e salva"))
            alert.addButton(withTitle: String(localized: "Più tardi"))
            alert.addButton(withTitle: String(localized: "Scarta audio"))
            alert.buttons[2].hasDestructiveAction = true
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                do {
                    try await voiceNotes.recover(audio, target)
                } catch {
                    lastError = String(
                        localized:
                            "Trascrizione non riuscita: l'audio resta e verrà riproposto. \(voiceNotes.describe(error))"
                    )
                }
            case .alertThirdButtonReturn:
                voiceNotes.delete(audio)
            default:
                return
            }
        }
    }

    // MARK: Notes (FR-170…176)

    /// Saves a new or edited note, on an item or on a project (FR-172), with the originals to keep.
    func saveNote(_ draft: NoteDraft) {
        let body = draft.body
        let date = draft.notedAt
        let kind = draft.kind
        let input = draft.input
        perform {
            let noteID: String
            if let id = draft.id {
                try archive.updateNote(id) {
                    $0.body = body
                    $0.notedAt = date
                    $0.kind = kind
                    $0.input = input
                }
                noteID = id
            } else {
                noteID = try archive.addNote(
                    itemID: draft.itemID, projectID: draft.itemID == nil ? draft.projectID : nil, body: body,
                    notedAt: date, kind: kind, input: input
                ).id
            }
            try archive.setStreams(draft.streamIDs, noteID: noteID)
            guard let owner = draft.itemID ?? draft.projectID else { return }
            for attachment in draft.pending {
                try archive.storeAttachment(
                    attachment.file, ownerID: owner, noteID: noteID, originalName: attachment.originalName)
                try? FileManager.default.removeItem(at: attachment.file)
            }
        }
        if let itemID = draft.itemID { refreshTextAssets(itemID) }
    }

    /// The note editor, shown by the main window (project notes, notes on the timeline).
    var editingNote: NoteDraft?

    // MARK: Clients and streams (ADR-0038)

    func client(_ id: String?) -> Client? { id.flatMap { id in clients.first { $0.id == id } } }
    func project(_ id: String?) -> Project? { id.flatMap { id in projects.first { $0.id == id } } }
    func stream(_ id: String) -> ProjectStream? { streams.first { $0.id == id } }
    func streams(of projectID: String?) -> [ProjectStream] {
        guard let projectID else { return [] }
        return streams.filter { $0.projectId == projectID }
    }

    func similarClients(to name: String) -> [Client] {
        clients.filter { ProjectNameMatcher.isSimilar(name, $0.name) }
    }

    func createClient(named name: String) -> Client? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var client: Client?
        perform { client = try archive.createClient(name: trimmed) }
        reload()
        return client
    }

    func createStream(named name: String, in projectID: String) -> ProjectStream? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var stream: ProjectStream?
        perform { stream = try archive.createStream(projectID: projectID, name: trimmed) }
        reload()
        return stream
    }

    func setProjectClient(_ projectID: String, _ clientID: String?) {
        perform { try archive.setProjectClient(projectID, clientID) }
        reload()
    }

    func setStreams(_ ids: [String], for itemID: String) {
        perform { try archive.setStreams(ids, itemID: itemID) }
        refreshTextAssets(itemID)
    }

    /// Sidebar disclosure state of clients, projects and "Senza cliente", kept between launches.
    var expandedNodes: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "sidebarExpanded") ?? []) {
        didSet { UserDefaults.standard.set(Array(expandedNodes), forKey: "sidebarExpanded") }
    }

    func toggleExpanded(_ id: String) {
        if expandedNodes.contains(id) { expandedNodes.remove(id) } else { expandedNodes.insert(id) }
    }

    /// TXT and MD are regenerated from the JSON and the database after metadata, speaker or note changes.
    func refreshTextAssets(_ itemID: String) {
        let transcription = self.transcription
        Task.detached(priority: .utility) { try? transcription.renderTextAssets(itemID: itemID) }
    }

    // MARK: Transcription

    func transcribe(_ itemID: String, deleteAudio: Bool, roomMode: Bool) {
        Task {
            do {
                try await transcription.transcribe(itemID: itemID, deleteAudio: deleteAudio, roomMode: roomMode)
                reload()
            } catch ModelManager.ModelError.missing {
                requestModelDownload?()
            } catch {
                lastError = ErrorText.describe(error)
            }
        }
    }

    /// Attaches a Teams transcript (.vtt/.docx) to an item that has the recording (ADR-0033).
    func attachTranscript(_ url: URL, to itemID: String) {
        let archive = self.archive
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    guard let transcript = try TeamsTranscript.parse(url, itemID: itemID) else {
                        throw ExtractionError.unsupported(url.lastPathComponent)
                    }
                    try ArchiveService.attach(transcript, from: url, to: itemID, archive: archive)
                }.value
                reload()
            } catch {
                lastError = String(
                    localized:
                        "\(url.lastPathComponent) non sembra una trascrizione Teams (.vtt o .docx): \(ErrorText.describe(error))"
                )
            }
        }
    }

    // MARK: Deletion (ADR-0030)

    enum DeleteChoice { case trash, permanent }

    func deleteItem(_ id: String, _ choice: DeleteChoice, notes: Archive.NoteDisposition = .delete) {
        // No content in the log: only what happened, to reconstruct unexpected deletions.
        Logger(subsystem: "com.giovannilombi.iago", category: "archive").notice(
            "Item \(id, privacy: .public) \(choice == .trash ? "moved to trash" : "deleted for good", privacy: .public) from the UI"
        )
        perform {
            switch choice {
            case .trash: try archive.trashItem(id)
            case .permanent: try archive.purgeItem(id, notes: notes)
            }
        }
        if selectedItemID == id { selectedItemID = nil }
    }

    func deleteAsset(_ asset: Asset, _ choice: DeleteChoice) {
        perform {
            switch choice {
            case .trash: try archive.trashAsset(asset.id)
            case .permanent: try archive.purgeAsset(asset.id)
            }
        }
    }

    func daysLeft(trashedAt: Date) -> Int {
        max(0, Int(ceil(archive.purgeDate(forTrashedAt: trashedAt).timeIntervalSinceNow / 86_400)))
    }

    // MARK: Import (FR-30)

    /// Emails read from `.eml` files, each waiting for its confirmation sheet (FR-184).
    var pendingEmails: [EmailImportDraft] = [] { didSet { if pendingEmails.isEmpty { pendingEmailsTotal = 0 } } }
    /// Size of the queue when it started, for "3 di 12".
    var pendingEmailsTotal = 0
    /// Several emails dropped at once: the stack, imported one at a time or all together.
    var emailBatch: [EmailImportDraft]?

    /// "Una alla volta" from the stack: the emails to import go through the single confirmation.
    func reviewOneByOne(_ drafts: [EmailImportDraft]) {
        emailBatch = nil
        // Every new email is shown, also those IAGO could not file; duplicates are left out.
        pendingEmails = drafts.filter { !$0.alreadyImported }
        pendingEmailsTotal = pendingEmails.count
    }

    /// "Importa" from the table: every included email with its project and streams.
    func importBatch(_ drafts: [EmailImportDraft]) async -> Int {
        var count = 0
        for draft in drafts where draft.include {
            do {
                _ = try await archiveService.importEmail(draft)
                count += 1
            } catch ArchiveError.duplicateEmail {
                continue
            } catch {
                lastError = String(localized: "Import di \(draft.fileName) non riuscito: \(ErrorText.describe(error))")
            }
        }
        reload()
        return count
    }
    /// "Nuova email" sheet.
    var composingEmail = false

    enum ExportKind: String, Identifiable {
        case llm, audio
        var id: String { rawValue }
    }

    /// "Esporta" menu of the current view.
    var exporting: ExportKind?

    func importEmail(_ draft: EmailImportDraft) async {
        do {
            let item = try await archiveService.importEmail(draft)
            reload()
            selectedItemID = item.id
        } catch {
            lastError = String(localized: "Import di \(draft.fileName) non riuscito: \(ErrorText.describe(error))")
        }
    }

    func createEmail(_ input: EmailInput, projectID: String?) async {
        do {
            let item = try await archiveService.createEmail(input, projectID: projectID)
            reload()
            selectedItemID = item.id
        } catch {
            lastError = ErrorText.describe(error)
        }
    }

    /// "Importa › Da file…" (and "Email .eml…" with `emailsOnly`): the system panel, then the usual import.
    func chooseFilesToImport(emailsOnly: Bool = false) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = !emailsOnly
        if emailsOnly {
            panel.allowedContentTypes = ["eml", "emlx"].compactMap { UTType(filenameExtension: $0) }
        }
        panel.prompt = String(localized: "Importa")
        guard panel.runModal() == .OK else { return }
        importFiles(panel.urls)
    }

    /// What the clipboard holds, shown in "Importa › Dagli appunti" before anything is imported.
    enum ClipboardContent {
        case files([URL])
        case image(png: Data, size: CGSize)
        case text(String)
        case empty
    }

    /// Files first, then an image (screenshots, images copied from an app or a page), then text. Only the
    /// kinds of data are looked at here; nothing is imported until the user confirms.
    func clipboardContent() -> ClipboardContent {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            as? [URL], !urls.isEmpty
        {
            return .files(urls)
        }
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil),
            let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        {
            return .image(png: png, size: CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        }
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return .text(text)
        }
        return .empty
    }

    /// An image from the clipboard becomes a document read with OCR, like a dropped image.
    func importClipboardImage(_ png: Data) {
        let folder = archiveService.paths.scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let file = folder.appendingPathComponent(
            String(localized: "Immagine dagli appunti") + " \(Date().formatted(.iso8601.year().month().day())).png")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: file)
            importFiles([file])
        } catch {
            lastError = ErrorText.describe(error)
        }
    }

    /// "Importa › Da testo": the text becomes a document to classify, like an imported file.
    func importText(_ text: String, title: String) async -> Bool {
        do {
            let item = try await archiveService.importText(text, title: title)
            reload()
            selectedItemID = item.id
            return true
        } catch {
            lastError = ErrorText.describe(error)
            return false
        }
    }

    /// Folders (a dragged thread, a folder of documents) are opened: their files are imported.
    static func expandFolders(_ urls: [URL]) -> [URL] {
        urls.flatMap { url -> [URL] in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue
            else { return [url] }
            let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            return (enumerator?.allObjects as? [URL] ?? []).filter {
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
    }

    func importFiles(_ dropped: [URL]) {
        let urls = Self.expandFolders(dropped)
        // Emails go through their confirmation sheet; everything else is imported at once.
        let emails = urls.filter(ArchiveService.isEmail)
        var drafts: [EmailImportDraft] = []
        for url in emails {
            do {
                drafts.append(try archiveService.readEmail(url))
            } catch {
                lastError = String(
                    localized: "\(url.lastPathComponent) non sembra un'email leggibile: \(ErrorText.describe(error))")
            }
        }
        if drafts.count > 1 {
            emailBatch = drafts
        } else {
            pendingEmails += drafts
            pendingEmailsTotal = max(pendingEmailsTotal, pendingEmails.count)
        }
        let others = urls.filter { !emails.contains($0) }
        guard !others.isEmpty else { return }
        let work = activity.begin(
            .importFiles, others.count == 1 ? others[0].lastPathComponent : "\(others.count) file")
        Task {
            let results = await archiveService.importFiles(others)
            let item: String? = if case .success(let item)? = results.last?.result { item.id } else { nil }
            activity.end(
                work,
                failure: results.contains { if case .failure = $0.result { true } else { false } }
                    ? String(localized: "Alcuni file non sono stati importati") : nil, itemID: item)
            let failures = results.compactMap { entry -> String? in
                if case .failure(let error) = entry.result {
                    "\(entry.name): \(ErrorText.describe(error))"
                } else {
                    nil
                }
            }
            if !failures.isEmpty { lastError = failures.joined(separator: "\n") }
            if case .success(let item)? = results.last?.result {
                select(.library(.unclassified))
                selectedItemID = item.id
            }
        }
    }
}
