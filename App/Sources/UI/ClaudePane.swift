import AppKit
import IAGOStore
import SwiftUI

/// Impostazioni › Claude (FR-130…132, ADR-0043): which projects Claude can read, how to connect Claude Desktop
/// or Claude Code to IAGO's MCP server, and every access Claude made.
struct ClaudePane: View {
    let model: AppModel
    @State private var accesses: [AuditEntry] = []
    @State private var message: String?
    @State private var changes: [MCPChange] = []
    @State private var choice = Choice.all
    /// Connections to this IAGO already in Claude Desktop's configuration.
    @State private var installed: [String] = []
    @State private var confirmingCodePermissions = false

    /// What a new connection can see.
    enum Choice: Hashable {
        case all
        case unclassified
        case client(String)
        case project(String)
    }

    var body: some View {
        SettingsGroup(title: String(localized: "Cosa sapere")) {
            Label(
                String(
                    localized:
                        "Claude legge IAGO dal tuo Mac, senza porte di rete. Però i contenuti che legge vengono inviati ai server di Anthropic per rispondere, con il tuo abbonamento."
                ),
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            Text(
                String(
                    localized:
                        "Vede solo i progetti che abiliti qui sotto (e gli elementi da classificare solo se scegli la connessione che li include). Il cestino non è mai visibile. Ogni lettura finisce nel registro in fondo a questa pagina."
                )
            )
            .font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        SettingsGroup(
            title: String(localized: "Progetti consultabili da Claude"),
            footnote: String(localized: "Di default nessuno: abilita solo quelli su cui vuoi lavorare con Claude.")
        ) {
            if model.projects.isEmpty {
                Text(String(localized: "Nessun progetto.")).foregroundStyle(.secondary)
            }
            ForEach(groups, id: \.title) { group in
                if !group.title.isEmpty {
                    Text(group.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                }
                ForEach(group.projects) { project in
                    HStack {
                        Toggle(
                            project.name,
                            isOn: Binding(
                                get: { project.claudeAccessible },
                                set: { value in
                                    model.perform { try model.archive.setProjectClaudeAccessible(project.id, value) }
                                    if value {
                                        ClaudeConnection.projectShared(
                                            archive: model.archive, projectName: project.name)
                                    }
                                })
                        )
                        Spacer()
                        if project.claudeAccessible { WritableToggle(model: model, project: project, short: true) }
                    }
                }
            }
        }
        SettingsGroup(
            title: String(localized: "Schermate"),
            footnote: String(
                localized:
                    "Il testo letto sulle schermate delle call è sempre consultabile da Claude, come la trascrizione. Le immagini contengono tutto ciò che era sullo schermo, notifiche e altre app comprese: condividile solo se ti serve che Claude legga slide, tabelle e grafici."
            )
        ) {
            Toggle(
                String(localized: "Condividi con Claude anche le immagini delle schermate"),
                isOn: Binding(
                    get: { (try? model.archive.setting(Archive.shareScreenshotsWithClaudeKey)) == "1" },
                    set: { value in
                        model.perform {
                            try model.archive.setSetting(Archive.shareScreenshotsWithClaudeKey, value ? "1" : "0")
                        }
                    })
            )
        }
        SettingsGroup(
            title: String(localized: "Collega Claude"),
            footnote: String(
                localized:
                    "Puoi creare più connessioni, una per ambito: in Claude Desktop scegli quale usare nella chat. Alla prima lettura macOS chiede se iago-mcp può usare la chiave di IAGO nel Portachiavi: scegli \"Consenti sempre\"."
            )
        ) {
            Picker(String(localized: "Cosa vede Claude"), selection: $choice) {
                ForEach(choices, id: \.self) { choice in
                    Text(label(choice)).tag(choice)
                }
            }
            .fixedSize()
            Text(explanation(choice)).font(.callout)
                .foregroundStyle(choice == .unclassified ? Color.orange : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            let connection = connection(choice)
            HStack {
                Button(String(localized: "Aggiungi a Claude Desktop")) {
                    message = ClaudeConnection.addToDesktop(name: connection.name, arguments: connection.arguments)
                    installed = ClaudeConnection.desktopConnections()
                }
                Button(String(localized: "Copia il comando per Claude Code")) {
                    copy(ClaudeConnection.codeCommand(name: connection.name, arguments: connection.arguments))
                }
            }
            Text(ClaudeConnection.codeCommand(name: connection.name, arguments: connection.arguments))
                .font(.caption.monospaced()).textSelection(.enabled).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !installed.isEmpty {
                Divider()
                Text(String(localized: "Già in Claude Desktop")).font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(installed, id: \.self) { name in
                    HStack {
                        Text(name).font(.callout.monospaced())
                        Spacer()
                        Button(String(localized: "Togli")) {
                            message = ClaudeConnection.removeFromDesktop(name: name)
                            installed = ClaudeConnection.desktopConnections()
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
        if let message {
            Text(message).font(.callout).foregroundStyle(.secondary)
        }
        permissionsGroup
        SettingsGroup(
            title: String(localized: "Modifiche tramite Claude (MCP)"),
            footnote: String(
                localized:
                    "Annulla toglie ciò che è stato inserito (gli elementi vanno nel cestino) o riporta il testo di prima."
            )
        ) {
            if changes.isEmpty {
                Text(String(localized: "Nessuna modifica tramite Claude.")).foregroundStyle(.secondary)
            }
            ForEach(changes) { change in
                HStack(alignment: .firstTextBaseline) {
                    Text(change.at.formatted(date: .abbreviated, time: .shortened)).font(.caption).monospacedDigit()
                        .frame(width: 130, alignment: .leading)
                    Text(describe(change)).font(.caption).lineLimit(1)
                        .foregroundStyle(change.undoneAt == nil ? .primary : .secondary)
                        .strikethrough(change.undoneAt != nil)
                    Spacer()
                    if change.undoneAt == nil, let id = change.id {
                        Button(String(localized: "Annulla")) {
                            model.perform { try model.archive.undoMCPChange(id) }
                            if model.selectedDecisionID == change.entityId { model.selectedDecisionID = nil }
                            if model.selectedNoteID == change.entityId { model.selectedNoteID = nil }
                            reloadChanges()
                        }
                        .buttonStyle(.link).font(.caption)
                    } else {
                        Text(String(localized: "annullata")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        SettingsGroup(title: String(localized: "Letture di Claude")) {
            if accesses.isEmpty {
                Text(String(localized: "Claude non ha ancora letto nulla.")).foregroundStyle(.secondary)
            }
            ForEach(accesses, id: \.id) { entry in
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.at.formatted(date: .abbreviated, time: .shortened)).font(.caption).monospacedDigit()
                        .frame(width: 130, alignment: .leading)
                    Text(entry.action).font(.caption.weight(.semibold)).frame(width: 120, alignment: .leading)
                    Text(entry.detail ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
        .task(id: model.revision) {
            reloadChanges()
            accesses = ((try? model.archive.auditEntries(limit: 300)) ?? []).filter { $0.actor == "mcp" }
                .prefix(50).map { $0 }
        }
        .onAppear { installed = ClaudeConnection.desktopConnections() }
    }

    private func reloadChanges() {
        changes = (try? model.archive.mcpChanges(limit: 50)) ?? []
    }

    /// "Nota aggiunta · «Richiamare Mario…»": what changed, with the current text cut short (it is the user's
    /// own archive, shown only here).
    /// ADR-0047: Claude asks before every tool unless the client is told otherwise; only the client can do it.
    private var permissionsGroup: some View {
        SettingsGroup(
            title: String(localized: "Evitare le richieste di permesso"),
            footnote: String(
                localized:
                    "I permessi li concede Claude, non IAGO. Gli strumenti di lettura non modificano nulla; quelli di scrittura mostrano sempre un'anteprima e scrivono solo dopo il tuo OK, e tutto si annulla qui sotto."
            )
        ) {
            Text(String(localized: "Claude Desktop")).font(.callout.weight(.semibold))
            Text(
                String(
                    localized:
                        "1. Apri Claude Desktop › Impostazioni › Connettori.\n2. Fai clic sulla connessione di IAGO (per esempio «\(installed.first ?? connection(choice).name)», tipo Desktop).\n3. Imposta gli strumenti su «Consenti sempre»: tutti insieme, se Claude Desktop lo propone, oppure uno per uno."
                )
            )
            .font(.callout).fixedSize(horizontal: false, vertical: true)
            Text(
                String(
                    localized:
                        "Dopo un aggiornamento di Claude Desktop può servire ripetere questi passi. Con un account aziendale queste impostazioni possono dipendere dall'amministratore."
                )
            )
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text(String(localized: "Claude Code")).font(.callout.weight(.semibold))
            Button(String(localized: "Consenti tutti gli strumenti in Claude Code…")) {
                confirmingCodePermissions = true
            }
            .confirmationDialog(
                String(localized: "Consentire a Claude Code tutti gli strumenti di IAGO?"),
                isPresented: $confirmingCodePermissions, titleVisibility: .visible
            ) {
                Button(String(localized: "Consenti")) {
                    message = ClaudeConnection.allowInClaudeCode(names: codePermissionNames)
                }
                Button(String(localized: "Annulla"), role: .cancel) {}
            } message: {
                Text(
                    String(
                        localized:
                            "IAGO aggiunge \(codePermissionNames.map { "mcp__\($0)" }.joined(separator: ", ")) ai permessi di ~/.claude/settings.json e ne tiene una copia. Il resto del file non cambia."
                    ))
            }
        }
    }

    /// The connections to allow: those in Claude Code and Claude Desktop, and the one chosen above.
    private var codePermissionNames: [String] {
        Array(Set(ClaudeConnection.codeConnections() + installed + [connection(choice).name])).sorted()
    }

    private func describe(_ change: MCPChange) -> String {
        let what: String
        var title: String?
        switch change.entity {
        case .note:
            what = change.action == .create ? String(localized: "Nota aggiunta") : String(localized: "Nota modificata")
            title = (try? model.archive.note(change.entityId))??.body
        case .decision:
            what =
                change.action == .create
                ? String(localized: "Decisione aggiunta") : String(localized: "Decisione modificata")
            title = (try? model.archive.decision(change.entityId))??.text
        case .item:
            what = String(localized: "Elemento inserito")
            title = model.item(change.entityId)?.title ?? (try? model.archive.item(change.entityId))??.title
        case .summary:
            what =
                change.action == .create
                ? String(localized: "Sintesi scritta") : String(localized: "Sintesi sostituita")
            title = model.item(change.entityId)?.title
        case .suggestion:
            what = String(localized: "Proposte aggiunte")
            title = model.item(change.entityId)?.title
        }
        guard let title, !title.isEmpty else { return what }
        let flat = title.split(whereSeparator: \.isNewline).joined(separator: " ")
        return "\(what) · «\(flat.count > 60 ? String(flat.prefix(60)) + "…" : flat)»"
    }

    private var choices: [Choice] {
        let clients = model.clients.filter { client in
            model.projects.contains { $0.clientId == client.id && $0.claudeAccessible }
        }
        return [.all, .unclassified] + clients.map { .client($0.id) }
            + model.projects.filter(\.claudeAccessible)
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }.map { .project($0.id) }
    }

    private func label(_ choice: Choice) -> String {
        switch choice {
        case .all: String(localized: "Tutti i progetti consultabili")
        case .unclassified: String(localized: "Tutti i progetti, compresi gli elementi da classificare")
        case .client(let id): String(localized: "Cliente: \(model.client(id)?.name ?? "")")
        case .project(let id): String(localized: "Progetto: \(model.projects.first { $0.id == id }?.name ?? "")")
        }
    }

    private func explanation(_ choice: Choice) -> String {
        switch choice {
        case .all:
            String(localized: "Claude vede tutti i progetti con \"Consultabile da Claude\" attivo.")
        case .unclassified:
            String(
                localized:
                    "Oltre ai progetti consultabili, Claude vede anche gli elementi non ancora assegnati a un progetto (Elementi da classificare): potrebbero esserci cose che non vuoi condividere."
            )
        case .client:
            String(localized: "Solo i progetti consultabili di questo cliente: meno contesto, risposte più mirate.")
        case .project:
            String(localized: "Solo questo progetto: Claude non deve chiederti quale, va dritto al punto.")
        }
    }

    private func connection(_ choice: Choice) -> (name: String, arguments: [String]) {
        switch choice {
        case .all: ("iago", [])
        case .unclassified: ("iago-tutto", ["--unclassified"])
        case .client(let id): (ClaudeConnection.serverName(model.client(id)?.name ?? id), ["--client", id])
        case .project(let id):
            (ClaudeConnection.serverName(model.projects.first { $0.id == id }?.name ?? id), ["--project", id])
        }
    }

    private var groups: [(title: String, projects: [Project])] {
        let sorted = model.projects.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        var result: [(String, [Project])] = model.clients.sorted {
            $0.name.localizedCompare($1.name) == .orderedAscending
        }
        .map { client in (client.name, sorted.filter { $0.clientId == client.id }) }
        .filter { !$0.1.isEmpty }
        let loose = sorted.filter { project in !model.clients.contains { $0.id == project.clientId } }
        if !loose.isEmpty { result.append((result.isEmpty ? "" : String(localized: "Senza cliente"), loose)) }
        return result
    }

    private func copy(_ text: String) {
        ClaudeConnection.copy(text)
        message = String(localized: "Copiato negli appunti.")
    }
}
