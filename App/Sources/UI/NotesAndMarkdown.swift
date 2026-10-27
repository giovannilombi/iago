import IAGOEngine
import IAGOIngest
import IAGOIntelligence
import IAGOStore
import SwiftUI
import UniformTypeIdentifiers

/// A file dropped or pasted into a note: its text is added to the note; the original is kept only if the
/// user asks (e.g. a Gantt chart, where the image matters).
struct PendingAttachment: Identifiable, Equatable {
    let id = UUID()
    var file: URL
    var originalName: String
}

/// A note being added or edited (FR-170, FR-171): Markdown text, editable date, optional type, attachments.
struct NoteDraft: Identifiable {
    var id: String?
    /// The item the note is on, or nil for a project note (FR-172).
    var itemID: String?
    var projectID: String?
    var body = ""
    var notedAt = Date()
    var kind = Note.Kind.note
    /// Dictated (FR-218): shown with a microphone icon.
    var input = Note.Input.typed
    /// Originals to keep, stored when the note is saved.
    var pending: [PendingAttachment] = []
    /// ADR-0047: streams of the note's project.
    var streamIDs: [String] = []

    init(itemID: String) {
        self.itemID = itemID
    }

    init(projectID: String) {
        self.projectID = projectID
    }

    init(_ note: Note) {
        id = note.id
        itemID = note.itemId
        projectID = note.projectId
        body = note.body
        notedAt = note.notedAt
        kind = note.kind
        input = note.input
    }

    static func label(_ kind: Note.Kind) -> String {
        switch kind {
        case .note: String(localized: "Nota")
        case .email: String(localized: "Email")
        case .lateDecision: String(localized: "Decisione successiva")
        case .update: String(localized: "Aggiornamento")
        }
    }
}

struct NoteEditor: View {
    let model: AppModel
    @State var draft: NoteDraft
    let onSave: (NoteDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var existing: [Asset] = []
    @State private var extracting: [String] = []
    /// A file whose text has been extracted, waiting for "text only" or "text and original".
    @State private var choice: (file: URL, name: String, markdown: String)?
    @State private var isDropTargeted = false
    @State private var recorder: VoiceNoteRecorder?
    /// FR-213: dictated text goes after the existing text (default) or replaces it.
    @State private var replaceWithDictation = false
    /// "Riordina testo" (FR-219, ADR-0048): running, then the proposal to confirm.
    @State private var tidying: Task<Void, Never>?
    @State private var tidied: TidyProposal?

    struct TidyProposal: Identifiable {
        let id = UUID()
        let original: String
        let text: String
        let modelName: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.id == nil ? String(localized: "Nuova nota") : String(localized: "Modifica nota")).font(.title3)
                .bold()
            HStack {
                DatePicker(String(localized: "Data"), selection: $draft.notedAt)
                Picker(String(localized: "Tipo"), selection: $draft.kind) {
                    ForEach(Note.Kind.allCases, id: \.self) { Text(NoteDraft.label($0)).tag($0) }
                }
                .frame(maxWidth: 240)
            }
            if let projectID = streamProjectID, !model.streams(of: projectID).isEmpty {
                HStack(alignment: .top) {
                    Text(String(localized: "Stream")).foregroundStyle(.secondary)
                    StreamChooser(model: model, projectID: projectID, selection: $draft.streamIDs)
                }
            }
            if let recorder {
                DictationBar(recorder: recorder, replace: $replaceWithDictation, hasText: hasText) {
                    dictate(recorder)
                }
            }
            TextEditor(text: $draft.body)
                .font(.body).frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 6).stroke(
                        isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: isDropTargeted ? 2 : 1)
                )
                .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted) { providers in
                    Task { await receive(providers) }
                    return true
                }
                .onPasteCommand(of: [.fileURL, .png, .tiff, .image]) { providers in
                    Task { await receive(providers) }
                }
            HStack {
                Button(String(localized: "Incolla immagine"), systemImage: "doc.on.clipboard") { pasteFromClipboard() }
                    .help(String(localized: "Incolla lo screenshot o l'immagine copiata negli appunti (⌘⇧V)"))
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button(String(localized: "Allega file…"), systemImage: "paperclip") { chooseFiles() }
                if tidying != nil {
                    ProgressView().controlSize(.small)
                    Button(String(localized: "Ferma")) {
                        tidying?.cancel()
                        tidying = nil
                    }
                } else {
                    Button(String(localized: "Riordina testo"), systemImage: "cpu") { tidy() }
                        .disabled(!hasText)
                        .help(
                            String(
                                localized:
                                    "Toglie intercalari e ripetizioni con il motore locale; vedi il risultato prima di sostituire"
                            ))
                }
                Text(
                    String(
                        localized:
                            "Oppure trascina o incolla immagini, screenshot, PDF e documenti: il testo viene estratto in Markdown."
                    )
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(extracting, id: \.self) { name in
                HStack {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "Estrazione del testo da \(name)…")).font(.caption)
                }
            }
            if !existing.isEmpty || !draft.pending.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Allegati conservati")).font(.caption).bold()
                    ForEach(existing) { asset in
                        HStack {
                            Image(systemName: "paperclip")
                            Text(asset.originalName ?? String(localized: "Allegato"))
                            Spacer()
                            Button(String(localized: "Rimuovi"), role: .destructive) {
                                model.perform { try model.archive.purgeAsset(asset.id) }
                                existing.removeAll { $0.id == asset.id }
                            }
                            .buttonStyle(.link)
                        }
                    }
                    ForEach(draft.pending) { attachment in
                        HStack {
                            Image(systemName: "paperclip")
                            Text(attachment.originalName)
                            Spacer()
                            Button(String(localized: "Rimuovi"), role: .destructive) {
                                draft.pending.removeAll { $0.id == attachment.id }
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
                .font(.callout)
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) {
                    recorder?.discardAudio()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(String(localized: "Salva")) {
                    onSave(draft)
                    // The text is in the note now: the audio is deleted (FR-215).
                    recorder?.finish()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !extracting.isEmpty
                        || recorder?.state == .recording || recorder?.state == .transcribing)
            }
        }
        .padding(20)
        .frame(width: 620)
        .task {
            guard let id = draft.id else { return }
            existing = (try? model.archive.attachments(noteID: id)) ?? []
            draft.streamIDs = (try? model.archive.streamIDs(noteID: id)) ?? []
        }
        .onAppear { if recorder == nil { recorder = VoiceNoteRecorder(service: model.voiceNotes) } }
        .onChange(of: recorder?.transcribedText) { _, text in
            guard let text else { return }
            insert(text)
            recorder?.transcribedText = nil
        }
        .onDisappear {
            if recorder?.isRecording == true { recorder?.discardAudio() }
            tidying?.cancel()
        }
        .sheet(item: Binding(get: { model.engine.neededFor }, set: { model.engine.neededFor = $0 })) { feature in
            EngineNeededSheet(model: model, feature: feature)
        }
        .sheet(item: $tidied) { proposal in
            TidyPreviewSheet(original: proposal.original, tidied: proposal.text, modelName: proposal.modelName) {
                draft.body = proposal.text
            }
        }
        .confirmationDialog(
            String(localized: "Cosa conservare di \"\(choice?.name ?? "")\"?"),
            isPresented: Binding(get: { choice != nil }, set: { if !$0 { choice = nil } }), titleVisibility: .visible
        ) {
            Button(String(localized: "Solo il testo (Markdown)")) { accept(keepOriginal: false) }
            Button(String(localized: "Il testo e il file originale")) { accept(keepOriginal: true) }
        } message: {
            Text(
                String(
                    localized:
                        "Il testo estratto viene aggiunto alla nota. Conserva anche l'originale se l'immagine conta (per esempio un Gantt o uno schema)."
                ))
        }
    }

    /// The project whose streams the note can join: its own, or its item's.
    private var streamProjectID: String? { draft.projectID ?? draft.itemID.flatMap { model.item($0)?.projectId } }

    /// Only with the engine the user chose; without one, "Serve un motore locale" explains how to get it.
    private func tidy() {
        guard let engine = model.engine.engine(for: .tidyText) else { return }
        let original = draft.body
        tidying = Task {
            let work = model.activity.begin(.tidy, engine.modelName)
            defer { model.activity.end(work) }
            do {
                // The user waits for the preview: it goes first in the engine lane (ADR-0069).
                let text = try await EngineLane.$interactive.withValue(true) {
                    try await TextTidier.tidy(original, with: engine)
                }
                if !Task.isCancelled, !text.isEmpty {
                    tidied = TidyProposal(original: original, text: text, modelName: engine.modelName)
                }
            } catch is CancellationError {
            } catch {
                model.lastError = String(localized: "Riordino non riuscito: \(ErrorText.describe(error))")
            }
            tidying = nil
        }
    }

    private var hasText: Bool { !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Microphone button: first click records, second stops and transcribes (FR-210, FR-211).
    private func dictate(_ recorder: VoiceNoteRecorder) {
        // The text arrives through `transcribedText` (see `onChange`), also when a call stops the dictation.
        if recorder.isRecording {
            Task { _ = await recorder.stopAndTranscribe() }
        } else if case .failed = recorder.state {
            Task { _ = await recorder.transcribe() }
        } else {
            Task {
                guard await MicrophonePermission.ensure() else { return }
                do {
                    try recorder.start(
                        target: VoiceNoteTarget(
                            itemID: draft.itemID, projectID: draft.projectID, noteID: draft.id, startedAt: Date()))
                } catch {
                    model.lastError = String(
                        localized: "Impossibile avviare il microfono: \(ErrorText.describe(error))")
                }
            }
        }
    }

    private func insert(_ text: String) {
        guard !text.isEmpty else { return }
        draft.input = .voice
        if !hasText || replaceWithDictation {
            draft.body = text
        } else {
            draft.body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + text
        }
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        Task { for url in panel.urls { await extract(url, name: url.lastPathComponent) } }
    }

    /// Screenshots copied with ⌘⇧⌃4 and images copied from other apps (⌘V in the text inserts text only).
    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            as? [URL],
            !urls.isEmpty
        {
            Task { for url in urls { await extract(url, name: url.lastPathComponent) } }
            return
        }
        guard let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation,
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else {
            model.lastError = String(localized: "Negli appunti non c'è un'immagine né un file.")
            return
        }
        let name = String(localized: "Immagine incollata \(Date().formatted(date: .numeric, time: .shortened))")
            .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ".")
        let url = model.archiveService.paths.scratch.appendingPathComponent("\(UUID().uuidString)/\(name).png")
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try png.write(to: url)
            Task { await extract(url, name: url.lastPathComponent) }
        } catch {
            model.lastError = ErrorText.describe(error)
        }
    }

    private func receive(_ providers: [NSItemProvider]) async {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
                let url = await loadURL(provider)
            {
                await extract(url, name: url.lastPathComponent)
            } else if let file = await loadImage(provider) {
                await extract(file, name: file.lastPathComponent)
            }
        }
    }

    private func loadURL(_ provider: NSItemProvider) async -> URL? {
        let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        return nil
    }

    /// Pasted or dragged image data (e.g. a screenshot from the clipboard), saved as PNG in the scratch folder.
    private func loadImage(_ provider: NSItemProvider) async -> URL? {
        let data: Data? = await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: .image) { data, _ in continuation.resume(returning: data) }
        }
        guard let data, let image = NSImage(data: data),
            let tiff = image.tiffRepresentation,
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return nil }
        let name = String(localized: "Immagine incollata \(Date().formatted(date: .numeric, time: .shortened))")
            .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ".")
        let url = model.archiveService.paths.scratch.appendingPathComponent("\(UUID().uuidString)/\(name).png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? png.write(to: url)) != nil else { return nil }
        return url
    }

    private func extract(_ url: URL, name: String) async {
        extracting.append(name)
        defer { extracting.removeAll { $0 == name } }
        do {
            let extraction = try await Task.detached(priority: .userInitiated) { try ContentExtractor.extract(url) }
                .value
            choice = (url, name, extraction.markdown)
        } catch {
            model.lastError = String(localized: "Impossibile leggere \(name): \(ErrorText.describe(error))")
        }
    }

    private func accept(keepOriginal: Bool) {
        guard let choice else { return }
        let text = choice.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let block =
            "#### \(choice.name)\n\n" + (text.isEmpty ? String(localized: "_(nessun testo riconosciuto)_") : text)
        draft.body =
            draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? block : draft.body + "\n\n" + block
        if keepOriginal {
            // Copied to the scratch folder: the source may be a temporary file of the pasteboard.
            let copy = model.archiveService.paths.scratch.appendingPathComponent("\(UUID().uuidString)-\(choice.name)")
            if (try? FileManager.default.copyItem(at: choice.file, to: copy)) != nil {
                draft.pending.append(PendingAttachment(file: copy, originalName: choice.name))
            }
        }
        self.choice = nil
    }
}

/// Minimal Markdown view: headings, list items and inline styles (bold, italics, links, code).
struct MarkdownText: View {
    let markdown: String
    /// Where `![…](img/x.png)` images are (the user guide); without it images are not shown.
    var baseURL: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let text):
                    inline(text).font(level == 1 ? .title2 : level == 2 ? .title3 : .headline).bold().padding(.top, 6)
                case .bullet(let text):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•")
                        inline(text)
                    }
                case .rule:
                    Divider()
                case .paragraph(let text):
                    inline(text)
                case .blank:
                    Spacer().frame(height: 4)
                case .table(let rows):
                    table(rows)
                case .numbered(let number, let text):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(number).").monospacedDigit().foregroundStyle(.secondary)
                        inline(text)
                    }
                case .quote(let text):
                    HStack(alignment: .top, spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 3)
                        inline(text).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                case .image(let alt, let path):
                    image(alt, path)
                }
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Block {
        case heading(Int, String)
        case bullet(String)
        case rule
        case paragraph(String)
        case blank
        /// A Markdown table (summaries, ADR-0054): the header first, separator rows dropped.
        case table([[String]])
        case numbered(Int, String)
        case quote(String)
        case image(alt: String, path: String)
    }

    private var blocks: [Block] {
        var result: [Block] = []
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("|") {
                let cells = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if cells.allSatisfy({ $0.allSatisfy { "-: ".contains($0) } }) { continue }
                if case .table(let rows)? = result.last {
                    result[result.count - 1] = .table(rows + [cells])
                } else {
                    result.append(.table([cells]))
                }
                continue
            }
            result.append(block(line))
        }
        return result
    }

    private func table(_ rows: [[String]]) -> some View {
        let width = rows.map(\.count).max() ?? 0
        return Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                GridRow(alignment: .firstTextBaseline) {
                    ForEach(0..<width, id: \.self) { column in
                        inline(column < row.count ? row[column] : "")
                            .font(index == 0 ? .caption.weight(.semibold) : .callout)
                            .foregroundStyle(index == 0 ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if index == 0 { Divider().gridCellUnsizedAxes(.horizontal) }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    @ViewBuilder
    private func image(_ alt: String, _ path: String) -> some View {
        if let url = baseURL?.appendingPathComponent(path), let picture = NSImage(contentsOf: url) {
            VStack(alignment: .leading, spacing: 4) {
                Image(nsImage: picture).resizable().scaledToFit()
                    .frame(maxWidth: min(picture.size.width, 900))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                if !alt.isEmpty { Text(alt).font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.vertical, 6)
        }
    }

    private func block(_ line: String) -> Block {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .blank }
        if trimmed == "---" { return .rule }
        if let match = trimmed.firstMatch(of: /^(#{1,6})\s+(.*)$/) {
            return .heading(match.1.count, String(match.2))
        }
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") { return .bullet(String(trimmed.dropFirst(2))) }
        if let match = trimmed.firstMatch(of: /^(\d+)\.\s+(.*)$/), let number = Int(match.1) {
            return .numbered(number, String(match.2))
        }
        if trimmed.hasPrefix("> ") { return .quote(String(trimmed.dropFirst(2))) }
        if let match = trimmed.firstMatch(of: /^!\[(.*)\]\((.*)\)$/) {
            return .image(alt: String(match.1), path: String(match.2))
        }
        return .paragraph(line)
    }

    private func inline(_ text: String) -> Text {
        // `{{icona}}` in the guide: IAGO's menu bar icon inside the sentence, so it is recognised at once.
        if text.contains("{{icona}}") {
            let parts = text.components(separatedBy: "{{icona}}")
            var result = Text("")
            for (index, part) in parts.enumerated() {
                if index > 0, let icon = MenuBarIcon.image(.none, accessibility: "IAGO") {
                    result = result + Text(Image(nsImage: icon)).baselineOffset(-3)
                }
                result = result + plainInline(part)
            }
            return result
        }
        return plainInline(text)
    }

    private func plainInline(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        {
            return Text(attributed)
        }
        return Text(text)
    }
}

/// Microphone row of the note editor (FR-210…214): record / stop, level and duration, "Aggiungi in coda" or
/// "Sostituisci", and the failure state with "Riprova" / "Scarta audio" (FR-215).
struct DictationBar: View {
    @Bindable var recorder: VoiceNoteRecorder
    @Binding var replace: Bool
    let hasText: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            switch recorder.state {
            case .idle:
                Button(action: toggle) {
                    Label(
                        hasText ? String(localized: "Ri-registra") : String(localized: "Detta"), systemImage: "mic.fill"
                    )
                }
                .help(String(localized: "Detta la nota: viene trascritta subito e l'audio non viene conservato"))
                if hasText {
                    Picker("", selection: $replace) {
                        Text(String(localized: "Aggiungi in coda")).tag(false)
                        Text(String(localized: "Sostituisci")).tag(true)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
            case .recording:
                Button(action: toggle) {
                    Label(String(localized: "Stop"), systemImage: "stop.circle.fill")
                }
                .tint(.red)
                .keyboardShortcut(.return, modifiers: [.command])
                LevelMeter(level: recorder.level).frame(width: 90, height: 6)
                Text(Format.clock(recorder.elapsed)).monospacedDigit().foregroundStyle(.secondary)
                Circle().fill(Color.red).frame(width: 8, height: 8)
            case .transcribing:
                ProgressView().controlSize(.small)
                Text(String(localized: "Trascrizione della nota…")).foregroundStyle(.secondary)
            case .failed(let reason):
                Label(String(localized: "Trascrizione non riuscita"), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).help(reason)
                Button(String(localized: "Riprova"), action: toggle)
                Button(String(localized: "Scarta audio"), role: .destructive) { recorder.discardAudio() }
            }
            Spacer()
        }
        .font(.callout)
    }
}

/// Input level of the microphone while dictating.
struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(Color.green).frame(width: geometry.size.width * CGFloat(min(1, sqrt(level))))
            }
        }
    }
}
