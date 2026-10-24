import AppKit
import IAGOExport
import IAGOStore
import SwiftUI
import UniformTypeIdentifiers

/// What is being exported: the items of the current view, with the filters applied (FR-91).
struct ExportScope {
    var title: String
    var itemIDs: [String]
    var projectNoteIDs: [String]
    var decisionScope: DecisionQuery.Scope?
    var filtersDescription: String

    @MainActor
    static func current(_ model: AppModel) -> ExportScope {
        var title = String(localized: "Archivio IAGO")
        var projectNoteIDs: [String] = []
        switch model.sidebar {
        case .library(.project(let id)):
            title = model.project(id)?.name ?? title
            projectNoteIDs = [id]
        case .library(.client(let id)):
            title = model.client(id)?.name ?? title
            projectNoteIDs = model.projects.filter { $0.clientId == id }.map(\.id)
        case .library(.stream(let id)):
            if let stream = model.stream(id) {
                title = "\(model.project(stream.projectId)?.name ?? "") · \(stream.name)"
            }
        case .library(.unclassified): title = String(localized: "Da classificare")
        case .library(.undefinedProject): title = String(localized: "Non definito")
        case .library(.category(let id)): title = model.categories.first { $0.id == id }?.name ?? title
        case .library(.tag(let id)): title = "#" + (model.tags.first { $0.id == id }?.name ?? "")
        default: break
        }
        return ExportScope(
            title: title, itemIDs: model.summaries.map(\.id), projectNoteIDs: projectNoteIDs,
            decisionScope: model.decisionScope, filtersDescription: describe(model.filter, model: model))
    }

    @MainActor
    static func describe(_ filter: AppModel.LibraryFilter, model: AppModel) -> String {
        var parts: [String] = []
        if let id = filter.categoryID, let name = model.categories.first(where: { $0.id == id })?.name {
            parts.append("categoria \(name)")
        }
        if !filter.tags.isEmpty { parts.append("tag " + filter.tags.sorted().map { "#\($0)" }.joined(separator: " ")) }
        if let type = filter.type { parts.append("tipo \(type.rawValue)") }
        if let from = filter.from { parts.append("dal \(from.formatted(date: .numeric, time: .omitted))") }
        if let to = filter.to { parts.append("al \(to.formatted(date: .numeric, time: .omitted))") }
        return parts.isEmpty ? "nessuno" : parts.joined(separator: ", ")
    }
}

/// "Esporta per LLM…" (FR-90/91): one Markdown file, token estimate before saving or copying.
struct LLMExportSheet: View {
    let model: AppModel
    let scope: ExportScope
    @Environment(\.dismiss) private var dismiss
    @State private var includeNotes = true
    @State private var includeDecisions = true
    @State private var fullDocuments = true
    @State private var markdown: String?
    @State private var building = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(String(localized: "Esporta per LLM"), systemImage: "doc.text.magnifyingglass").font(.title3).bold()
            Text(
                String(
                    localized:
                        "«\(scope.title)»: \(scope.itemIDs.count) elementi della vista attuale (filtri: \(scope.filtersDescription)), in ordine cronologico, in un unico file Markdown da dare a Claude o a un altro LLM."
                )
            )
            .foregroundStyle(.secondary)
            Toggle(String(localized: "Note (degli elementi e di progetto)"), isOn: $includeNotes)
            Toggle(String(localized: "Registro decisioni"), isOn: $includeDecisions)
                .disabled(scope.decisionScope == nil)
            Picker(String(localized: "Documenti"), selection: $fullDocuments) {
                Text(String(localized: "Interi")).tag(true)
                Text(String(localized: "Solo un estratto")).tag(false)
            }
            .pickerStyle(.segmented).fixedSize()
            HStack(spacing: 8) {
                if building {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "Preparazione…")).foregroundStyle(.secondary)
                } else if let markdown {
                    Image(systemName: "number").foregroundStyle(.secondary)
                    Text(
                        String(
                            localized:
                                "Circa \(ProjectExporter.estimatedTokens(markdown).formatted()) token · \(markdown.count.formatted()) caratteri"
                        )
                    )
                    .monospacedDigit()
                    .help(String(localized: "Stima: circa un token ogni 3,6 caratteri di testo italiano"))
                }
            }
            .frame(height: 20)
            Label(
                String(
                    localized: "Il file esportato non è cifrato: trattalo con la stessa cura dei documenti originali."),
                systemImage: "lock.open"
            )
            .font(.caption).foregroundStyle(.orange)
            HStack {
                Spacer()
                Button(String(localized: "Chiudi"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(String(localized: "Copia negli appunti")) { copy() }.disabled(markdown == nil)
                Button(String(localized: "Salva…")) { save() }.keyboardShortcut(.defaultAction).disabled(
                    markdown == nil)
            }
        }
        .padding(20)
        .frame(width: 560)
        .task(id: "\(includeNotes)\(includeDecisions)\(fullDocuments)") { await build() }
    }

    private func build() async {
        building = true
        defer { building = false }
        let options = ProjectExporter.Options(
            title: scope.title, itemIDs: scope.itemIDs, projectNoteIDs: scope.projectNoteIDs,
            decisionScope: scope.decisionScope, includeNotes: includeNotes, includeDecisions: includeDecisions,
            documents: fullDocuments ? .full : .excerpt(1_500), filtersDescription: scope.filtersDescription)
        let archive = model.archive
        do {
            markdown = try await Task.detached(priority: .userInitiated) {
                try ProjectExporter.markdown(options, archive: archive)
            }.value
        } catch {
            model.lastError = ErrorText.describe(error)
        }
    }

    private func copy() {
        guard let markdown else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        audit("copied")
        dismiss()
    }

    private func save() {
        guard let markdown else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue =
            "\(scope.title.replacingOccurrences(of: "/", with: "-")) - IAGO \(Date().formatted(.iso8601.year().month().day())).md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.perform { try Data(markdown.utf8).write(to: url) }
        audit("saved")
        dismiss()
    }

    private func audit(_ how: String) {
        try? model.archive.audit(
            .export, action: "llm_markdown_\(how)", detail: "\(scope.itemIDs.count) items, scope \(scope.title)")
    }
}

/// "Esporta audio…": decrypted copies of the audio of the current view, for sharing or keeping elsewhere.
struct AudioExportSheet: View {
    let model: AppModel
    let scope: ExportScope
    @Environment(\.dismiss) private var dismiss
    @State private var includeTranscripts = true
    @State private var progress: Double?
    @State private var done: (count: Int, folder: URL)?

    var body: some View {
        let ids = Set(scope.itemIDs)
        let withAudio = ((try? model.archive.summaries(.recent)) ?? []).filter { ids.contains($0.id) && $0.hasAudio }
        VStack(alignment: .leading, spacing: 14) {
            Label(String(localized: "Esporta audio"), systemImage: "waveform.badge.plus").font(.title3).bold()
            Text(
                String(
                    localized:
                        "«\(scope.title)»: \(withAudio.count) elementi con audio nella vista attuale. Ogni audio diventa un normale file .m4a nella cartella che scegli."
                )
            )
            .foregroundStyle(.secondary)
            Toggle(String(localized: "Anche la trascrizione (.md) accanto a ogni audio"), isOn: $includeTranscripts)
            Label(
                String(
                    localized:
                        "I file esportati non sono cifrati: chi li riceve può ascoltarli. L'esportazione viene annotata nel registro di IAGO."
                ),
                systemImage: "lock.open"
            )
            .font(.caption).foregroundStyle(.orange)
            if let progress { ProgressView(value: progress) }
            if let done {
                HStack {
                    Label(String(localized: "\(done.count) file esportati"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button(String(localized: "Mostra nel Finder")) { NSWorkspace.shared.open(done.folder) }
                        .buttonStyle(.link)
                }
            }
            HStack {
                Spacer()
                Button(done == nil ? String(localized: "Annulla") : String(localized: "Chiudi"), role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(progress != nil && done == nil)
                if done == nil {
                    Button(String(localized: "Scegli cartella ed esporta…")) { export(withAudio.map(\.id)) }
                        .keyboardShortcut(.defaultAction)
                        .disabled(withAudio.isEmpty || progress != nil)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func export(_ itemIDs: [String]) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Esporta qui")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let archive = model.archive
        let transcripts = includeTranscripts
        progress = 0
        let work = model.activity.begin(.exportAudio, folder.lastPathComponent)
        Task {
            var count = 0
            for (index, id) in itemIDs.enumerated() {
                count += await Task.detached(priority: .userInitiated) {
                    (try? Self.exportItem(id, to: folder, transcripts: transcripts, archive: archive)) ?? 0
                }.value
                progress = Double(index + 1) / Double(itemIDs.count)
                model.activity.update(work, fraction: progress ?? 0)
            }
            model.activity.end(work)
            try? archive.audit(
                .export, action: "audio", detail: "\(itemIDs.count) items, scope \(scope.title), \(count) files")
            done = (count, folder)
        }
    }

    /// Writes `2026-10-13 1530 Titolo.m4a` (the preferred track) and, if asked, the transcript next to it.
    nonisolated static func exportItem(_ id: String, to folder: URL, transcripts: Bool, archive: Archive) throws -> Int
    {
        guard let item = try archive.item(id) else { return 0 }
        let assets = try archive.assets(itemID: id)
        let order: [Asset.Kind] = [.audioMix, .audioImport, .audioMic, .audioSystem]
        guard let audio = order.lazy.compactMap({ kind in assets.first { $0.kind == kind } }).first else { return 0 }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        let safeTitle = item.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        var base = "\(formatter.string(from: item.occurredAt)) \(safeTitle)"
        var suffix = 2
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(base).m4a").path) {
            base = "\(formatter.string(from: item.occurredAt)) \(safeTitle) (\(suffix))"
            suffix += 1
        }
        try archive.readAsset(audio, to: folder.appendingPathComponent("\(base).m4a"))
        var written = 1
        if transcripts, assets.contains(where: { $0.kind == .transcriptJSON }) {
            let markdown = TranscriptRenderer.markdown(try ItemDocument.load(id, from: archive))
            try Data(markdown.utf8).write(to: folder.appendingPathComponent("\(base).md"))
            written += 1
        }
        return written
    }
}
