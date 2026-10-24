import AppKit
import IAGOStore
import SwiftUI

/// What the "Impostazioni" panel of a project or client shows (right click › Impostazioni…, or the Claude mark).
struct ScopeSettingsTarget: Identifiable, Hashable {
    enum Scope: Hashable {
        case project(String)
        case client(String)
    }

    enum Tab: Hashable { case general, claude, people }

    var scope: Scope
    var tab: Tab = .general
    var id: Scope { scope }
}

// MARK: - Sidebar marks

/// The colour of a project (dot) or client (square). A click opens the palette to change it.
struct ColorMark: View {
    let color: String?
    var square = false
    let change: (String) -> Void
    @State private var picking = false

    var body: some View {
        Button {
            picking = true
        } label: {
            Group {
                if square {
                    RoundedRectangle(cornerRadius: 3).fill(Color.iago(color)).frame(width: 11, height: 11)
                } else {
                    Circle().fill(Color.iago(color)).frame(width: 9, height: 9)
                }
            }
            .frame(width: 18, height: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Cambia colore"))
        .popover(isPresented: $picking, arrowEdge: .bottom) {
            ColorPalette(selected: color) { name in
                change(name)
                picking = false
            }
            .padding(10)
        }
    }
}

/// The palette names of `Archive.palette`, as clickable dots.
struct ColorPalette: View {
    let selected: String?
    let choose: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Archive.palette, id: \.self) { name in
                Button {
                    choose(name)
                } label: {
                    Circle().fill(Color.iago(name)).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.primary, lineWidth: selected == name ? 2 : 0).padding(-3))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Whether a project is readable by Claude: Claude's mark when it is, a small lock when it stays only in IAGO.
/// The tooltip says it in full, a click opens the project's Claude settings.
struct AccessMark: View {
    let model: AppModel
    let project: Project
    @State private var hovering = false
    @State private var explaining = false

    var body: some View {
        Button {
            model.scopeSettings = ScopeSettingsTarget(scope: .project(project.id), tab: .claude)
        } label: {
            Group {
                if project.claudeAccessible {
                    ClaudeLogo().frame(width: 10, height: 10)
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .frame(width: 14, height: 16).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // `.help` is not shown on buttons inside the sidebar list: a small popover after a short hover instead.
        .onHover { inside in
            hovering = inside
            guard inside else {
                explaining = false
                return
            }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                if hovering { explaining = true }
            }
        }
        .popover(isPresented: $explaining, arrowEdge: .trailing) {
            Text(explanation).font(.callout).padding(10).frame(width: 260, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var explanation: String {
        project.claudeAccessible
            ? String(
                localized:
                    "Consultabile da Claude: se colleghi Claude a IAGO, può leggere questo progetto (i contenuti letti vanno ad Anthropic)."
            )
                + (project.claudeWritable
                    ? String(localized: " Può anche scrivere note, decisioni e documenti, su tua richiesta.")
                    : String(localized: " Non può scrivere."))
                + String(localized: " Clic per le impostazioni.")
            : String(
                localized: "Solo in IAGO: resta cifrato su questo Mac e Claude non lo vede. Clic per le impostazioni.")
    }
}

/// Claude's mark: an orange burst of rays, drawn (no image asset, no background, no border).
struct ClaudeLogo: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let lengths: [CGFloat] = [1, 0.78, 0.92, 0.7, 0.98, 0.82, 0.9, 0.74, 1, 0.8, 0.88, 0.72]
            for (index, length) in lengths.enumerated() {
                let angle = CGFloat(index) / CGFloat(lengths.count) * 2 * .pi + 0.2
                var ray = Path()
                ray.move(to: center)
                ray.addLine(
                    to: CGPoint(
                        x: center.x + cos(angle) * radius * length, y: center.y + sin(angle) * radius * length))
                context.stroke(
                    ray, with: .color(Color(red: 0.85, green: 0.47, blue: 0.34)),
                    style: StrokeStyle(lineWidth: radius * 0.26, lineCap: .round))
            }
        }
        .accessibilityLabel(Text("Claude"))
    }
}

// MARK: - Panel

/// "Impostazioni" of a project or client: general (name, colour, client, pinned), Claude (readable or not, a
/// connection limited to it) and people.
struct ScopeSettingsSheet: View {
    let model: AppModel
    @State var target: ScopeSettingsTarget
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                switch target.scope {
                case .project(let id):
                    if let project = project(id) {
                        AccessMark(model: model, project: project)
                        Text(project.name).font(.title2).bold()
                    }
                case .client(let id):
                    if let client = model.client(id) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.iago(client.color)).frame(width: 13, height: 13)
                        Text(client.name).font(.title2).bold()
                    }
                }
            }
            Picker("", selection: $target.tab) {
                Text(String(localized: "Generale")).tag(ScopeSettingsTarget.Tab.general)
                Text(String(localized: "Claude")).tag(ScopeSettingsTarget.Tab.claude)
                Text(String(localized: "Persone")).tag(ScopeSettingsTarget.Tab.people)
            }
            .pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch (target.scope, target.tab) {
                    case (.project(let id), .general): projectGeneral(id)
                    case (.client(let id), .general): clientGeneral(id)
                    case (.project(let id), .claude): projectClaude(id)
                    case (.client(let id), .claude): clientClaude(id)
                    case (.project(let id), .people):
                        PeopleSheet(model: model, title: "", clientID: nil, projectID: id, embedded: true)
                    case (.client(let id), .people):
                        PeopleSheet(model: model, title: "", clientID: id, projectID: nil, embedded: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
            HStack {
                Spacer()
                Button(String(localized: "Fatto")) { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 640, height: 520)
        .onAppear {
            switch target.scope {
            case .project(let id): name = project(id)?.name ?? ""
            case .client(let id): name = model.client(id)?.name ?? ""
            }
        }
    }

    private func project(_ id: String) -> Project? { model.projects.first { $0.id == id } }

    // MARK: General

    @ViewBuilder
    private func projectGeneral(_ id: String) -> some View {
        if let project = project(id) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text(String(localized: "Nome")).foregroundStyle(.secondary)
                    TextField("", text: $name).textFieldStyle(.roundedBorder)
                        .onSubmit { rename(project: id) }
                        .onChange(of: name) { _, _ in message = nil }
                }
                GridRow {
                    Text(String(localized: "Cliente")).foregroundStyle(.secondary)
                    Picker(
                        "",
                        selection: Binding(
                            get: { project.clientId }, set: { model.setProjectClient(id, $0) })
                    ) {
                        Text(String(localized: "Nessun cliente")).tag(String?.none)
                        ForEach(model.clients) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .labelsHidden().fixedSize()
                }
                GridRow {
                    Text(String(localized: "In evidenza")).foregroundStyle(.secondary)
                    Toggle(
                        String(localized: "Mostra in alto nella barra laterale"),
                        isOn: Binding(get: { project.pinned }, set: { model.setPinned(project, $0) }))
                }
                GridRow {
                    Text(String(localized: "Stream")).foregroundStyle(.secondary)
                    let streams = model.streams(of: id)
                    Text(
                        streams.isEmpty
                            ? String(localized: "Nessuno (crealo col tasto destro sul progetto › Nuovo stream…)")
                            : streams.map(\.name).joined(separator: ", ")
                    )
                    .foregroundStyle(.secondary)
                }
            }
            if name.trimmingCharacters(in: .whitespaces) != project.name {
                Button(String(localized: "Salva il nome")) { rename(project: id) }
            }
        }
    }

    @ViewBuilder
    private func clientGeneral(_ id: String) -> some View {
        if let client = model.client(id) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text(String(localized: "Nome")).foregroundStyle(.secondary)
                    TextField("", text: $name).textFieldStyle(.roundedBorder)
                        .onSubmit { rename(client: id) }
                }
                GridRow {
                    Text(String(localized: "Colore")).foregroundStyle(.secondary)
                    ColorPalette(selected: client.color) { color in
                        model.perform { try model.archive.updateClient(id) { $0.color = color } }
                    }
                }
                GridRow {
                    Text(String(localized: "Progetti")).foregroundStyle(.secondary)
                    Text(
                        model.projects.filter { $0.clientId == id }.map(\.name).joined(separator: ", ")
                    )
                    .foregroundStyle(.secondary)
                }
            }
            if name.trimmingCharacters(in: .whitespaces) != client.name {
                Button(String(localized: "Salva il nome")) { rename(client: id) }
            }
        }
    }

    private func rename(project id: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.perform { try model.archive.renameProject(id, to: trimmed) }
    }

    private func rename(client id: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.perform { try model.archive.updateClient(id) { $0.name = trimmed } }
    }

    // MARK: Claude

    @ViewBuilder
    private func projectClaude(_ id: String) -> some View {
        if let project = project(id) {
            Toggle(
                String(localized: "Consultabile da Claude"),
                isOn: Binding(
                    get: { project.claudeAccessible },
                    set: { value in
                        model.perform { try model.archive.setProjectClaudeAccessible(id, value) }
                        if value { ClaudeConnection.provisionServerKey(archive: model.archive) }
                    })
            )
            .font(.headline)
            Text(
                project.claudeAccessible
                    ? String(
                        localized:
                            "Claude può leggere trascrizioni, email, documenti, note e decisioni di questo progetto quando gli fai una domanda. Quello che legge viene inviato ad Anthropic."
                    )
                    : String(
                        localized:
                            "Resta solo in IAGO: Claude non lo vede, nemmeno se è collegato a IAGO."
                    )
            )
            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if project.claudeAccessible {
                WritableToggle(model: model, project: project)
                connection(
                    title: String(localized: "Collegamento solo a questo progetto"),
                    name: ClaudeConnection.serverName(project.name), arguments: ["--project", id])
            }
        }
    }

    @ViewBuilder
    private func clientClaude(_ id: String) -> some View {
        let projects = model.projects.filter { $0.clientId == id }
        Text(String(localized: "Progetti consultabili da Claude")).font(.headline)
        if projects.isEmpty { Text(String(localized: "Nessun progetto.")).foregroundStyle(.secondary) }
        ForEach(projects) { project in
            HStack {
                Toggle(
                    project.name,
                    isOn: Binding(
                        get: { project.claudeAccessible },
                        set: { value in
                            model.perform { try model.archive.setProjectClaudeAccessible(project.id, value) }
                            if value { ClaudeConnection.provisionServerKey(archive: model.archive) }
                        }))
                Spacer()
                if project.claudeAccessible { WritableToggle(model: model, project: project, short: true) }
            }
        }
        if projects.contains(where: \.claudeAccessible), let client = model.client(id) {
            connection(
                title: String(localized: "Collegamento solo a questo cliente"),
                name: ClaudeConnection.serverName(client.name), arguments: ["--client", id])
        }
    }

    /// A connection limited to this project or client, for Claude Desktop and Claude Code.
    private func connection(title: String, name: String, arguments: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 4)
            Text(title).font(.headline)
            Text(
                String(
                    localized:
                        "Una connessione in più, chiamata «\(name)», che vede solo questo: Claude va dritto al punto e usa meno contesto. In Claude Desktop attivi la connessione che ti serve nella chat; in Claude Code puoi aggiungerla solo nella cartella del lavoro."
                )
            )
            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(String(localized: "Aggiungi a Claude Desktop")) {
                    message = ClaudeConnection.addToDesktop(name: name, arguments: arguments)
                }
                Button(String(localized: "Copia il comando per Claude Code")) {
                    ClaudeConnection.copy(ClaudeConnection.codeCommand(name: name, arguments: arguments))
                    message = String(localized: "Comando copiato: incollalo nel Terminale.")
                }
            }
            Text(ClaudeConnection.codeCommand(name: name, arguments: arguments))
                .font(.caption.monospaced()).textSelection(.enabled).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Connection helpers

/// How Claude Desktop and Claude Code start IAGO's MCP server (ADR-0043).
enum ClaudeConnection {
    /// The server inside this copy of IAGO.
    static var serverURL: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/iago-mcp") }

    static var desktopConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
    }

    /// "iago-poldo-spa" for a limited connection: letters and digits only.
    static func serverName(_ scopeName: String) -> String {
        let folded = scopeName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        let slug = folded.map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
        return "iago-\(slug.isEmpty ? "progetto" : String(slug.prefix(40)))"
    }

    static func desktopSnippet(name: String = "iago", arguments: [String] = []) -> String {
        let args = arguments.isEmpty ? "" : ", \"args\": [\(arguments.map { "\"\($0)\"" }.joined(separator: ", "))]"
        return """
            {
              "mcpServers": {
                "\(name)": { "command": "\(serverURL.path)"\(args) }
              }
            }
            """
    }

    static func codeCommand(name: String = "iago", arguments: [String] = []) -> String {
        (["claude mcp add --scope user \(name) -- \"\(serverURL.path)\""] + arguments).joined(separator: " ")
    }

    /// Names of the connections to this IAGO already in Claude Desktop's configuration.
    static func desktopConnections() -> [String] {
        guard let data = try? Data(contentsOf: desktopConfigURL),
            let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let servers = config["mcpServers"] as? [String: Any]
        else { return [] }
        return servers.compactMap { name, value in
            ((value as? [String: Any])?["command"] as? String)?.hasSuffix("/iago-mcp") == true ? name : nil
        }
        .sorted()
    }

    /// Removes one connection from Claude Desktop's configuration, keeping a copy of the file.
    static func removeFromDesktop(name: String) -> String {
        let url = desktopConfigURL
        guard let data = try? Data(contentsOf: url),
            var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            var servers = config["mcpServers"] as? [String: Any]
        else { return String(localized: "Configurazione di Claude Desktop non trovata.") }
        servers[name] = nil
        config["mcpServers"] = servers
        do {
            try data.write(to: url.appendingPathExtension("bak-iago"))
            let updated = try JSONSerialization.data(
                withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try updated.write(to: url, options: .atomic)
            return String(localized: "Tolta «\(name)». Chiudi Claude Desktop (⌘Q) e riaprilo.")
        } catch {
            return String(localized: "Non sono riuscito a modificare la configurazione di Claude Desktop.")
        }
    }

    /// Hands the master key to the MCP server, which keeps its own keychain copy so it never needs a prompt
    /// (ADR-0043, option chosen by the user). Only when Claude can read at least one project; the key goes over a
    /// pipe, never through a file or the command line.
    static func provisionServerKey(archive: Archive) {
        guard (try? archive.projects(includeArchived: true).contains(where: \.claudeAccessible)) == true,
            FileManager.default.isExecutableFile(atPath: serverURL.path),
            let key = try? KeychainMasterKeyStore().existingKey()
        else { return }
        let process = Process()
        process.executableURL = serverURL
        process.arguments = ["--provision"]
        let input = Pipe()
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        do {
            try process.run()
            input.fileHandleForWriting.write(Data(key.withUnsafeBytes { Data($0) }.base64EncodedString().utf8))
            try input.fileHandleForWriting.close()
        } catch {
            return
        }
    }

    static var codeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    /// Names of the connections to this IAGO in Claude Code (user and project scope of `~/.claude.json`).
    static func codeConnections() -> [String] {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
        guard let data = try? Data(contentsOf: url),
            let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        var tables = [config["mcpServers"] as? [String: Any] ?? [:]]
        for case let project as [String: Any] in (config["projects"] as? [String: Any] ?? [:]).values {
            tables.append(project["mcpServers"] as? [String: Any] ?? [:])
        }
        return Set(
            tables.flatMap { servers in
                servers.compactMap { name, value in
                    ((value as? [String: Any])?["command"] as? String)?.hasSuffix("/iago-mcp") == true ? name : nil
                }
            }
        ).sorted()
    }

    /// Lets Claude Code use every tool of these connections without asking (ADR-0047): adds `mcp__<name>` to
    /// `permissions.allow` in `~/.claude/settings.json`, keeping everything else and a copy of the file.
    static func allowInClaudeCode(names: [String]) -> String {
        let url = codeSettingsURL
        do {
            var settings: [String: Any] = [:]
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return String(localized: "Le impostazioni di Claude Code non sono leggibili: non le ho toccate.")
                }
                settings = parsed
                try data.write(to: url.appendingPathExtension("bak-iago"))
            }
            var permissions = settings["permissions"] as? [String: Any] ?? [:]
            var allow = permissions["allow"] as? [String] ?? []
            let rules = names.map { "mcp__\($0)" }.filter { !allow.contains($0) }
            guard !rules.isEmpty else { return String(localized: "Claude Code ha già il permesso per IAGO.") }
            allow += rules
            permissions["allow"] = allow
            settings["permissions"] = permissions
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(
                withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try data.write(to: url, options: .atomic)
            return String(
                localized:
                    "Fatto: Claude Code può usare gli strumenti di \(names.joined(separator: ", ")) senza chiedere. Vale dalla prossima sessione di Claude Code."
            )
        } catch {
            return String(localized: "Non sono riuscito a scrivere le impostazioni di Claude Code.")
        }
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Adds `mcpServers.<name>` to Claude Desktop's configuration, keeping everything else and a copy of the
    /// file. Returns the message for the user.
    static func addToDesktop(name: String = "iago", arguments: [String] = []) -> String {
        let url = desktopConfigURL
        do {
            var config: [String: Any] = [:]
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return String(
                        localized:
                            "La configurazione di Claude Desktop non è leggibile: copia la configurazione a mano.")
                }
                config = parsed
                try data.write(to: url.appendingPathExtension("bak-iago"))
            }
            var servers = config["mcpServers"] as? [String: Any] ?? [:]
            var entry: [String: Any] = ["command": serverURL.path]
            if !arguments.isEmpty { entry["args"] = arguments }
            servers[name] = entry
            config["mcpServers"] = servers
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(
                withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try data.write(to: url, options: .atomic)
            return String(
                localized: "Aggiunta «\(name)» a Claude Desktop. Chiudi Claude Desktop (⌘Q) e riaprilo per vederla.")
        } catch {
            return String(localized: "Non sono riuscito a scrivere la configurazione: copiala a mano.")
        }
    }
}

/// "Inserita/Modificata tramite Claude (MCP)" on notes, decisions and items written by the user through Claude
/// (ADR-0044). `compact`: only the mark, with the text as tooltip.
struct ViaClaudeBadge: View {
    let model: AppModel
    let entity: MCPChange.Entity
    let id: String
    var compact = false

    var body: some View {
        if let action = model.viaClaude(entity, id) {
            let text = Self.text(action, entity: entity)
            HStack(spacing: 4) {
                ClaudeLogo().frame(width: 9, height: 9)
                if !compact { Text(text) }
            }
            .font(.caption).foregroundStyle(.secondary)
            .help(text + String(localized: " · si annulla da Impostazioni › Claude"))
        }
    }

    static func text(_ action: MCPChange.Action, entity: MCPChange.Entity) -> String {
        switch (action, entity) {
        case (.create, .item): String(localized: "Inserito tramite Claude (MCP)")
        case (.create, _): String(localized: "Inserita tramite Claude (MCP)")
        case (.update, .item): String(localized: "Modificato tramite Claude (MCP)")
        case (.update, _): String(localized: "Modificata tramite Claude (MCP)")
        }
    }
}

/// "Claude può anche scrivere" (ADR-0044): only for a project Claude can read.
struct WritableToggle: View {
    let model: AppModel
    let project: Project
    var short = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                short ? String(localized: "Può scrivere") : String(localized: "Claude può anche scrivere"),
                isOn: Binding(
                    get: { project.claudeWritable },
                    set: { value in
                        model.perform { try model.archive.setProjectClaudeWritable(project.id, value) }
                    }))
            if !short {
                Text(
                    String(
                        localized:
                            "Su tua richiesta, Claude può aggiungere e modificare note e decisioni, creare documenti e inserire email. Trascrizioni, audio e originali non si toccano. Tutto compare come «tramite Claude (MCP)» e si annulla da Impostazioni › Claude."
                    )
                )
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
