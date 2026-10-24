import AppKit
import IAGOCore
import IAGOExport
import IAGOStore
import SwiftUI
import UniformTypeIdentifiers

/// Item view (FR-52, spec 14): editable metadata, player with track choice, transcript with clickable
/// timestamps and renameable speakers, Markdown view, bookmarks, notes, assets and actions.
struct ItemDetailView: View {
    @Bindable var model: AppModel
    let itemID: String

    @State private var item: Item?
    @State private var assets: [Asset] = []
    @State private var markers: [Marker] = []
    @State private var decisions: [DecisionSummary] = []
    @State private var notes: [Note] = []
    @State private var speakers: [ItemSpeaker] = []
    @State private var transcript: Transcript?
    @State private var content: String?
    @State private var originalImage: NSImage?
    @State private var attachingTranscript = false
    @State private var confirmAttachTranscript = false
    @State private var activeJob: Job?
    @State private var tab = Tab.transcript
    @State private var roomMode = false
    @State private var confirmRetranscribe: Bool?
    @State private var deletingItem = false
    @State private var askNotesDisposition = false
    @State private var editingNote: NoteDraft?
    /// The Markdown of a document or email being corrected (FR-191).
    @State private var editingContent: String?

    enum Tab: Hashable { case transcript, markdown }

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: 20) {
                    MetadataEditor(model: model, item: item)
                    ViaClaudeBadge(model: model, entity: .item, id: item.id)
                    actions(item)
                    if let job = activeJob { jobProgress(job) }
                    SummarySection(
                        model: model, item: item,
                        hasText: item.type == .call ? transcript != nil : content?.isEmpty == false
                    ) { seconds in
                        tab = .transcript
                        Task { await listen(at: seconds) }
                    }
                    SuggestionsSection(model: model, item: item)
                    if hasAudio {
                        PlayerSection(
                            player: player, isLoaded: isMine, duration: item.durationSec,
                            tracks: assets.filter { $0.kind.isAudio }
                        ) { Task { await listen() } }
                    }
                    if !markers.isEmpty { markersSection }
                    switch item.type {
                    case .document: documentSection
                    case .email:
                        EmailHeaderSection(model: model, itemID: itemID)
                        documentSection
                    case .call: transcriptSection(item)
                    }
                    notesSection(item)
                    decisionsSection(item)
                    LinksSection(model: model, itemID: itemID)
                    assetsSection
                }
                .padding(20)
                .frame(minWidth: 0, maxWidth: 820, alignment: .leading)
            }
        }
        .task(id: model.revision) { await load() }
        // Audio that was only prepared is released; audio being listened to keeps going (playback bar).
        .onDisappear { if isMine, !player.isActive { player.close() } }
        .alert(String(localized: "Sostituire la trascrizione esistente?"), isPresented: $confirmAttachTranscript) {
            Button(String(localized: "Scegli il file…")) { chooseTranscript() }
            Button(String(localized: "Annulla"), role: .cancel) {}
        } message: {
            Text(String(localized: "La trascrizione Teams diventerà quella dell'elemento."))
        }
        .sheet(
            isPresented: Binding(get: { editingContent != nil }, set: { if !$0 { editingContent = nil } })
        ) {
            MarkdownEditSheet(text: editingContent ?? "") { text in
                model.perform { try model.archive.updateContentMarkdown(text, itemID: itemID) }
                content = nil
                model.refreshTextAssets(itemID)
            }
        }
        .sheet(item: $editingNote) { draft in
            NoteEditor(model: model, draft: draft) { saved in save(saved) }
        }
    }

    // MARK: Loading

    private func load() async {
        let archive = model.archive
        guard let item = try? archive.item(itemID) else {
            self.item = nil
            return
        }
        self.item = item
        assets = (try? archive.assets(itemID: itemID)) ?? []
        markers = (try? archive.markers(itemID: itemID)) ?? []
        decisions = (try? archive.decisions(sourceItemID: itemID)) ?? []
        notes = (try? archive.notes(itemID: itemID)) ?? []
        speakers = (try? archive.speakers(itemID: itemID)) ?? []
        activeJob = (try? archive.jobs(itemID: itemID))?.first { $0.isActive }
        if let md = assets.first(where: { $0.kind == .contentMD }), content == nil {
            content = await Task.detached { try? String(decoding: archive.readAssetData(md), as: UTF8.self) }.value
        }
        if let image = assets.first(where: { $0.kind == .originalImage }), originalImage == nil {
            originalImage = await Task.detached { (try? archive.readAssetData(image)).flatMap(NSImage.init(data:)) }
                .value
        }
        if let json = assets.first(where: { $0.kind == .transcriptJSON }) {
            if transcript == nil || json.updatedAt > (transcriptLoadedAt ?? .distantPast) {
                transcript = await Task.detached { try? Transcript.decode(from: archive.readAssetData(json)) }.value
                transcriptLoadedAt = json.updatedAt
            }
        } else {
            transcript = nil
        }
        if isMine, let asset = player.asset, !assets.contains(where: { $0.id == asset.id }) { player.close() }
        // Prepared in advance, unless another item is being listened to.
        if !player.isActive, !isMine, let first = preferredTrack(assets) {
            await player.load(first, itemID: itemID)
        }
        // Opened from a search result: start the audio at the passage.
        if let seek = model.pendingSeek, seek.itemID == itemID, hasAudio {
            model.pendingSeek = nil
            tab = .transcript
            await listen(at: seek.atSec)
        }
    }

    private var player: AudioPlayerModel { model.player }
    private var isMine: Bool { player.itemID == itemID }
    private var hasAudio: Bool { assets.contains { $0.kind.isAudio } }

    /// Plays this item, from `seconds` if given; takes the player over from another item.
    private func listen(at seconds: Double? = nil) async {
        if !isMine, let track = preferredTrack(assets) { await player.load(track, itemID: itemID) }
        guard isMine, player.asset != nil else { return }
        if let seconds {
            player.seek(to: seconds)
        } else if !player.isPlaying {
            player.togglePlay()
        }
    }

    @State private var transcriptLoadedAt: Date?

    private func preferredTrack(_ assets: [Asset]) -> Asset? {
        let order: [Asset.Kind] = [.audioMix, .audioImport, .audioMic, .audioSystem]
        return order.lazy.compactMap { kind in assets.first { $0.kind == kind } }.first
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(_ item: Item) -> some View {
        let hasAudio = assets.contains { $0.kind.isAudio }
        VStack(alignment: .leading, spacing: 10) {
            if hasAudio, item.source == .recording, assets.contains(where: { $0.kind == .audioSystem }) {
                Toggle(String(localized: "Più persone nella stanza"), isOn: $roomMode)
                    .help(String(localized: "Distingue le voci anche nel microfono del Mac (ADR-0031)"))
            }
            ActionGrid {
                if hasAudio, activeJob == nil {
                    ActionLink(
                        title: transcript == nil
                            ? String(localized: "Trascrivi e conserva l'audio")
                            : String(localized: "Ritrascrivi e conserva l'audio"),
                        isPrimary: true
                    ) { transcribe(deleteAudio: false) }
                    ActionLink(
                        title: transcript == nil
                            ? String(localized: "Trascrivi ed elimina l'audio")
                            : String(localized: "Ritrascrivi ed elimina l'audio"),
                        detail: String(localized: "L'audio si elimina dopo la verifica della trascrizione")
                    ) { transcribe(deleteAudio: true) }
                }
                if hasAudio {
                    ActionLink(
                        title: String(localized: "Allega trascrizione Teams…"),
                        detail: String(
                            localized: "File .vtt o .docx scaricato da Teams: i nomi degli speaker sono quelli veri")
                    ) {
                        if transcript != nil { confirmAttachTranscript = true } else { chooseTranscript() }
                    }
                }
            }
            // Kept apart from the transcription actions, so it is never hit by mistake.
            Divider().padding(.top, 4)
            HStack {
                Spacer()
                Button(role: .destructive) {
                    deletingItem = true
                } label: {
                    Label(String(localized: "Elimina elemento…"), systemImage: "trash")
                }
                .buttonStyle(.borderless).foregroundStyle(.red).controlSize(.small)
            }
        }
        .confirmationDialog(
            String(localized: "Eliminare \"\(item.title)\"?"), isPresented: $deletingItem, titleVisibility: .visible
        ) {
            Button(String(localized: "Sposta nel cestino")) { model.deleteItem(itemID, .trash) }
            Button(String(localized: "Elimina definitivamente"), role: .destructive) {
                if notes.isEmpty { model.deleteItem(itemID, .permanent) } else { askNotesDisposition = true }
            }
        } message: {
            Text(
                String(
                    localized:
                        "Nel cestino resta 30 giorni e si può ripristinare. L'eliminazione definitiva non si può annullare."
                ))
        }
        .confirmationDialog(
            String(localized: "Cosa fare delle note?"), isPresented: $askNotesDisposition, titleVisibility: .visible
        ) {
            Button(String(localized: "Elimina anche le note"), role: .destructive) {
                model.deleteItem(itemID, .permanent, notes: .delete)
            }
            if item.projectId != nil {
                Button(String(localized: "Sposta le note nel progetto")) {
                    model.deleteItem(itemID, .permanent, notes: .moveToProject)
                }
            }
        } message: {
            Text(String(localized: "L'elemento ha \(notes.count) note (FR-176)."))
        }
        .alert(
            String(localized: "Sostituire la trascrizione esistente?"),
            isPresented: .constant(confirmRetranscribe != nil)
        ) {
            Button(String(localized: "Ritrascrivi")) {
                if let delete = confirmRetranscribe { startTranscription(deleteAudio: delete) }
                confirmRetranscribe = nil
            }
            Button(String(localized: "Annulla"), role: .cancel) { confirmRetranscribe = nil }
        } message: {
            Text(
                String(
                    localized: "La trascrizione attuale e i nomi degli speaker non usati verranno sostituiti (FR-55)."))
        }
    }

    private func chooseTranscript() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "vtt"), UTType(filenameExtension: "docx")].compactMap {
            $0
        }
        panel.message = String(localized: "Scegli la trascrizione Teams di questa riunione")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.attachTranscript(url, to: itemID)
    }

    private func transcribe(deleteAudio: Bool) {
        if transcript != nil { confirmRetranscribe = deleteAudio } else { startTranscription(deleteAudio: deleteAudio) }
    }

    private func startTranscription(deleteAudio: Bool) {
        model.transcribe(itemID, deleteAudio: deleteAudio, roomMode: roomMode)
    }

    private func jobProgress(_ job: Job) -> some View {
        HStack {
            ProgressView(value: job.progress) {
                Text(
                    job.status == .queued
                        ? String(localized: "In coda per la trascrizione") : String(localized: "Trascrizione in corso…")
                )
            }
            Button(String(localized: "Annulla")) {
                Task { try? await model.transcription.queue.cancel(job.id) }
            }
        }
    }

    // MARK: Bookmarks

    private var markersSection: some View {
        SectionBox(String(localized: "Segnalibri"), systemImage: "bookmark", tint: .orange, collapseKey: "markers") {
            ForEach(markers) { marker in
                HStack(alignment: .firstTextBaseline) {
                    timestampButton(marker.atSec)
                    Text(marker.note ?? String(localized: "Momento segnato")).foregroundStyle(
                        marker.note == nil ? .secondary : .primary)
                    Spacer()
                    switch marker.status {
                    case .open:
                        Button(String(localized: "Diventa decisione…")) { decide(from: marker) }
                            .buttonStyle(.link)
                        Button(String(localized: "Scarta")) {
                            model.perform { try model.archive.setMarkerStatus(marker.id, .dismissed) }
                        }
                        .buttonStyle(.link)
                    case .converted:
                        Label(String(localized: "Decisione"), systemImage: "checkmark.seal.fill").font(.caption)
                            .foregroundStyle(.green)
                    case .dismissed:
                        EmptyView()
                    }
                }
                .opacity(marker.status == .dismissed ? 0.5 : 1)
            }
        }
    }

    /// FR-152.1: the bookmark's note (or the passage at that moment) becomes the decision text.
    private func decide(from marker: Marker) {
        guard let item else { return }
        let segment = transcript?.segments.last { $0.start <= marker.atSec + 0.5 }
        var draft = DecisionDraft(
            item: item, atSec: marker.atSec, text: marker.note ?? segment?.text ?? "", origin: .marker,
            speaker: segment.map { label($0.speaker) })
        draft.markerID = marker.id
        model.editingDecision = draft
    }

    /// FR-152.2: right click on a passage. Text copied from inside the passage (⌘C) narrows it down.
    private func decide(from segment: Transcript.Segment) {
        guard let item else { return }
        model.editingDecision = DecisionDraft(
            item: item, atSec: segment.start, text: Self.copiedText(within: segment.text) ?? segment.text,
            origin: .selection, speaker: label(segment.speaker))
    }

    private static func copiedText(within text: String) -> String? {
        guard
            let copied = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !copied.isEmpty,
            text.range(of: copied, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        else { return nil }
        return copied
    }

    // MARK: Decisions (FR-150…156)

    private func decisionsSection(_ item: Item) -> some View {
        SectionBox(
            String(localized: "Punti chiave"), systemImage: "checkmark.seal", tint: .green, collapseKey: "decisions"
        ) {
            ForEach(decisions) { summary in
                DecisionRow(model: model, summary: summary, showsProject: false, compact: true)
            }
            if decisions.isEmpty {
                Text(
                    item.type == .document
                        ? String(
                            localized:
                                "Puoi aggiungere una decisione qui sotto, oppure selezionando un passaggio del documento (copialo con ⌘C, poi tasto destro → \"Segna come decisione\")."
                        )
                        : String(
                            localized:
                                "Puoi aggiungere una decisione qui sotto, dal tasto destro su una frase della trascrizione, da un segnalibro o da una nota (\"Promuovi a decisione\")."
                        )
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            Menu {
                ForEach([Decision.Kind.decision, .action, .milestone], id: \.self) { kind in
                    Button {
                        var draft = DecisionDraft(item: item, atSec: nil, text: "", origin: .manual)
                        draft.kind = kind
                        model.editingDecision = draft
                    } label: {
                        Label(DecisionRow.kindLabel(kind), systemImage: DecisionRow.kindIcon(kind))
                    }
                }
            } label: {
                Label(String(localized: "Aggiungi"), systemImage: "plus")
            }
            .fixedSize()
        }
    }

    private func timestampButton(_ seconds: Double) -> some View {
        Button(Format.clock(seconds)) { Task { await listen(at: seconds) } }
            .buttonStyle(.link).monospacedDigit()
            .disabled(!hasAudio)
            .help(String(localized: "Ascolta da questo punto"))
    }

    // MARK: Transcript

    @ViewBuilder
    private func transcriptSection(_ item: Item) -> some View {
        SectionBox(
            String(localized: "Trascrizione"), systemImage: "text.alignleft", tint: .blue, collapseKey: "transcript"
        ) {
            if let transcript {
                Picker("", selection: $tab) {
                    Text(String(localized: "Trascrizione")).tag(Tab.transcript)
                    Text(String(localized: "Markdown")).tag(Tab.markdown)
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 260)
                if transcript.engine.asr == "teams" {
                    Label(String(localized: "Trascrizione Teams importata"), systemImage: "person.2.wave.2")
                        .font(.caption).foregroundStyle(.secondary)
                }
                SpeakerNames(model: model, itemID: itemID, transcript: transcript, speakers: speakers)
                switch tab {
                case .transcript:
                    CappedScroll(isLong: transcript.segments.count > 14) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(transcript.segments, id: \.id) { segment in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    timestampButton(segment.start).frame(width: 64, alignment: .leading)
                                    Text(label(segment.speaker)).fontWeight(.semibold).frame(
                                        width: 110, alignment: .leading)
                                    Text(segment.text).textSelection(.enabled)
                                }
                                .contextMenu {
                                    Button(String(localized: "Segna come decisione…")) { decide(from: segment) }
                                    Button(String(localized: "Ascolta da qui")) {
                                        Task { await listen(at: segment.start) }
                                    }
                                    .disabled(!hasAudio)
                                }
                            }
                        }
                    }
                case .markdown:
                    CappedScroll(isLong: transcript.segments.count > 14) {
                        MarkdownText(markdown: TranscriptRenderer.markdown(document(item, transcript)))
                    }
                }
            } else {
                Text(
                    assets.contains { $0.kind.isAudio }
                        ? String(localized: "Non ancora trascritta.")
                        : String(localized: "Nessuna trascrizione e nessun audio.")
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private func label(_ speakerID: String) -> String {
        speakers.first { $0.speakerId == speakerID }?.label
            ?? transcript?.speakers.first { $0.id == speakerID }?.label ?? speakerID
    }

    private func document(_ item: Item, _ transcript: Transcript) -> ItemDocument {
        ItemDocument(
            item: item, projectName: model.projects.first { $0.id == item.projectId }?.name,
            categoryName: model.categories.first { $0.id == item.categoryId }?.name,
            tags: (try? model.archive.tags(for: itemID).map(\.name)) ?? [],
            speakerLabels: Dictionary(uniqueKeysWithValues: speakers.map { ($0.speakerId, $0.label) }), notes: notes,
            transcript: transcript)
    }

    // MARK: Documents (material to classify)

    private var documentSection: some View {
        SectionBox(String(localized: "Contenuto"), systemImage: "doc.richtext", tint: .teal, collapseKey: "content") {
            if let originalImage {
                Color.clear
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    // Fixed-height box with the image as overlay: the image's aspect ratio never feeds back
                    // into the column's minimum width (that loop crashed the window inside the inspector).
                    .overlay { Image(nsImage: originalImage).resizable().scaledToFit() }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            if let content {
                // FR-191: OCR or conversion mistakes are corrected by hand; the automatic text stays restorable.
                HStack(spacing: 12) {
                    Button(String(localized: "Correggi il testo…")) { editingContent = content }
                        .buttonStyle(.link)
                    if assets.contains(where: { $0.kind == .contentMDAuto }) {
                        Text(String(localized: "Testo corretto a mano")).font(.caption).foregroundStyle(.secondary)
                        Button(String(localized: "Ripristina il testo automatico")) {
                            model.perform { try model.archive.restoreAutomaticMarkdown(itemID: itemID) }
                            self.content = nil
                        }
                        .buttonStyle(.link)
                    }
                }
                .font(.callout)
                CappedScroll(isLong: content.count > 2_500) {
                    MarkdownText(
                        markdown: content.isEmpty ? String(localized: "_(nessun testo riconosciuto)_") : content)
                }
                .contextMenu {
                    Button(String(localized: "Segna come decisione…")) {
                        guard let item else { return }
                        model.editingDecision = DecisionDraft(
                            item: item, atSec: nil, text: Self.copiedText(within: content) ?? "",
                            origin: .selection)
                    }
                }
            } else {
                ProgressView()
            }
        }
    }

    // MARK: Notes (FR-170…173)

    private func notesSection(_ item: Item) -> some View {
        SectionBox(String(localized: "Note"), systemImage: "note.text", tint: .yellow, collapseKey: "notes") {
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(note.notedAt, format: .dateTime.day().month().year().hour().minute()).font(.caption).bold()
                        Text("· \(NoteDraft.label(note.kind))").font(.caption).foregroundStyle(.secondary)
                        ViaClaudeBadge(model: model, entity: .note, id: note.id)
                        if note.input == .voice {
                            Image(systemName: "mic.fill").font(.caption).foregroundStyle(.secondary)
                                .help(String(localized: "Nota dettata"))
                        }
                        if note.updatedAt.timeIntervalSince(note.createdAt) > 1 {
                            Text(
                                String(
                                    localized:
                                        "· modificata il \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))"
                                )
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        PromoteNoteButton(model: model, note: note, item: item)
                        Button(String(localized: "Modifica")) { editingNote = NoteDraft(note) }.buttonStyle(.link)
                        DeleteNoteButton {
                            model.perform { try model.archive.deleteNote(note.id) }; model.refreshTextAssets(itemID)
                        }
                    }
                    MarkdownText(markdown: note.body)
                    NoteAttachments(model: model, noteID: note.id)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.08)))
            }
            Button {
                editingNote = NoteDraft(itemID: itemID)
            } label: {
                Label(String(localized: "Aggiungi nota"), systemImage: "plus")
            }
        }
    }

    private func save(_ draft: NoteDraft) {
        model.saveNote(draft)
    }

    // MARK: Assets (FR-53, FR-60)

    private var assetsSection: some View {
        SectionBox(String(localized: "File"), systemImage: "doc", tint: .gray) {
            ForEach(assets) { asset in
                AssetRow(model: model, asset: asset)
            }
        }
    }
}

// MARK: - Subviews

/// A visually separate card for each part of the item view.
struct SectionBox<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let collapsible: Bool
    let content: Content
    /// Remembered per kind of section (all transcripts, all notes…), not per item.
    @AppStorage private var collapsed: Bool

    /// `collapseKey` makes the section collapsible with a chevron on the left of its title (accordion).
    init(
        _ title: String, systemImage: String, tint: Color = .accentColor, collapseKey: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.collapsible = collapseKey != nil
        self.content = content()
        _collapsed = AppStorage(wrappedValue: false, "section.collapsed.\(collapseKey ?? "fixed")")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if collapsible {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { collapsed.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(collapsed ? 0 : 90))
                            .frame(width: 12)
                        Label(title, systemImage: systemImage).font(.headline).foregroundStyle(tint)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(collapsed ? String(localized: "Apri") : String(localized: "Chiudi"))
                if !collapsed { content }
            } else {
                Label(title, systemImage: systemImage).font(.headline).foregroundStyle(tint)
                content
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10).fill(tint).frame(width: 4)
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
    }
}

/// Long content (transcript, document text) scrolls inside its box past `maxHeight`, so the detail pane never
/// becomes an endless scroll; short content keeps its natural height.
struct CappedScroll<Content: View>: View {
    let isLong: Bool
    var maxHeight: CGFloat = 460
    @ViewBuilder let content: Content

    var body: some View {
        if isLong {
            ScrollView {
                content.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
            }
            .frame(height: maxHeight)
            .overlay(alignment: .bottom) {
                Divider().opacity(0.6)
            }
        } else {
            content
        }
    }
}

private struct DeleteNoteButton: View {
    let action: () -> Void
    @State private var confirming = false

    var body: some View {
        Button(String(localized: "Elimina"), role: .destructive) { confirming = true }
            .buttonStyle(.link)
            .confirmationDialog(String(localized: "Eliminare la nota?"), isPresented: $confirming) {
                Button(String(localized: "Elimina"), role: .destructive, action: action)
            }
    }
}

/// Speaker names, renameable per item (FR-41). Renames never rewrite `transcript.json` (spec 7.3).
private struct SpeakerNames: View {
    let model: AppModel
    let itemID: String
    let transcript: Transcript
    let speakers: [ItemSpeaker]
    @State private var names: [String: String] = [:]

    var body: some View {
        let ids = transcript.speakers.map(\.id).filter { id in transcript.segments.contains { $0.speaker == id } }
        HStack(spacing: 8) {
            Text(String(localized: "Speaker:")).foregroundStyle(.secondary)
            ForEach(ids, id: \.self) { id in
                TextField(
                    "", text: Binding(get: { names[id] ?? current(id) }, set: { names[id] = $0 })
                )
                .textFieldStyle(.roundedBorder).frame(width: 130)
                .onSubmit { rename(id) }
            }
        }
        .onChange(of: speakers) { names = [:] }
    }

    private func current(_ id: String) -> String {
        speakers.first { $0.speakerId == id }?.label ?? transcript.speakers.first { $0.id == id }?.label ?? id
    }

    private func rename(_ id: String) {
        guard let name = names[id]?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
        model.perform { try model.archive.renameSpeaker(id, of: itemID, to: name) }
        model.refreshTextAssets(itemID)
    }
}

private struct PlayerSection: View {
    @Bindable var player: AudioPlayerModel
    /// False while the player holds another item: the controls show this item at rest.
    let isLoaded: Bool
    let duration: Double?
    let tracks: [Asset]
    let play: () -> Void

    var body: some View {
        SectionBox(String(localized: "Audio"), systemImage: "waveform", tint: .purple) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    playButton
                    slider.frame(minWidth: 160)
                    timeLabel
                    trackPicker
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        playButton
                        slider
                    }
                    HStack(spacing: 12) {
                        timeLabel
                        Spacer(minLength: 0)
                        trackPicker
                    }
                }
            }
            if let error = player.error { Text(error).foregroundStyle(.red).font(.caption) }
        }
    }

    private var playButton: some View {
        Button {
            if isLoaded { player.togglePlay() } else { play() }
        } label: {
            Image(systemName: isLoaded && player.isPlaying ? "pause.fill" : "play.fill").frame(width: 18)
        }
        .disabled(player.isLoading)
    }

    private var slider: some View {
        Slider(
            value: Binding(get: { isLoaded ? player.currentTime : 0 }, set: { player.seek(to: $0, play: false) }),
            in: 0...max(isLoaded ? player.duration : duration ?? 0, 1)
        )
        .disabled(!isLoaded)
    }

    private var timeLabel: some View {
        Text(
            isLoaded
                ? "\(Format.clock(player.currentTime)) / \(Format.clock(player.duration))"
                : "\(Format.clock(0)) / \(Format.clock(duration ?? 0))"
        )
        .monospacedDigit()
        .foregroundStyle(.secondary).lineLimit(1).fixedSize()
    }

    @ViewBuilder
    private var trackPicker: some View {
        if tracks.count > 1, isLoaded {
            Picker(
                "",
                selection: Binding(
                    get: { player.asset?.id ?? "" },
                    set: { id in
                        if let asset = tracks.first(where: { $0.id == id }) {
                            Task { await player.switchTrack(to: asset) }
                        }
                    })
            ) {
                ForEach(tracks) { Text($0.kind.trackName).tag($0.id) }
            }
            .labelsHidden().fixedSize()
        }
    }
}

private struct AssetRow: View {
    let model: AppModel
    let asset: Asset
    @State private var deleting = false

    var body: some View {
        HStack {
            Image(systemName: asset.kind.isAudio ? "waveform" : "doc.text").frame(width: 18)
            Text(Self.name(asset.kind))
            Text(Format.bytes(asset.sizeBytes)).foregroundStyle(.secondary)
            Spacer()
            if asset.kind == .transcriptTXT || asset.kind == .transcriptMD {
                Button(String(localized: "Copia")) { copy() }.buttonStyle(.link)
            }
            Button(String(localized: "Esporta…")) { export() }.buttonStyle(.link)
            Button(String(localized: "Elimina…"), role: .destructive) { deleting = true }.buttonStyle(.link)
        }
        .confirmationDialog(
            String(localized: "Eliminare \(Self.name(asset.kind))?"), isPresented: $deleting, titleVisibility: .visible
        ) {
            Button(String(localized: "Sposta nel cestino")) { model.deleteAsset(asset, .trash) }
            Button(String(localized: "Elimina definitivamente"), role: .destructive) {
                model.deleteAsset(asset, .permanent)
            }
        }
    }

    static func name(_ kind: Asset.Kind) -> String {
        switch kind {
        case .audioMix: String(localized: "Audio (mix)")
        case .audioMic: String(localized: "Traccia microfono")
        case .audioSystem: String(localized: "Traccia sistema")
        case .audioImport: String(localized: "Audio importato")
        case .transcriptJSON: String(localized: "Trascrizione (JSON)")
        case .transcriptTXT: String(localized: "Trascrizione (TXT)")
        case .transcriptMD: String(localized: "Trascrizione (Markdown)")
        case .originalDocument: String(localized: "Documento originale")
        case .originalImage: String(localized: "Immagine originale")
        case .contentMD: String(localized: "Contenuto (Markdown)")
        case .originalTranscript: String(localized: "Trascrizione originale (Teams)")
        case .noteAttachment: String(localized: "Allegato")
        case .originalEmail: String(localized: "Email originale (.eml)")
        case .contentMDAuto: String(localized: "Testo automatico (prima delle correzioni)")
        }
    }

    static func fileExtension(_ kind: Asset.Kind) -> String {
        switch kind {
        case .transcriptJSON: "json"
        case .transcriptTXT: "txt"
        case .transcriptMD, .contentMD, .contentMDAuto: "md"
        case .originalEmail: "eml"
        default: "m4a"
        }
    }

    private func export() {
        let panel = NSSavePanel()
        let title = model.item(asset.itemId)?.title ?? "IAGO"
        let base = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let suffix: String =
            switch asset.kind {
            case .audioMic: " - microfono"
            case .audioSystem: " - sistema"
            default: ""
            }
        panel.nameFieldStringValue =
            asset.originalName ?? "\(base)\(suffix).\(Self.fileExtension(asset.kind))"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.perform { try model.archive.readAsset(asset, to: url) }
    }

    private func copy() {
        model.perform {
            let text = String(decoding: try model.archive.readAssetData(asset), as: UTF8.self)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
}

/// Originals kept with a note: open them in their app (decrypted to the scratch folder, spec 9.4).
struct NoteAttachments: View {
    let model: AppModel
    let noteID: String
    @State private var attachments: [Asset] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(attachments) { asset in
                HStack(spacing: 6) {
                    Image(systemName: "paperclip").foregroundStyle(.secondary)
                    Button(asset.originalName ?? String(localized: "Allegato")) { open(asset) }.buttonStyle(.link)
                    Text(Format.bytes(asset.sizeBytes)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .task(id: model.revision) { attachments = (try? model.archive.attachments(noteID: noteID)) ?? [] }
    }

    private func open(_ asset: Asset) {
        let folder = model.archiveService.paths.scratch.appendingPathComponent("open-\(UUID().uuidString)")
        let url = folder.appendingPathComponent(asset.originalName ?? "allegato")
        model.perform {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try model.archive.readAsset(asset, to: url)
            NSWorkspace.shared.open(url)
        }
    }
}

/// Correcting the Markdown of a document or email (FR-191).
struct MarkdownEditSheet: View {
    @State var text: String
    let save: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Correggi il testo")).font(.title3).bold()
            Text(
                String(
                    localized:
                        "Markdown: # titoli, **grassetto**, - elenchi. Il testo estratto automaticamente resta conservato e si può ripristinare."
                )
            )
            .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minHeight: 380)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(String(localized: "Salva")) {
                    save(text)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 720)
    }
}
