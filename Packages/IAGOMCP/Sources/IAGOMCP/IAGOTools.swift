import CryptoKit
import Foundation
import IAGOExport
import IAGOStore
import Synchronization

/// The tools Claude uses to read IAGO (spec 12 v1.4, ADR-0043). Only projects marked "Consultabile da Claude"
/// exist for these tools; every call is written to the audit log, never its content.
public struct IAGOTools: ToolProvider {
    /// A connection limited to one project or one client (`iago-mcp --project ID` / `--client ID`): less context
    /// for Claude, straight to the point. Still only projects marked "Consultabile da Claude".
    public enum Restriction: Sendable, Equatable {
        case project(String)
        case client(String)
        /// Every readable project plus the items still without a project ("Da classificare"): only when the user
        /// chooses this connection (ADR-0043).
        case includingUnclassified
    }

    let archive: Archive
    let restriction: Restriction?
    /// The write connection, opened on the first write (ADR-0044); nil: a read-only server.
    let openWriter: (@Sendable () throws -> Archive)?
    /// Writes one audit row: tool, short parameters, returned IDs.
    let audit: @Sendable (_ action: String, _ detail: String) -> Void
    let timeZone: TimeZone
    let clock: @Sendable () -> Date
    /// Where import_file may read (the user's home); tests use a temporary folder.
    let filesRoot: URL
    /// The app's inbox for files only IAGO itself can import (audio, video, Teams transcripts): it converts and
    /// transcribes them like a drop. nil: those files are refused.
    let inbox: URL?
    /// Signs the confirmation codes of write previews (ADR-0047); new for every server process.
    let previewKey = SymmetricKey(size: .bits256)
    /// What the connection learned about its client.
    let session = Session()

    final class Session: Sendable {
        private let name = Mutex<String?>(nil)
        var client: String? { name.withLock { $0 } }
        func set(_ client: String) { name.withLock { $0 = client } }
    }

    public func connected(client: String) { session.set(client) }

    public func content(_ name: String, arguments: JSON) throws -> [JSON] {
        guard name == "get_screenshots" else {
            return [["type": "text", "text": .string(try call(name, arguments: arguments))]]
        }
        let scope = try Scope(archive: archive, restriction: restriction)
        var returned: [String] = []
        let content = try screenshotsContent(scope, arguments, &returned)
        audit(name, Self.auditDetail(arguments, returned: returned))
        return content
    }

    public init(
        archive: Archive, restriction: Restriction? = nil, timeZone: TimeZone = .current,
        clock: @escaping @Sendable () -> Date = { Date() },
        filesRoot: URL = FileManager.default.homeDirectoryForCurrentUser, inbox: URL? = nil,
        openWriter: (@Sendable () throws -> Archive)? = nil, audit: @escaping @Sendable (String, String) -> Void
    ) {
        self.filesRoot = filesRoot
        self.inbox = inbox
        self.archive = archive
        self.openWriter = openWriter
        self.restriction = restriction
        self.timeZone = timeZone
        self.clock = clock
        self.audit = audit
    }

    public var instructions: String {
        var limited = ""
        if restriction == .includingUnclassified {
            limited =
                "Questa connessione include anche «Da classificare»: elementi non ancora assegnati a un progetto (usa project=\"Da classificare\").\n"
        } else if let scope = try? Scope(archive: archive, restriction: restriction), restriction != nil {
            limited =
                scope.projects.count == 1
                ? "Questa connessione è limitata al progetto «\(scope.projects[0].name)»: non serve indicarlo.\n"
                : "Questa connessione è limitata ai progetti: \(scope.projects.map(\.name).joined(separator: ", ")).\n"
        }
        return limited + """
            IAGO è l'archivio locale di un professionista: call trascritte, email, documenti, note e decisioni, \
            organizzati per cliente › progetto › stream. Vedi solo i progetti che l'utente ha reso consultabili.
            - Gli elementi sono di tre tipi: call (trascrizione con minuti e speaker), email (con direzione: \
            inviata o ricevuta), documenti (testo estratto, anche con OCR: può contenere errori di riconoscimento).
            - Le note sono scritte dall'utente, con data: valgono come sue annotazioni, non come parole dette in call.
            - I punti chiave sono decisioni (Attiva, Superata da una più recente della stessa catena, Annullata), \
            attività (Aperta, Fatta, Annullata; possono diventare decisioni) e tappe (fatti importanti avvenuti). \
            Per "cosa vale oggi" usa solo le decisioni Attive.
            - Le informazioni si susseguono nel tempo: in caso di conflitto prevale la più recente, e il conflitto va \
            segnalato.
            - Cita sempre la fonte: titolo dell'elemento, data e, per le call, il minuto [mm:ss].
            Inizia da list_projects; usa search per trovare passaggi e get_item per leggere un elemento intero; \
            recent_items per gli ultimi elementi di tutti i progetti.
            """ + (openWriter == nil ? "" : Self.writingGuide + Self.workGuide)
    }

    /// How to write (ADR-0047): context first, ask instead of guessing, preview before every write.
    static let writingGuide = """

        Scrivere in IAGO (solo nei progetti «scrivibili» di list_projects, solo quando l'utente te lo chiede):
        1. Prima leggi il contesto del progetto: list_projects (stream), list_decisions con status=active (e query \
        sul tema), la parte recente di project_timeline, list_notes se serve.
        2. Scegli il tipo giusto:
           - nota (add_note): un'informazione da ricordare;
           - decisione (add_decision): qualcosa di deciso, che vale finché un'altra decisione non la supera;
           - attività (add_decision, kind activity): qualcosa da fare;
           - tappa (add_decision, kind milestone): un fatto importante avvenuto (firma, consegna, kickoff);
           - documento (create_document): un testo lungo e strutturato, come un verbale o un riepilogo;
           - file (import_file): un PDF, un'immagine o un documento che è sul Mac. IAGO non riceve i file caricati \
        nella chat: chiedi all'utente il percorso (per esempio ~/Downloads/modulo.pdf). Gli allegati di un'email \
        vanno in add_email con attachment_paths.
           Più voci insieme (per esempio decisioni e attività emerse da una call) vanno in un'unica write_batch: \
        una sola anteprima e un solo OK.
        3. Se l'utente dice che una decisione è cambiata, trova con list_decisions (query) quella attiva sul tema. \
        Se ce n'è una sola, proponi di superarla (supersedes_ids). Se sono più d'una o nessuna, chiedi quali: \
        una voce può superarne più d'una, anche di tipo diverso (per esempio una tappa che chiude una decisione e due \
        attività).
        4. Collega ogni voce alla sua fonte: l'elemento (item_id o source_item_id: call al minuto, email, \
        documento, file), la nota d'origine (source_note_id), lo stream giusto. Se non è chiaro, chiedi.
        5. Date: non indicarle. Senza date la voce è di adesso e compare in cima alla timeline. Indica una data \
        solo se l'utente la dice, oppure date="source" se l'utente vuole la data esatta della fonte.
        6. Ogni scrittura ha due passi. Chiama lo strumento senza confirmation: IAGO restituisce un'anteprima \
        (cosa, dove, collegamenti, data e posizione in timeline, dubbi). Mostra all'utente l'anteprima e i dubbi \
        in modo breve e chiedi conferma. Dopo il suo OK richiama lo strumento con gli stessi parametri e il \
        codice. Se l'utente cambia qualcosa, fai una nuova anteprima.
        7. Dopo la scrittura riferisci dove è finita la voce, come indicato da IAGO. Ciò che scrivi compare come \
        inserito tramite Claude (MCP) e l'utente può annullarlo da Impostazioni › Claude.
        Non scrivere mai nelle trascrizioni, negli audio o negli originali: non ci sono strumenti per farlo.
        """

    // MARK: Definitions

    static let projectArgument: JSON = [
        "type": "string",
        "description":
            "ID o nome del progetto (come in list_projects); facoltativo se la connessione ha un solo progetto.",
    ]
    static let streamArgument: JSON = [
        "type": "string", "description": "Facoltativo: nome di uno stream del progetto, per restringere.",
    ]
    static let fromArgument: JSON = ["type": "string", "description": "Facoltativo: dal giorno (AAAA-MM-GG)."]
    static let toArgument: JSON = ["type": "string", "description": "Facoltativo: fino al giorno (AAAA-MM-GG)."]
    static let typesArgument: JSON = [
        "type": "array", "items": ["type": "string", "enum": ["call", "email", "document", "note", "decision"]],
        "description": "Facoltativo: solo questi tipi.",
    ]

    public var tools: [ToolDefinition] {
        (readTools + workReadTools).map { tool in
            var tool = tool
            tool.readOnly = true
            tool.title = Self.readTitles[tool.name] ?? Self.workTitles[tool.name]
            return tool
        }
            + (openWriter == nil
                ? []
                : writeTools.map { tool in
                    var tool = tool
                    tool.readOnly = false
                    return tool
                })
    }

    static let readTitles = [
        "list_projects": "Elenca progetti", "search": "Cerca", "get_item": "Leggi elemento",
        "project_timeline": "Timeline del progetto", "list_decisions": "Punti chiave", "list_notes": "Note",
        "get_thread": "Conversazione email", "export_project": "Esporta progetto", "find_file": "Trova file",
    ]

    var readTools: [ToolDefinition] {
        [
            ToolDefinition(
                name: "list_projects",
                description:
                    "Elenca i progetti consultabili con cliente, stream, numero di elementi e periodo coperto.",
                inputSchema: ["type": "object", "properties": .object([:])]),
            ToolDefinition(
                name: "search",
                description: """
                    Cerca parole nei testi dei progetti consultabili: trascrizioni, email, documenti, note e \
                    decisioni. Ignora maiuscole e accenti; cerca parole intere (prova sinonimi se non trovi). \
                    Restituisce i passaggi con elemento, data e minuto: usa get_item per il contesto completo.
                    """,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Parole da cercare."],
                        "project": Self.projectArgument, "stream": Self.streamArgument, "types": Self.typesArgument,
                        "from": Self.fromArgument, "to": Self.toArgument,
                        "limit": ["type": "integer", "description": "Massimo risultati (default 30, max 100)."],
                    ],
                    "required": ["query"],
                ]),
            ToolDefinition(
                name: "get_item",
                description: """
                    Un elemento intero: intestazione (tipo, data, partecipanti o mittente/destinatari), trascrizione \
                    con minuti e speaker oppure testo dell'email o del documento, note dell'utente, decisioni nate \
                    dall'elemento e collegamenti ad altri elementi.
                    """,
                inputSchema: [
                    "type": "object", "properties": ["item_id": ["type": "string"]], "required": ["item_id"],
                ]),
            ToolDefinition(
                name: "project_timeline",
                description: """
                    Cronologia di un progetto: elementi, note e decisioni in ordine di data, con tipo, direzione \
                    delle email e ID per get_item.
                    """,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "project": Self.projectArgument, "stream": Self.streamArgument, "types": Self.typesArgument,
                        "from": Self.fromArgument, "to": Self.toArgument,
                    ],
                ]),
            ToolDefinition(
                name: "list_decisions",
                description: """
                    Punti chiave di un progetto: decisioni, attività (da fare o in corso) e tappe (fatti importanti), \
                    con stato, data, fonte (call al minuto, email, nota), \
                    catena "supera" e descrizione. Di default tutte; status=active per quelle valide oggi. Con \
                    query trova quelle su un tema (es. "è cambiata la decisione sul contributo").
                    """,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "project": Self.projectArgument, "stream": Self.streamArgument,
                        "query": [
                            "type": "string",
                            "description": "Facoltativo: parole del titolo o della descrizione, dalla più pertinente.",
                        ],
                        "status": ["type": "string", "enum": ["active", "done", "superseded", "cancelled", "all"]],
                        "kind": [
                            "type": "string", "enum": ["decision", "activity", "milestone", "all"],
                            "description": "Facoltativo: solo decisioni, attività o tappe (default tutti).",
                        ],
                        "from": Self.fromArgument, "to": Self.toArgument,
                    ],
                ]),
            ToolDefinition(
                name: "list_notes",
                description: "Note dell'utente su un progetto e sui suoi elementi, in ordine di data.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "project": Self.projectArgument, "from": Self.fromArgument, "to": Self.toArgument,
                        "kind": ["type": "string", "enum": ["note", "email", "late_decision", "update"]],
                    ],
                ]),
            ToolDefinition(
                name: "get_thread",
                description: "La conversazione email di cui fa parte un'email, in ordine di data, con direzione.",
                inputSchema: [
                    "type": "object", "properties": ["item_id": ["type": "string"]], "required": ["item_id"],
                ]),
            ToolDefinition(
                name: "find_file",
                description: """
                    Cerca per nome un file sul Mac dell'utente, in Download, Scrivania e Documenti (anche nelle \
                    sottocartelle), i più recenti per primi. Usalo per trovare il percorso di un file che l'utente ti ha \
                    mostrato in chat, prima di import_file o add_email con allegati: un file caricato in chat non \
                    arriva a IAGO. Restituisce percorso, dimensione e data.
                    """,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Parte del nome del file, senza percorso."]
                    ],
                    "required": ["name"],
                ]),
            ToolDefinition(
                name: "export_project",
                description: """
                    L'intero progetto in un unico Markdown (indice, registro decisioni, elementi e note in ordine \
                    cronologico). Può essere molto lungo: preferisci search e get_item per domande puntuali.
                    """,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "project": Self.projectArgument,
                        "documents": [
                            "type": "string", "enum": ["full", "excerpt"],
                            "description": "Documenti interi o solo un estratto (default excerpt).",
                        ],
                    ],
                ]),
        ]
    }

    // MARK: Dispatch

    public func call(_ name: String, arguments: JSON) throws -> String {
        let scope = try Scope(archive: archive, restriction: restriction)
        var returned: [String] = []
        let text: String
        switch name {
        case "list_projects": text = try listProjects(scope, &returned)
        case "search": text = try search(scope, arguments, &returned)
        case "get_item": text = try getItem(scope, arguments, &returned)
        case "project_timeline": text = try timeline(scope, arguments, &returned)
        case "list_decisions": text = try listDecisions(scope, arguments, &returned)
        case "list_notes": text = try listNotes(scope, arguments, &returned)
        case "get_thread": text = try thread(scope, arguments, &returned)
        case "export_project": text = try exportProject(scope, arguments, &returned)
        case "find_file": text = try findFile(arguments)
        case "recent_items": text = try recentItems(scope, arguments, &returned)
        case "summary_template": text = try summaryTemplate(scope, arguments, &returned)
        default:
            guard let written = try callWrite(name, scope, arguments, &returned) else {
                throw ToolError("Strumento sconosciuto: \(name)")
            }
            text = written
        }
        audit(name, Self.auditDetail(arguments, returned: returned))
        return text
    }

    /// Parameters (queries cut short) and returned IDs: never the content (ADR-0043).
    static func auditDetail(_ arguments: JSON, returned: [String]) -> String {
        var parts: [String] = []
        if case .object(let object) = arguments {
            for key in object.keys.sorted() {
                guard let value = object[key] else { continue }
                let text: String =
                    switch value {
                    case .string(let string): string
                    case .number(let number): number.formatted()
                    case .array(let values): values.compactMap(\.string).joined(separator: ",")
                    default: ""
                    }
                parts.append("\(key)=\(text.count > 60 ? String(text.prefix(60)) + "…" : text)")
            }
        }
        let ids = returned.prefix(50).joined(separator: ",") + (returned.count > 50 ? ",…" : "")
        parts.append("restituiti=\(returned.count)" + (returned.isEmpty ? "" : " [\(ids)]"))
        return parts.joined(separator: "; ")
    }

    // MARK: Scope

    /// A project, or the items without a project ("Da classificare") when the connection includes them.
    struct Target {
        static let unclassifiedID = "unclassified"
        static let unclassifiedName = "Da classificare"
        /// nil: the items without a project.
        var id: String?
        var name: String

        var library: LibraryScope { id.map { .project($0) } ?? .unclassified }
        var decisions: DecisionQuery.Scope { id.map { .project($0) } ?? .noProject }
    }

    /// The projects Claude may read, resolved once per call (the user may switch the flag at any time).
    struct Scope {
        var projects: [Project]
        var clients: [String: Client]
        var ids: Set<String>
        var includesUnclassified = false

        init(archive: Archive, restriction: Restriction? = nil) throws {
            projects = try archive.projects(includeArchived: true).filter(\.claudeAccessible)
            switch restriction {
            case .project(let id): projects = projects.filter { $0.id == id }
            case .client(let id): projects = projects.filter { $0.clientId == id }
            case .includingUnclassified: includesUnclassified = true
            case nil: break
            }
            clients = Dictionary(
                uniqueKeysWithValues: try archive.clients(includeArchived: true).map { ($0.id, $0) })
            ids = Set(projects.map(\.id))
        }

        func project(_ reference: String?) throws -> Target {
            guard let reference = reference?.trimmingCharacters(in: .whitespaces), !reference.isEmpty else {
                if projects.count == 1, !includesUnclassified {
                    return Target(id: projects[0].id, name: projects[0].name)
                }
                throw ToolError("Indica il progetto (ID o nome). " + available)
            }
            if includesUnclassified,
                reference == Target.unclassifiedID
                    || reference.localizedCaseInsensitiveCompare(Target.unclassifiedName) == .orderedSame
            {
                return Target(id: nil, name: Target.unclassifiedName)
            }
            let match =
                projects.first { $0.id == reference }
                ?? projects.first { $0.name.localizedCaseInsensitiveCompare(reference) == .orderedSame }
                ?? {
                    let partial = projects.filter { $0.name.localizedCaseInsensitiveContains(reference) }
                    return partial.count == 1 ? partial[0] : nil
                }()
            if let match { return Target(id: match.id, name: match.name) }
            throw ToolError("Progetto «\(reference)» non trovato tra quelli consultabili. " + available)
        }

        var available: String {
            var names = projects.map(\.name)
            if includesUnclassified { names.append("\(Target.unclassifiedName) (elementi senza progetto)") }
            return names.isEmpty
                ? "Nessun progetto è consultabile: l'utente può abilitarli in IAGO › Impostazioni › Claude."
                : "Progetti consultabili: \(names.joined(separator: ", "))."
        }

        func name(of projectID: String?) -> String? {
            projectID == nil ? Target.unclassifiedName : projects.first { $0.id == projectID }?.name
        }

        /// Content of this project (nil: without a project) is readable.
        func allows(_ projectID: String?) -> Bool {
            projectID.map(ids.contains) ?? includesUnclassified
        }

        func visible(_ item: Item) -> Bool {
            item.deletedAt == nil && item.trashedAt == nil && allows(item.projectId)
        }
    }

    func stream(_ name: String?, in project: Target) throws -> ProjectStream? {
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        guard let projectID = project.id else { throw ToolError("Gli elementi senza progetto non hanno stream.") }
        let streams = try archive.streams(projectID: projectID, includeArchived: true)
        if let match = streams.first(where: {
            $0.id == name || $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return match
        }
        let names = streams.map(\.name).joined(separator: ", ")
        throw ToolError(
            "Stream «\(name)» non trovato in «\(project.name)». "
                + (names.isEmpty ? "Il progetto non ha stream." : "Stream: \(names)."))
    }

    // MARK: Tools

    func listProjects(_ scope: Scope, _ returned: inout [String]) throws -> String {
        guard !scope.projects.isEmpty || scope.includesUnclassified else { return scope.available }
        var lines = ["# Progetti consultabili", ""]
        for project in scope.projects.sorted(by: { $0.name.localizedCompare($1.name) == .orderedAscending }) {
            returned.append(project.id)
            let items = try archive.summaries(.project(project.id))
            var facts = ["\(items.count) elementi"]
            let dates = items.map(\.item.occurredAt)
            if let first = dates.min(), let last = dates.max() {
                facts.append("dal \(day(first)) al \(day(last))")
            }
            if project.claudeWritable { facts.append("scrivibile") }
            let client = project.clientId.flatMap { scope.clients[$0]?.name }
            lines.append(
                "- **\(project.name)**" + (client.map { " — cliente \($0)" } ?? "") + " · id `\(project.id)` · "
                    + facts.joined(separator: ", "))
            let streams = try archive.streams(projectID: project.id).map(\.name)
            if !streams.isEmpty { lines.append("  - stream: \(streams.joined(separator: ", "))") }
        }
        if scope.includesUnclassified {
            let items = try archive.summaries(.unclassified)
            lines.append(
                "- **\(Target.unclassifiedName)** (elementi non ancora assegnati a un progetto) · id `\(Target.unclassifiedID)` · \(items.count) elementi"
            )
        }
        return lines.joined(separator: "\n")
    }

    func search(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String {
        guard let query = arguments["query"]?.string, !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ToolError("Indica cosa cercare (query).")
        }
        let limit = min(max(arguments["limit"]?.int ?? 30, 1), 100)
        let types = Set(arguments["types"]?.strings ?? [])
        let range = try dateRange(arguments)
        var searchScope = SearchScope.all
        var onlyUnclassified = false
        if let reference = arguments["project"]?.string {
            let project = try scope.project(reference)
            if let id = project.id { searchScope = .project(id) } else { onlyUnclassified = true }
            if let stream = try stream(arguments["stream"]?.string, in: project) { searchScope = .stream(stream.id) }
        }
        guard !scope.projects.isEmpty || scope.includesUnclassified else { return scope.available }
        var lines: [String] = []
        var items: [String: Item?] = [:]
        for hit in try archive.search(query, scope: searchScope, limit: 500) {
            let projectID = hit.projectID
            guard lines.count < limit, scope.allows(projectID), !onlyUnclassified || projectID == nil else { continue }
            var item: Item?
            if let itemID = hit.itemID {
                if items[itemID] == nil { items[itemID] = try archive.item(itemID) }
                guard let loaded = items[itemID] ?? nil, scope.visible(loaded) else { continue }
                item = loaded
            }
            let type: String
            let date: Date
            var heading: String
            switch hit.source {
            case .decision:
                guard let decision = try archive.decision(hit.sourceID), decision.deletedAt == nil else { continue }
                type = "decision"
                date = decision.decidedAt
                heading = "\(KeyPointLabels.kind(decision.kind)) (\(KeyPointLabels.status(decision)))"
            case .note:
                guard let note = try archive.note(hit.sourceID) else { continue }
                type = "note"
                date = note.notedAt
                heading = "Nota dell'utente" + (item.map { " su «\($0.title)»" } ?? " di progetto")
            case .transcript, .document:
                guard let item else { continue }
                type = item.type.rawValue
                date = item.occurredAt
                heading = "\(typeLabel(item.type)) «\(item.title)»"
                if let at = hit.atSec { heading += " @ \(TranscriptRenderer.clock(at))" }
            case .summary:
                guard let item else { continue }
                type = "summary"
                date = item.occurredAt
                heading = "Sintesi di «\(item.title)»"
            }
            guard types.isEmpty || types.contains(type), range.contains(date) else { continue }
            if let item { returned.append(item.id) } else { returned.append(hit.sourceID) }
            var line = "- \(day(date)) · \(heading) · progetto \(scope.name(of: projectID) ?? "")"
            if let item { line += " · item_id `\(item.id)`" }
            if hit.source == .decision { line += " · decision_id `\(hit.sourceID)`" }
            lines += [line, "  > \(hit.snippet.replacingOccurrences(of: "\n", with: " "))"]
        }
        guard !lines.isEmpty else {
            return "Nessun risultato per «\(query)». Prova parole diverse o sinonimi (la ricerca è per parole intere)."
        }
        return (["# Risultati per «\(query)»", "", "(«…» evidenzia le parole trovate)", ""] + lines)
            .joined(separator: "\n")
    }

    func getItem(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String {
        let item = try visibleItem(scope, arguments["item_id"]?.string)
        returned.append(item.id)
        var text = try ProjectExporter.itemMarkdown(item.id, archive: archive, timeZone: timeZone)
        // ADR-0072: the text read on the screenshots of the call, at their minute.
        let shots = try archive.screenshots(itemID: item.id)
        if !shots.isEmpty {
            text += "\n### Schermate catturate durante la call\n\n"
            text +=
                shots.map {
                    "- [\(TranscriptRenderer.clock($0.atSec ?? 0))] \(oneLine($0.text ?? "(nessun testo letto)", limit: 600))"
                }
                .joined(separator: "\n") + "\n"
            if (try archive.setting(Self.shareScreenshotsKey)) == "1" {
                text += "\nLe immagini si leggono con get_screenshots.\n"
            }
        }
        let decisions = try archive.decisions(sourceItemID: item.id)
        if !decisions.isEmpty {
            text += "\n### Decisioni nate da questo elemento\n\n"
            text +=
                decisions.map { ProjectExporter.decisionMarkdown($0, chainName: $0.chainName, timeZone: timeZone) }
                .joined(separator: "\n") + "\n"
        }
        let links = try archive.links(itemID: item.id).filter { scope.visible($0.item) }
        if !links.isEmpty {
            text += "\n### Collegamenti\n\n"
            text +=
                links.map {
                    "- \(linkLabel($0.link.kind, outgoing: $0.outgoing)): \(typeLabel($0.item.type)) «\($0.item.title)» del \(day($0.item.occurredAt)) · item_id `\($0.item.id)`"
                }.joined(separator: "\n") + "\n"
        }
        return text
    }

    func timeline(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String {
        let project = try scope.project(arguments["project"]?.string)
        let stream = try stream(arguments["stream"]?.string, in: project)
        let types = Set(arguments["types"]?.strings ?? [])
        let range = try dateRange(arguments)
        var entries: [(date: Date, line: String)] = []
        let summaries = try archive.summaries(stream.map { .stream($0.id) } ?? project.library)
            .filter { scope.visible($0.item) }
        for summary in summaries
        where (types.isEmpty || types.contains(summary.item.type.rawValue)) && range.contains(summary.item.occurredAt) {
            let item = summary.item
            returned.append(item.id)
            var line = "\(typeLabel(item.type))"
            if let email = summary.email {
                line = email.direction == .outbound ? "Email inviata" : "Email ricevuta"
                if let from = email.from { line += " da \(from.display)" }
            }
            line += " «\(item.title)»"
            if let duration = item.durationSec { line += " (\(TranscriptRenderer.minutes(duration)))" }
            if item.type == .call, !summary.hasTranscript { line += " (solo audio)" }
            if !summary.tags.isEmpty { line += " · tag \(summary.tags.joined(separator: ", "))" }
            line += " · item_id `\(item.id)`"
            entries.append((item.occurredAt, line))
        }
        if types.isEmpty || types.contains("note") {
            let itemIDs = summaries.map(\.item.id)
            for note in try archive.notes(projectID: project.id, itemIDs: itemIDs) where range.contains(note.notedAt) {
                let owner = summaries.first { $0.item.id == note.itemId }?.item.title
                entries.append(
                    (
                        note.notedAt,
                        "Nota dell'utente" + (owner.map { " su «\($0)»" } ?? " di progetto") + ": "
                            + oneLine(note.body, limit: 240)
                    ))
            }
        }
        if types.isEmpty || types.contains("decision") {
            let decisionScope: DecisionQuery.Scope = stream.map { .stream($0.id) } ?? project.decisions
            for summary in try archive.decisions(DecisionQuery(scope: decisionScope, statuses: []))
            where range.contains(summary.decision.decidedAt) {
                entries.append(
                    (
                        summary.decision.decidedAt,
                        "\(KeyPointLabels.kind(summary.decision.kind)) (\(KeyPointLabels.status(summary.decision))): \(summary.decision.text)"
                            + " · decision_id `\(summary.id)`"
                    ))
            }
        }
        guard !entries.isEmpty else { return "Nessun contenuto in «\(project.name)» con questi filtri." }
        let title = "# Cronologia di «\(project.name)»" + (stream.map { " · stream \($0.name)" } ?? "")
        return ([title, ""] + entries.sorted { $0.date < $1.date }.map { "- \(minute($0.date)) · \($0.line)" })
            .joined(separator: "\n")
    }

    func listDecisions(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String {
        let project = try scope.project(arguments["project"]?.string)
        let stream = try stream(arguments["stream"]?.string, in: project)
        let range = try dateRange(arguments)
        let statuses: Set<Decision.Status> =
            switch arguments["status"]?.string {
            case "active": [.active]
            case "superseded": [.superseded]
            case "cancelled": [.cancelled]
            case "done": [.done]
            default: []
            }
        let kinds: Set<Decision.Kind> =
            switch arguments["kind"]?.string {
            case "decision": [.decision]
            case "activity": [.action]
            case "milestone": [.milestone]
            default: []
            }
        let decisions = try archive.decisions(
            DecisionQuery(
                scope: stream.map { .stream($0.id) } ?? project.decisions, statuses: statuses, kinds: kinds)
        )
        .filter { range.contains($0.decision.decidedAt) }
        .sorted { $0.decision.decidedAt < $1.decision.decidedAt }
        .ranked(by: arguments["query"]?.string)
        guard !decisions.isEmpty else { return "Nessun punto chiave in «\(project.name)» con questi filtri." }
        returned = decisions.map(\.id)
        return
            (["# Punti chiave di «\(project.name)»", ""]
            + decisions.map { ProjectExporter.decisionMarkdown($0, chainName: $0.chainName, timeZone: timeZone) })
            .joined(separator: "\n")
    }

    func listNotes(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String {
        let project = try scope.project(arguments["project"]?.string)
        let range = try dateRange(arguments)
        let kind = arguments["kind"]?.string.flatMap(Note.Kind.init(rawValue:))
        let items = try archive.summaries(project.library).map(\.item).filter(scope.visible)
        let notes = try archive.notes(projectID: project.id, itemIDs: items.map(\.id))
            .filter { range.contains($0.notedAt) && (kind == nil || $0.kind == kind) }
            .sorted { $0.notedAt < $1.notedAt }
        guard !notes.isEmpty else { return "Nessuna nota in «\(project.name)» con questi filtri." }
        returned = notes.map(\.id)
        var lines = ["# Note dell'utente in «\(project.name)»"]
        for note in notes {
            let owner = items.first { $0.id == note.itemId }
            lines += [
                "",
                "## \(minute(note.notedAt)) · \(TranscriptRenderer.kindLabel(note.kind))"
                    + (owner.map { " su «\($0.title)» (item_id `\($0.id)`)" } ?? " · nota di progetto"),
                "", note.body,
            ]
        }
        return lines.joined(separator: "\n")
    }

    func thread(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String {
        let item = try visibleItem(scope, arguments["item_id"]?.string)
        guard item.type == .email else { throw ToolError("«\(item.title)» non è un'email.") }
        let thread = try archive.thread(itemID: item.id).filter(scope.visible)
        let messages = thread.isEmpty ? [item] : thread
        let metas = try archive.emailMetas(itemIDs: messages.map(\.id))
        returned = messages.map(\.id)
        var lines = ["# Conversazione «\(item.title)»", ""]
        for message in messages {
            let meta = metas[message.id]
            var line = "- \(minute(message.occurredAt)) · "
            line += meta?.direction == .outbound ? "inviata" : "ricevuta"
            if let from = meta?.from { line += " da \(from.display)" }
            if let to = meta?.to, !to.isEmpty { line += " a \(to.map(\.display).joined(separator: ", "))" }
            line += " · «\(message.title)» · item_id `\(message.id)`"
            if message.id == item.id { line += " ← questa" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    func exportProject(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String {
        let project = try scope.project(arguments["project"]?.string)
        let items = try archive.summaries(project.library).map(\.item).filter(scope.visible)
        returned = items.map(\.id)
        let documents: ProjectExporter.Options.Documents =
            arguments["documents"]?.string == "full" ? .full : .excerpt(3_000)
        return try ProjectExporter.markdown(
            ProjectExporter.Options(
                title: project.name, itemIDs: items.map(\.id), projectNoteIDs: project.id.map { [$0] } ?? [],
                decisionScope: project.decisions, documents: documents,
                filtersDescription: "export per Claude via MCP"),
            archive: archive, timeZone: timeZone)
    }

    // MARK: Helpers

    func visibleItem(_ scope: Scope, _ id: String?) throws -> Item {
        guard let id, !id.isEmpty else { throw ToolError("Indica item_id.") }
        guard let item = try archive.item(id), scope.visible(item) else {
            throw ToolError("Elemento \(id) non trovato tra i progetti consultabili.")
        }
        return item
    }

    func dateRange(_ arguments: JSON) throws -> ClosedRange<Date> {
        func parse(_ key: String, endOfDay: Bool) throws -> Date? {
            guard let text = arguments[key]?.string, !text.isEmpty else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3,
                let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
            else { throw ToolError("Data «\(text)» non valida: usa AAAA-MM-GG.") }
            return endOfDay ? calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) : start
        }
        let from = try parse("from", endOfDay: false) ?? .distantPast
        let to = try parse("to", endOfDay: true) ?? .distantFuture
        guard from <= to else { throw ToolError("L'intervallo di date è vuoto (from dopo to).") }
        return from...to
    }

    func day(_ date: Date) -> String { TranscriptRenderer.format(date, "yyyy-MM-dd", timeZone) }
    func minute(_ date: Date) -> String { TranscriptRenderer.format(date, "yyyy-MM-dd HH:mm", timeZone) }

    func oneLine(_ text: String, limit: Int) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
    }

    func typeLabel(_ type: Item.Kind) -> String {
        switch type {
        case .call: "Call"
        case .email: "Email"
        case .document: "Documento"
        }
    }

    func linkLabel(_ kind: ItemLink.Kind, outgoing: Bool) -> String {
        switch kind {
        case .followUpOf: outgoing ? "segue" : "seguito da"
        case .attachmentOf: outgoing ? "allegato di" : "allegato"
        case .replyTo: outgoing ? "risposta a" : "risposta"
        case .related: "correlato"
        }
    }
}

extension [DecisionSummary] {
    /// With a query: only the decisions sharing words with it, those sharing most first. Without: unchanged.
    func ranked(by query: String?) -> [DecisionSummary] {
        guard let query else { return self }
        let words = IAGOTools.significantWords(query)
        guard !words.isEmpty else { return self }
        return self.map { summary in
            let own = IAGOTools.significantWords(summary.decision.text + " " + (summary.decision.notes ?? ""))
            let partial = words.filter { word in own.contains { $0.hasPrefix(word) || word.hasPrefix($0) } }
            return (summary, partial.count)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }
}

extension IAGOTools {
    /// Download, Scrivania and Documenti, three levels deep, at most 20 000 entries: enough for "the PDF I just got".
    func findFile(_ arguments: JSON) throws -> String {
        guard let name = arguments["name"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), name.count >= 2
        else { throw ToolError("Indica almeno due lettere del nome del file.") }
        let wanted = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        var found: [(url: URL, size: Int, date: Date)] = []
        var visited = 0
        for folder in ["Downloads", "Desktop", "Documents"] {
            let root = filesRoot.appendingPathComponent(folder, isDirectory: true)
            guard
                let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants])
            else { continue }
            for case let url as URL in enumerator {
                visited += 1
                if visited > 20_000 { break }
                if enumerator.level > 3 { enumerator.skipDescendants() }
                guard
                    url.lastPathComponent.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                        .contains(wanted),
                    let values = try? url.resourceValues(forKeys: [
                        .isRegularFileKey, .fileSizeKey, .contentModificationDateKey,
                    ]),
                    values.isRegularFile == true
                else { continue }
                found.append((url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast))
            }
        }
        guard !found.isEmpty else {
            return
                "Nessun file con «\(name)» nel nome in Download, Scrivania e Documenti. Chiedi all'utente dove si trova."
        }
        let lines = found.sorted { $0.date > $1.date }.prefix(10).map {
            "- `\($0.url.path)` · \(ByteCountFormatter.string(fromByteCount: Int64($0.size), countStyle: .file)) · \(minute($0.date))"
        }
        return (["# File trovati (i più recenti per primi)", ""] + lines).joined(separator: "\n")
    }
}
