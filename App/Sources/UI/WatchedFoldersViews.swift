import AppKit
import IAGOIngest
import IAGOStore
import SwiftUI

/// Settings › Email e persone: watched folders, import rules and discarded files (ADR-0050).
struct WatchedFoldersSettings: View {
    let model: AppModel
    @State private var discarded: [WatchedFile] = []
    @State private var editingRule: ImportRule?

    private var importer: FolderImporter { model.folderImporter }

    var body: some View {
        SettingsGroup(
            title: String(localized: "Cartelle sorvegliate"),
            footnote: String(
                localized:
                    "IAGO importa da solo le email (.eml) salvate in queste cartelle, anche nelle sottocartelle, e solo quelle nuove. Per esempio: una regola di Power Automate che salva le email di Outlook in una cartella di OneDrive sincronizzata sul Mac. IAGO legge solo file sul Mac."
            )
        ) {
            ForEach(importer.folders) { folder in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "folder")
                        Text(folder.path).lineLimit(1).truncationMode(.middle).help(folder.path)
                        Spacer()
                        Toggle(
                            String(localized: "Attiva"),
                            isOn: Binding(
                                get: { folder.enabled },
                                set: { value in importer.update(folder) { $0.enabled = value } })
                        )
                        .toggleStyle(.switch).controlSize(.small)
                        Button(String(localized: "Togli"), role: .destructive) { importer.remove(folder) }
                            .buttonStyle(.link)
                    }
                    Toggle(
                        String(localized: "Sposta le email importate nella sottocartella «Importate»"),
                        isOn: Binding(
                            get: { folder.moveImported },
                            set: { value in importer.update(folder) { $0.moveImported = value } })
                    )
                    .font(.caption)
                    if let last = folder.lastScanAt {
                        Text(
                            String(
                                localized: "Ultimo controllo: \(last.formatted(date: .abbreviated, time: .shortened))")
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
            }
            HStack {
                Button(String(localized: "Aggiungi cartella…"), systemImage: "folder.badge.plus") { chooseFolder() }
                Button(String(localized: "Controlla ora")) { Task { await importer.scanAll() } }
                    .disabled(importer.folders.isEmpty || importer.scanning)
                if importer.scanning { ProgressView().controlSize(.small) }
                Spacer()
                if let summary = importer.lastSummary {
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        SettingsGroup(
            title: String(localized: "Regole di importazione"),
            footnote: String(
                localized:
                    "Prima si applicano le esclusioni, poi le assegnazioni, nell'ordine. Senza una regola che assegna, l'email va nel progetto proposto da IAGO solo se la proposta è sicura (stessa conversazione o persone già note); altrimenti resta in «Da classificare»."
            )
        ) {
            Toggle(
                String(localized: "Scarta inviti e risposte ai meeting"),
                isOn: Binding(get: { importer.builtIn.meetings }, set: { importer.builtIn.meetings = $0 }))
            Toggle(
                String(localized: "Scarta le risposte automatiche (fuori sede)"),
                isOn: Binding(get: { importer.builtIn.autoReplies }, set: { importer.builtIn.autoReplies = $0 }))
            Toggle(
                String(localized: "Scarta newsletter e liste di distribuzione"),
                isOn: Binding(get: { importer.builtIn.newsletters }, set: { importer.builtIn.newsletters = $0 }))
            Divider()
            ForEach(Array(importer.rules.enumerated()), id: \.element.id) { index, rule in
                HStack {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { rule.enabled },
                            set: { value in
                                var rules = importer.rules
                                rules[index].enabled = value
                                importer.rules = rules
                            })
                    )
                    .labelsHidden()
                    Text(describe(rule)).lineLimit(2)
                    Spacer()
                    Button(String(localized: "Modifica…")) { editingRule = rule }.buttonStyle(.link)
                    Button(String(localized: "Elimina"), role: .destructive) {
                        var rules = importer.rules
                        rules.remove(at: index)
                        importer.rules = rules
                    }
                    .buttonStyle(.link)
                }
            }
            HStack {
                Button(String(localized: "Nuova esclusione…")) {
                    editingRule = ImportRule(
                        id: model.archive.newRuleID(), action: .exclude, field: .subject, pattern: "")
                }
                Button(String(localized: "Nuova assegnazione…")) {
                    editingRule = ImportRule(
                        id: model.archive.newRuleID(), action: .assign, field: .domain, pattern: "",
                        projectID: model.projects.first?.id)
                }
            }
        }
        .sheet(item: $editingRule) { rule in
            ImportRuleEditor(model: model, rule: rule) { saved in
                var rules = importer.rules
                if let index = rules.firstIndex(where: { $0.id == saved.id }) {
                    rules[index] = saved
                } else {
                    rules.append(saved)
                }
                importer.rules = rules
            }
        }
        if !discarded.isEmpty {
            SettingsGroup(
                title: String(localized: "Scartate e non riuscite"),
                footnote: String(
                    localized: "Le email che le regole hanno lasciato fuori, o che non si sono potute leggere.")
            ) {
                ForEach(discarded.prefix(50)) { file in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.subject ?? URL(fileURLWithPath: file.path).lastPathComponent).lineLimit(1)
                            Text(file.reason ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        Button(String(localized: "Importa comunque")) {
                            Task {
                                await importer.importAnyway(file)
                                load()
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
        EmptyView()
            .task(id: importer.revision) { load() }
    }

    private func load() { discarded = (try? model.archive.discardedWatchedFiles()) ?? [] }

    private func describe(_ rule: ImportRule) -> String {
        let field = ImportRules.label(rule.field)
        switch rule.action {
        case .exclude: return String(localized: "Escludi se \(field) contiene «\(rule.pattern)»")
        case .assign:
            let project = rule.projectID.flatMap { model.project($0)?.name } ?? "?"
            let stream = rule.streamID.flatMap { model.stream($0)?.name }
            return String(localized: "Assegna a «\(project)»") + (stream.map { " › \($0)" } ?? "")
                + String(localized: " se \(field) contiene «\(rule.pattern)»")
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Sorveglia")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importer.add(url)
        Task { await importer.scanAll() }
    }
}

struct ImportRuleEditor: View {
    let model: AppModel
    @State var rule: ImportRule
    let onSave: (ImportRule) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(rule.action == .exclude ? String(localized: "Esclusione") : String(localized: "Assegnazione"))
                .font(.title3).bold()
            Picker(String(localized: "Se"), selection: $rule.field) {
                ForEach(ImportRule.Field.allCases, id: \.self) { field in
                    Text(ImportRules.label(field)).tag(field)
                }
            }
            .fixedSize()
            TextField(String(localized: "contiene…"), text: $rule.pattern).textFieldStyle(.roundedBorder)
            if rule.action == .assign {
                Picker(String(localized: "Progetto"), selection: $rule.projectID) {
                    ForEach(model.projects) { project in Text(project.name).tag(Optional(project.id)) }
                }
                .fixedSize()
                if let projectID = rule.projectID, !model.streams(of: projectID).isEmpty {
                    Picker(String(localized: "Stream"), selection: $rule.streamID) {
                        Text(String(localized: "Nessuno")).tag(String?.none)
                        ForEach(model.streams(of: projectID)) { stream in Text(stream.name).tag(Optional(stream.id)) }
                    }
                    .fixedSize()
                }
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(String(localized: "Salva")) {
                    onSave(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    rule.pattern.trimmingCharacters(in: .whitespaces).isEmpty
                        || (rule.action == .assign && rule.projectID == nil))
            }
        }
        .padding(20).frame(width: 440)
    }
}
