import CryptoKit
import Foundation
import IAGOCore
import IAGOExport
import IAGOIngest
import IAGOStore
import UniformTypeIdentifiers

/// Writing through Claude (ADR-0044, ADR-0047): notes, decisions, documents and emails in projects where the user
/// turned on "Claude può anche scrivere". Transcripts, audio and originals are never touched. Every write is
/// recorded in `mcp_change` so it can be undone from IAGO, and shown as "Inserita/Modificata tramite Claude (MCP)".
///
/// Each write takes two calls (ADR-0047): without `confirmation` the tool only returns a preview (what, where,
/// links, date and place in the timeline, doubts) and a code; with that code and the same arguments it writes.
extension IAGOTools {
    static let writeNotice =
        "In IAGO compare come «inserita tramite Claude (MCP)» e l'utente può annullarla da Impostazioni › Claude."

    /// How long a preview stays valid, in minutes.
    static let confirmationMinutes = 15

    var writeTools: [ToolDefinition] { baseWriteTools + workWriteTools(confirmation: Self.confirmationArgument) }

    static let confirmationArgument: JSON = [
        "type": "string",
        "description": """
        Codice dell'anteprima. Senza: lo strumento non scrive e restituisce l'anteprima da mostrare \
        all'utente. Con il codice e gli stessi parametri: scrive.
        """,
    ]

    var baseWriteTools: [ToolDefinition] {
        let project: JSON = [
            "type": "string",
            "description": "ID o nome del progetto; facoltativo se la connessione ha un solo progetto.",
        ]
        let date: JSON = [
            "type": "string",
            "description": """
            Facoltativo, solo se l'utente indica una data: AAAA-MM-GG o AAAA-MM-GG HH:mm, oppure "source" per \
            la data esatta della fonte. Senza: adesso, cioè in cima alla timeline.
            """,
        ]
        let stream: JSON = [
            "type": "string", "description": "Facoltativo: nome di uno stream del progetto (vedi list_projects).",
        ]
        let confirmation: JSON = [
            "type": "string",
            "description": """
            Codice dell'anteprima. Senza: lo strumento non scrive e restituisce l'anteprima da mostrare \
            all'utente. Con il codice e gli stessi parametri: scrive.
            """,
        ]
        let preview = " Funziona in due passi: anteprima, poi conferma con il codice dopo l'OK dell'utente."
        return [
            ToolDefinition(
                name: "add_note",
                description: """
                    Aggiunge una nota dell'utente: un'informazione da ricordare. Su un elemento (item_id: call, \
                    email, documento, file) o sul progetto, eventualmente in uno stream. Se il testo è una scelta \
                    presa usa add_decision; se è qualcosa da fare, add_decision con kind activity.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "text": ["type": "string", "description": "Testo della nota (Markdown)."],
                        "item_id": ["type": "string", "description": "Facoltativo: l'elemento a cui si riferisce."],
                        "project": project, "stream": stream, "date": date, "confirmation": confirmation,
                    ],
                    "required": ["text"],
                ], title: "Aggiungi nota"),
            ToolDefinition(
                name: "update_note",
                description: "Sostituisce il testo di una nota (note_id da list_notes o get_item)." + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "note_id": ["type": "string"], "text": ["type": "string"], "confirmation": confirmation,
                    ],
                    "required": ["note_id", "text"],
                ], title: "Modifica nota"),
            ToolDefinition(
                name: "add_decision",
                description: """
                    Registra un punto chiave: una decisione presa dall'utente o dal suo gruppo, un'attività (da \
                    fare) o una tappa (fatto avvenuto). Titolo breve in `text`, dettagli in `description`. Prima \
                    cerca con list_decisions (query) le decisioni attive sullo stesso tema: se questa ne cambia \
                    una o più, di qualsiasi tipo, indicale in supersedes_ids (diventano Superate). Collegala alla \
                    fonte: source_item_id \
                    (call con at_sec, email, documento) o source_note_id.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "text": ["type": "string", "description": "Cosa è stato deciso, in breve."],
                        "kind": [
                            "type": "string", "enum": ["decision", "activity", "milestone"],
                            "description":
                                "decision (default), activity (da fare o in corso) o milestone (tappa: fatto importante avvenuto).",
                        ],
                        "description": ["type": "string", "description": "Facoltativo: contesto e motivazioni."],
                        "project": project, "stream": stream, "date": date,
                        "source_item_id": ["type": "string", "description": "Facoltativo: elemento da cui nasce."],
                        "at_sec": ["type": "number", "description": "Facoltativo: secondo della call."],
                        "source_note_id": ["type": "string", "description": "Facoltativo: nota da cui nasce."],
                        "supersedes_ids": [
                            "type": "array", "items": ["type": "string"],
                            "description":
                                "Facoltativo: punti chiave (decisioni, attività o tappe) che questo supera.",
                        ],
                        "supersedes_id": ["type": "string", "description": "Come supersedes_ids, per una sola voce."],
                        "people": ["type": "array", "items": ["type": "string"]],
                        "tags": ["type": "array", "items": ["type": "string"]],
                        "confirmation": confirmation,
                    ],
                    "required": ["text"],
                ], title: "Registra punto chiave"),
            ToolDefinition(
                name: "update_decision",
                description: """
                    Modifica un punto chiave: titolo, descrizione, stato (active o cancelled; done per le attività), \
                    stream, nome della catena o le voci che supera (supersedes_ids: l'elenco completo, che sostituisce \
                    quello attuale; elenco vuoto per nessuna). Per registrare che una decisione è cambiata usa \
                    add_decision con supersedes_ids.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "decision_id": ["type": "string"], "text": ["type": "string"],
                        "description": ["type": "string"],
                        "status": [
                            "type": "string", "enum": ["active", "done", "cancelled"],
                            "description": "done solo per le attività.",
                        ],
                        "stream": ["type": "string", "description": "Nome dello stream; stringa vuota per toglierlo."],
                        "supersedes_ids": [
                            "type": "array", "items": ["type": "string"],
                            "description": "Elenco completo delle voci che supera; vuoto per nessuna.",
                        ],
                        "supersedes_id": [
                            "type": "string", "description": "Una sola voce; stringa vuota per nessuna.",
                        ],
                        "chain_name": ["type": "string", "description": "Stringa vuota per toglierlo."],
                        "confirmation": confirmation,
                    ],
                    "required": ["decision_id"],
                ], title: "Modifica punto chiave"),
            ToolDefinition(
                name: "create_document",
                description: """
                    Crea un documento nel progetto con il Markdown dato (verbale, riepilogo, appunti strutturati), \
                    eventualmente in uno stream e collegato agli elementi da cui nasce (related_item_ids). Resta un \
                    documento separato: non modifica trascrizioni o altri elementi.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string"], "markdown": ["type": "string"], "project": project,
                        "stream": stream, "date": date,
                        "related_item_ids": [
                            "type": "array", "items": ["type": "string"],
                            "description": "Facoltativo: elementi a cui collegarlo.",
                        ],
                        "confirmation": confirmation,
                    ],
                    "required": ["title", "markdown"],
                ], title: "Crea documento"),
            ToolDefinition(
                name: "import_file",
                description: """
                    Importa un file che è sul Mac dell'utente, gli stessi che accetta IAGO: PDF, immagini, Word, \
                    testo (originale cifrato + testo estratto, OCR se serve), email .eml, audio e video (convertiti e \
                    trascritti dall'app), trascrizioni di Teams (.vtt, .docx). Serve il percorso: un file caricato \
                    nella chat non arriva a IAGO, quindi trovalo con find_file o chiedilo all'utente. Collegalo agli elementi da cui nasce \
                    (related_item_ids), per esempio l'email che lo accompagna.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Percorso completo del file sul Mac."],
                        "title": ["type": "string", "description": "Facoltativo: titolo (default: nome del file)."],
                        "project": project, "stream": stream, "date": date,
                        "related_item_ids": [
                            "type": "array", "items": ["type": "string"],
                            "description": "Facoltativo: elementi a cui collegarlo.",
                        ],
                        "confirmation": confirmation,
                    ],
                    "required": ["path"],
                ], title: "Importa file"),
            ToolDefinition(
                name: "write_batch",
                description: """
                    Più note e punti chiave insieme, con una sola anteprima e una sola conferma: per esempio ciò che \
                    emerge da una call. entries è un elenco di {tool: add_note o add_decision, arguments: gli \
                    stessi parametri di quello strumento, senza confirmation}. Massimo 20 voci.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "entries": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "tool": ["type": "string", "enum": ["add_note", "add_decision"]],
                                    "arguments": ["type": "object"],
                                ],
                                "required": ["tool", "arguments"],
                            ],
                        ],
                        "confirmation": confirmation,
                    ],
                    "required": ["entries"],
                ], title: "Scrivi più voci"),
            ToolDefinition(
                name: "add_email",
                description: """
                    Inserisce un'email che l'utente ti ha incollato o dettato (mittente, destinatari, oggetto, data, \
                    direzione, testo). Indirizzi nel formato "Nome <email>". La data è quella dell'email: chiedila \
                    se non la conosci.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "subject": ["type": "string"], "body": ["type": "string", "description": "Testo (Markdown)."],
                        "from": ["type": "string"],
                        "to": ["type": "array", "items": ["type": "string"]],
                        "direction": ["type": "string", "enum": ["inbound", "outbound"]],
                        "attachment_paths": [
                            "type": "array", "items": ["type": "string"],
                            "description":
                                "Facoltativo: percorsi completi sul Mac dei file allegati, importati come documenti collegati all'email.",
                        ],
                        "project": project, "stream": stream,
                        "date": [
                            "type": "string", "description": "Data dell'email: AAAA-MM-GG o AAAA-MM-GG HH:mm.",
                        ],
                        "confirmation": confirmation,
                    ],
                    "required": ["subject", "body"],
                ], title: "Inserisci email"),
        ]
    }

    /// What a write will do, checked before anything is written.
    struct WritePlan {
        /// What will be written, where and when: one line each.
        var summary: [String]
        /// What the user should settle before confirming.
        var doubts: [String] = []
        var apply: (_ writer: Archive, _ returned: inout [String]) throws -> String
    }

    /// nil when `name` is not a write tool.
    func callWrite(_ name: String, _ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String? {
        guard writeTools.contains(where: { $0.name == name }) else { return nil }
        guard let openWriter else { throw ToolError("Questa connessione di IAGO è in sola lettura.") }
        let plan = try plan(name, scope, arguments)
        if let code = arguments["confirmation"]?.string?.trimmingCharacters(in: .whitespaces), !code.isEmpty {
            guard isValidConfirmation(code, tool: name, arguments) else {
                throw ToolError(
                    "Codice di conferma non valido o scaduto, oppure i parametri sono cambiati dopo l'anteprima: richiama \(name) senza confirmation per una nuova anteprima e mostrala all'utente."
                )
            }
            return try plan.apply(try openWriter(), &returned)
        }
        var lines = ["ANTEPRIMA: non ho ancora scritto nulla in IAGO.", ""] + plan.summary.map { "- \($0)" }
        if !plan.doubts.isEmpty {
            lines += ["", "Dubbi da chiarire con l'utente prima di confermare:"] + plan.doubts.map { "- \($0)" }
        }
        lines += [
            "",
            "Mostra questa anteprima all'utente e chiedi conferma. Solo dopo il suo OK richiama \(name) con gli stessi identici parametri e confirmation=\"\(confirmationCode(tool: name, arguments, minute: currentMinute))\" (valido \(Self.confirmationMinutes) minuti). Se l'utente cambia qualcosa, chiedi una nuova anteprima con i parametri corretti.",
        ]
        return lines.joined(separator: "\n")
    }

    func plan(_ name: String, _ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        switch name {
        case "add_note": try planNote(scope, arguments)
        case "update_note": try planNoteUpdate(scope, arguments)
        case "add_decision": try planDecision(scope, arguments)
        case "update_decision": try planDecisionUpdate(scope, arguments)
        case "create_document": try planDocument(scope, arguments)
        case "add_email": try planEmail(scope, arguments)
        case "import_file": try planFile(scope, arguments)
        case "write_batch": try planBatch(scope, arguments)
        case "set_summary": try planSummary(scope, arguments)
        case "propose_suggestions": try planSuggestions(scope, arguments)
        default: throw ToolError("Strumento sconosciuto: \(name).")
        }
    }

    /// Several notes and key points under one preview and one confirmation, e.g. what came out of a call.
    func planBatch(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        guard let entries = arguments["entries"]?.array, !entries.isEmpty else {
            throw ToolError("Indica entries: un elenco di {tool, arguments} con tool add_note o add_decision.")
        }
        guard entries.count <= Self.batchLimit else {
            throw ToolError("Al massimo \(Self.batchLimit) voci per volta: dividile in più gruppi.")
        }
        var plans: [WritePlan] = []
        var summary: [String] = []
        var doubts: [String] = []
        for (index, entry) in entries.enumerated() {
            let tool = entry["tool"]?.string ?? ""
            guard ["add_note", "add_decision"].contains(tool) else {
                throw ToolError("Voce \(index + 1): tool deve essere add_note o add_decision.")
            }
            let plan = try plan(tool, scope, entry["arguments"] ?? .object([:]))
            plans.append(plan)
            summary.append("Voce \(index + 1): " + plan.summary.joined(separator: " · "))
            doubts += plan.doubts.map { "Voce \(index + 1): \($0)" }
        }
        return WritePlan(summary: summary, doubts: doubts) { writer, returned in
            var done: [String] = []
            for (index, plan) in plans.enumerated() {
                do {
                    done.append("Voce \(index + 1): " + (try plan.apply(writer, &returned)))
                } catch {
                    let detail = (error as? ToolError)?.message ?? "\(error)"
                    throw ToolError(
                        (done + [
                            "Voce \(index + 1) non scritta: \(detail). Le voci precedenti sono state scritte; le successive no."
                        ])
                        .joined(separator: "\n"))
                }
            }
            return done.joined(separator: "\n")
        }
    }

    static let batchLimit = 20

    // MARK: Confirmation

    var currentMinute: Int { Int(clock().timeIntervalSince1970 / 60) }

    /// "<minute>-<HMAC of tool, minute and arguments>": bound to the arguments, valid for a few minutes, keyed per
    /// process so it cannot be made up.
    func confirmationCode(tool: String, _ arguments: JSON, minute: Int) -> String {
        var rest = arguments
        if case .object(var object) = rest {
            object["confirmation"] = nil
            rest = .object(object)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let canonical = (try? encoder.encode(rest)) ?? Data()
        var message = Data("\(tool)\n\(minute)\n".utf8)
        message.append(canonical)
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: previewKey)
        return "\(String(minute, radix: 36))-" + mac.prefix(5).map { String(format: "%02x", $0) }.joined()
    }

    func isValidConfirmation(_ code: String, tool: String, _ arguments: JSON) -> Bool {
        guard let dash = code.firstIndex(of: "-"), let minute = Int(code[..<dash], radix: 36) else { return false }
        let age = currentMinute - minute
        guard (0...Self.confirmationMinutes).contains(age) else { return false }
        return confirmationCode(tool: tool, arguments, minute: minute) == code
    }

    // MARK: Permission

    /// The project, if Claude may write there.
    func writableProject(_ scope: Scope, _ projectID: String?) throws -> Project {
        guard let projectID, let project = scope.projects.first(where: { $0.id == projectID }) else {
            throw ToolError(
                "Da Claude si può scrivere solo nei progetti consultabili, non tra gli elementi da classificare.")
        }
        guard project.claudeWritable else {
            throw ToolError(
                "Il progetto «\(project.name)» è consultabile ma non scrivibile: l'utente può attivare \"Claude può anche scrivere\" nelle impostazioni del progetto in IAGO."
            )
        }
        return project
    }

    func writableTarget(_ scope: Scope, _ arguments: JSON) throws -> Project {
        let target = try scope.project(arguments["project"]?.string)
        return try writableProject(scope, target.id)
    }

    func requiredText(_ arguments: JSON, _ key: String) throws -> String {
        guard let text = arguments[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
        else { throw ToolError("Manca \(key).") }
        return text
    }

    func stream(_ arguments: JSON, in project: Project) throws -> ProjectStream? {
        try stream(arguments["stream"]?.string, in: Target(id: project.id, name: project.name))
    }

    /// "AAAA-MM-GG" or "AAAA-MM-GG HH:mm"; nil when absent or "source".
    func moment(_ arguments: JSON) throws -> Date? {
        guard let text = arguments["date"]?.string?.trimmingCharacters(in: .whitespaces), !text.isEmpty,
            !wantsSourceDate(arguments)
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = text.split(whereSeparator: { $0 == "-" || $0 == " " || $0 == ":" || $0 == "T" })
            .compactMap { Int($0) }
        guard parts.count == 3 || parts.count >= 5,
            let date = calendar.date(
                from: DateComponents(
                    year: parts[0], month: parts[1], day: parts[2], hour: parts.count >= 5 ? parts[3] : 12,
                    minute: parts.count >= 5 ? parts[4] : 0))
        else {
            throw ToolError("Data «\(text)» non valida: usa AAAA-MM-GG, AAAA-MM-GG HH:mm oppure \"source\".")
        }
        return date
    }

    func wantsSourceDate(_ arguments: JSON) -> Bool {
        arguments["date"]?.string?.trimmingCharacters(in: .whitespaces).lowercased() == "source"
    }

    /// The date of a new entry: the one given, the source's, or now. With the line that tells where it goes.
    func when(_ arguments: JSON, source: Date?, projectID: String) throws -> (date: Date?, line: String, doubt: String?)
    {
        if wantsSourceDate(arguments) {
            guard let source else {
                throw ToolError("date=\"source\" vale solo con una fonte (item_id, source_item_id o source_note_id).")
            }
            return (source, "Data: quella della fonte, \(minute(source)). " + (try place(source, projectID)), nil)
        }
        if let given = try moment(arguments) {
            let past = given < clock().addingTimeInterval(-600)
            return (
                given, "Data: \(minute(given)). " + (try place(given, projectID)),
                past
                    ? "La data è nel passato: la voce non comparirà in cima alla timeline. Conferma con l'utente che è quella giusta."
                    : nil
            )
        }
        return (nil, "Data: adesso, \(minute(clock())). In cima alla timeline del progetto.", nil)
    }

    /// Where an entry dated `date` appears in the project timeline, between its neighbours.
    func place(_ date: Date, _ projectID: String) throws -> String {
        var entries: [(date: Date, label: String)] = []
        let items = try archive.summaries(.project(projectID)).map(\.item)
        entries += items.map { ($0.occurredAt, "«\(oneLine($0.title, limit: 60))»") }
        entries += try archive.decisions(DecisionQuery(scope: .project(projectID), statuses: [])).map {
            ($0.decision.decidedAt, "il punto chiave «\(oneLine($0.decision.text, limit: 60))»")
        }
        entries += try archive.notes(projectID: projectID, itemIDs: items.map(\.id)).map {
            ($0.notedAt, "la nota «\(oneLine($0.body, limit: 40))»")
        }
        let above = entries.filter { $0.date > date }.min { $0.date < $1.date }
        let below = entries.filter { $0.date <= date }.max { $0.date < $1.date }
        guard let above else { return "In cima alla timeline del progetto." }
        return "In timeline compare il \(minute(date)), sotto \(above.label)"
            + (below.map { " e sopra \($0.label)." } ?? ", in fondo.")
    }

    /// A doubt when the project has streams and none was chosen.
    func streamDoubt(_ project: Project, chosen: ProjectStream?) throws -> String? {
        guard chosen == nil else { return nil }
        let names = try archive.streams(projectID: project.id).map(\.name)
        guard !names.isEmpty else { return nil }
        return
            "Il progetto ha degli stream (\(names.joined(separator: ", "))): chiedi all'utente se va in uno di questi."
    }

    // MARK: Notes

    func planNote(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        let text = try requiredText(arguments, "text")
        var item: Item?
        if let itemID = arguments["item_id"]?.string, !itemID.isEmpty { item = try visibleItem(scope, itemID) }
        let project = try item.map { try writableProject(scope, $0.projectId) } ?? writableTarget(scope, arguments)
        let stream = try stream(arguments, in: project)
        let date = try when(arguments, source: item?.occurredAt, projectID: project.id)
        var summary = [
            "Nota: «\(oneLine(text, limit: 120))»",
            "Progetto: \(project.name)" + (stream.map { " · stream \($0.name)" } ?? ""),
            item.map { "Sull'elemento: «\($0.title)» (\(minute($0.occurredAt)))" } ?? "Nota di progetto",
            date.line,
        ]
        if item != nil, stream == nil { summary[1] += " · segue l'elemento" }
        var doubts = [date.doubt, item == nil ? try streamDoubt(project, chosen: stream) : nil].compactMap { $0 }
        if let kind = Self.looksLike(text) {
            doubts.append(
                "Il testo sembra \(kind == .decision ? "una decisione" : "un'attività"): chiedi all'utente se registrarlo come punto chiave (add_decision) invece che come nota."
            )
        }
        let similar = try similarNotes(to: text, project: project)
        if !similar.isEmpty {
            doubts.append(
                "Esistono già note quasi uguali: chiedi all'utente se aggiornarne una (update_note) invece di aggiungerne un'altra: "
                    + similar.map { "«\(oneLine($0.body, limit: 60))» del \(minute($0.notedAt)) (note_id `\($0.id)`)" }
                    .joined(separator: "; "))
        }
        return WritePlan(summary: summary, doubts: doubts) { writer, returned in
            let note = try writer.addNote(
                itemID: item?.id, projectID: item == nil ? project.id : nil, body: text, notedAt: date.date ?? clock(),
                input: .mcp, streams: stream.map { [$0.id] } ?? [])
            try writer.recordMCPChange(.note, id: note.id, action: .create)
            returned.append(note.id)
            return "Nota aggiunta (note_id `\(note.id)`). \(date.line) " + Self.writeNotice
        }
    }

    func planNoteUpdate(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        let id = try requiredText(arguments, "note_id")
        let text = try requiredText(arguments, "text")
        guard let note = try archive.note(id) else { throw ToolError("Nota \(id) non trovata.") }
        var projectID = note.projectId
        if let itemID = note.itemId { projectID = try visibleItem(scope, itemID).projectId }
        let project = try writableProject(scope, projectID)
        return WritePlan(
            summary: [
                "Nota in «\(project.name)» del \(minute(note.notedAt))",
                "Prima: «\(oneLine(note.body, limit: 120))»",
                "Dopo: «\(oneLine(text, limit: 120))»",
                "La data e la posizione in timeline non cambiano.",
            ]
        ) { writer, returned in
            try writer.recordMCPChange(.note, id: id, action: .update, previous: MCPPrevious(body: note.body))
            try writer.updateNote(id) { $0.body = text }
            returned.append(id)
            return "Nota aggiornata. In IAGO compare come «modificata tramite Claude (MCP)» e si può annullare."
        }
    }

    // MARK: Decisions

    func planDecision(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        let text = try requiredText(arguments, "text")
        let kind: Decision.Kind =
            switch arguments["kind"]?.string {
            case "activity": .action
            case "milestone": .milestone
            default: .decision
            }
        var sourceItem: Item?
        if let itemID = arguments["source_item_id"]?.string, !itemID.isEmpty {
            sourceItem = try visibleItem(scope, itemID)
        }
        var sourceNote: Note?
        if let noteID = arguments["source_note_id"]?.string, !noteID.isEmpty {
            guard let note = try archive.note(noteID) else { throw ToolError("Nota \(noteID) non trovata.") }
            if let itemID = note.itemId { _ = try visibleItem(scope, itemID) }
            sourceNote = note
            if sourceItem == nil, let itemID = note.itemId { sourceItem = try archive.item(itemID) }
        }
        let projectID = sourceItem?.projectId ?? sourceNote?.projectId
        let project = try projectID.map { try writableProject(scope, $0) } ?? writableTarget(scope, arguments)
        let stream = try stream(arguments, in: project)
        let targets = try supersedeTargets(arguments, project: project) ?? []
        let atSec =
            sourceItem == nil
            ? nil
            : arguments["at_sec"].flatMap { value -> Double? in
                if case .number(let number) = value { return number }
                return value.string.flatMap(Double.init)
            }
        let sourceDate =
            sourceNote?.notedAt ?? sourceItem.map { $0.occurredAt.addingTimeInterval(atSec ?? 0) }
        let date = try when(arguments, source: sourceDate, projectID: project.id)
        let description = arguments["description"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines)

        var summary = [
            "\(Self.kindLabel(kind)): «\(oneLine(text, limit: 120))»",
            "Progetto: \(project.name)" + (stream.map { " · stream \($0.name)" } ?? ""),
            date.line,
        ]
        if let sourceItem {
            summary.append(
                "Fonte: «\(sourceItem.title)»" + (atSec.map { " al minuto \(TranscriptRenderer.clock($0))" } ?? ""))
        }
        if let sourceNote { summary.append("Nasce dalla nota «\(oneLine(sourceNote.body, limit: 60))»") }
        let people = arguments["people"]?.strings ?? []
        let tags = arguments["tags"]?.strings ?? []
        if !people.isEmpty { summary.append("Persone: \(people.joined(separator: ", "))") }
        if !tags.isEmpty { summary.append("Tag: \(tags.map { "#\($0)" }.joined(separator: " "))") }
        for target in targets {
            summary.append(
                "Supera: «\(oneLine(target.decision.text, limit: 80))» del \(minute(target.decision.decidedAt)), che diventerà Superata"
            )
        }
        var doubts = [date.doubt, try streamDoubt(project, chosen: stream)].compactMap { $0 }
        if let latest = targets.map(\.decision.decidedAt).max(), (date.date ?? clock()) < latest {
            doubts.append(
                "La data è precedente a quella di una voce che supera (\(minute(latest))): nella catena risulterebbe più vecchia. Chiedi all'utente quale data usare."
            )
        }
        if targets.isEmpty {
            let similar = try similarDecisions(to: text, project: project, stream: stream)
            if !similar.isEmpty {
                doubts.append(
                    "Ci sono punti chiave attivi simili: chiedi all'utente se questo ne supera qualcuno (supersedes_ids) o se sono distinti: "
                        + similar.map { "«\(oneLine($0.decision.text, limit: 60))» (decision_id `\($0.id)`)" }
                        .joined(separator: "; "))
            }
        }
        if kind == .decision, Self.looksLike(text) == .action {
            doubts.append("Il titolo sembra qualcosa da fare: chiedi all'utente se è un'attività (kind activity).")
        }
        return WritePlan(summary: summary, doubts: doubts) { writer, returned in
            let decision = try writer.createDecision(
                Decision(
                    text: text, decidedAt: date.date ?? clock(), projectId: project.id, sourceItemId: sourceItem?.id,
                    sourceAtSec: atSec, sourceNoteId: sourceNote?.id, origin: .mcp,
                    notes: description?.isEmpty == false ? description : nil, kind: kind),
                people: people, tags: tags,
                streams: stream.map { [$0.id] } ?? [], supersedes: targets.map(\.id))
            try writer.recordMCPChange(.decision, id: decision.id, action: .create)
            returned.append(decision.id)
            return "\(Self.kindLabel(kind)) registrata in «\(project.name)» (decision_id `\(decision.id)`)"
                + (targets.isEmpty
                    ? ". "
                    : targets.count == 1
                        ? ", e quella precedente ora risulta Superata. "
                        : ", e le \(targets.count) voci precedenti ora risultano Superate. ") + "\(date.line) "
                + Self.writeNotice
        }
    }

    func planDecisionUpdate(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        let id = try requiredText(arguments, "decision_id")
        guard let summary = try archive.decisionSummary(id) else { throw ToolError("Decisione \(id) non trovata.") }
        let current = summary.decision
        let project = try writableProject(scope, current.projectId)
        let status: Decision.Status? =
            switch arguments["status"]?.string {
            case "active": .active
            case "cancelled": .cancelled
            case "done" where current.kind == .action: .done
            case nil: nil
            default: throw ToolError("Stato non valido: usa active o cancelled (done solo per le attività).")
            }
        if status != nil, current.status == .superseded {
            throw ToolError("La decisione è Superata: segue la sua catena, lo stato non si cambia a mano.")
        }
        let text = arguments["text"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = arguments["description"]?.string
        let chainName = arguments["chain_name"]?.string
        var streams: [String]?
        if let name = arguments["stream"]?.string {
            streams =
                try stream(name.isEmpty ? nil : name, in: Target(id: project.id, name: project.name))
                .map { [$0.id] } ?? []
        }
        let newTargets = try supersedeTargets(arguments, project: project)
        if newTargets?.contains(where: { $0.id == current.id }) == true {
            throw ToolError("Una voce non può superare sé stessa.")
        }
        guard
            text != nil || description != nil || status != nil || chainName != nil || streams != nil
                || newTargets != nil
        else {
            throw ToolError(
                "Niente da modificare: indica text, description, status, stream, supersedes_ids o chain_name.")
        }
        var lines = ["\(Self.kindLabel(current.kind)) «\(oneLine(current.text, limit: 80))» in «\(project.name)»"]
        if let text, !text.isEmpty { lines.append("Titolo: «\(oneLine(text, limit: 120))»") }
        if description != nil { lines.append("Descrizione nuova") }
        if let status { lines.append("Stato: \(status.rawValue)") }
        if let streams {
            lines.append(
                streams.isEmpty
                    ? "Senza stream" : "Stream: \(arguments["stream"]?.string ?? "")")
        }
        if let chainName { lines.append(chainName.isEmpty ? "Catena senza nome" : "Nome della catena: «\(chainName)»") }
        var reorders = false
        var doubts: [String] = []
        if let newTargets {
            let before = Set(summary.supersedesAll.map(\.id))
            let after = Set(newTargets.map(\.id))
            for target in newTargets where !before.contains(target.id) {
                lines.append("Supera: «\(oneLine(target.decision.text, limit: 80))», che diventerà Superata")
                if try archive.comesLater(target.id, than: current.id) {
                    reorders = true
                    lines.append(
                        "Cambia l'ordine della catena: oggi «\(oneLine(target.decision.text, limit: 60))» viene dopo questa voce; questa passa dopo di lei e il resto della catena resta in ordine."
                    )
                }
                if current.decidedAt < target.decision.decidedAt {
                    doubts.append(
                        "Questa voce è del \(minute(current.decidedAt)), più vecchia di «\(oneLine(target.decision.text, limit: 60))» che supererebbe (\(minute(target.decision.decidedAt))). Chiedi all'utente se va bene."
                    )
                }
            }
            for previous in summary.supersedesAll where !after.contains(previous.id) {
                lines.append(
                    "Non supera più «\(oneLine(previous.text, limit: 80))»: torna Attiva se nessun'altra voce la supera."
                )
            }
            if before == after { lines.append("Le voci superate restano le stesse.") }
            if reorders {
                doubts.append("Cambia l'ordine di una catena di decisioni: fallo confermare esplicitamente all'utente.")
            }
        }
        lines.append("La data e la posizione in timeline non cambiano.")
        let (newIDs2, reorders2, streams2) = (newTargets?.map(\.id), reorders, streams)
        return WritePlan(summary: lines, doubts: doubts) { writer, returned in
            let (newIDs, reorders, streams) = (newIDs2, reorders2, streams2)
            let touched = [current.id] + (newIDs ?? []) + summary.supersedesAll.map(\.id)
            try writer.recordMCPChange(
                .decision, id: id, action: .update,
                previous: MCPPrevious(
                    text: current.text, notes: current.notes, status: current.status,
                    chainName: try archive.chainName(of: id), streamIDs: summary.streamIDs,
                    chain: newIDs == nil ? nil : try archive.decisionLinks(ofChainsOf: touched)))
            try writer.updateDecision(id, streams: streams, supersedes: newIDs, reorderingChain: reorders) {
                decision in
                if let text, !text.isEmpty { decision.text = text }
                if let description {
                    let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    decision.notes = trimmed.isEmpty ? nil : trimmed
                }
                if let status { decision.status = status }
            }
            if let chainName { try writer.setChainName(chainName, decisionID: id) }
            returned.append(id)
            return "Punto chiave aggiornato. In IAGO compare come «modificato tramite Claude (MCP)» e si può annullare."
        }
    }

    /// The entries to supersede (ADR-0052): `supersedes_ids`, or `supersedes_id` as a list of one; nil when neither
    /// is given. They must be in the same project.
    func supersedeTargets(_ arguments: JSON, project: Project) throws -> [DecisionSummary]? {
        let ids: [String]
        if let list = arguments["supersedes_ids"]?.strings {
            ids = list
        } else if let one = arguments["supersedes_id"]?.string {
            ids = one.isEmpty ? [] : [one]
        } else {
            return nil
        }
        var seen: Set<String> = []
        return try ids.filter { seen.insert($0).inserted }.map { id in
            guard let target = try archive.decisionSummary(id), target.decision.projectId == project.id else {
                throw ToolError("Il punto chiave \(id) da superare non è in «\(project.name)».")
            }
            return target
        }
    }

    /// Notes of the project and its items that say nearly the same as `text`.
    func similarNotes(to text: String, project: Project) throws -> [Note] {
        let words = Self.significantWords(text)
        guard words.count >= 2 else { return [] }
        let items = try archive.summaries(.project(project.id)).map(\.id)
        return try archive.notes(projectID: project.id, itemIDs: items)
            .filter { note in
                let other = Self.significantWords(note.body)
                let shared = words.intersection(other).count
                return shared >= 2 && Double(shared) / Double(max(words.count, other.count, 1)) >= 0.6
            }
            .prefix(3).map { $0 }
    }

    /// Active decisions and activities of the project (or stream) that share most of their words with `text`.
    func similarDecisions(to text: String, project: Project, stream: ProjectStream?) throws -> [DecisionSummary] {
        let words = Self.significantWords(text)
        guard !words.isEmpty else { return [] }
        let candidates = try archive.decisions(
            DecisionQuery(
                scope: stream.map { .stream($0.id) } ?? .project(project.id), statuses: [.active],
                kinds: [.decision, .action]))
        return
            candidates
            .map { ($0, Self.significantWords($0.decision.text + " " + ($0.decision.notes ?? ""))) }
            .filter { _, other in
                let shared = words.intersection(other).count
                return shared > 0 && Double(shared) / Double(min(words.count, max(other.count, 1))) >= 0.5
            }
            .prefix(3).map(\.0)
    }

    static func significantWords(_ text: String) -> Set<String> {
        let stop: Set<String> = [
            "della", "delle", "degli", "dello", "nella", "nelle", "nello", "sulla", "sulle", "dalla", "dalle",
            "alla", "alle", "allo", "sono", "come", "questa", "questo", "quella", "quello", "anche", "oppure",
            "perché", "perche", "dopo", "prima", "ancora", "sempre", "molto", "tutto", "tutti", "essere",
            "fare", "deciso", "decidere", "decisione",
        ]
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it"))
        return Set(
            folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter {
                $0.count >= 4 && !stop.contains($0)
            })
    }

    /// A rough guess of what a text is, to raise a doubt; never used to decide.
    static func looksLike(_ text: String) -> Decision.Kind? {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it"))
        let decided = [
            "abbiamo deciso", "ho deciso", "si e deciso", "decidiamo", "abbiamo scelto", "ho scelto",
            "approvato", "approvata", "concordato", "concordata", "confermato che", "stabilito",
        ]
        if decided.contains(where: folded.contains) { return .decision }
        let todo = ["da fare", "bisogna ", "dobbiamo ", "devo ", "ricordarsi", "entro il", "entro "]
        if todo.contains(where: folded.contains) { return .action }
        let firstWord = folded.split(separator: " ").first.map(String.init) ?? ""
        let verbs = ["chiamare", "inviare", "mandare", "preparare", "verificare", "capire", "decidere", "sentire"]
        return verbs.contains(firstWord) ? .action : nil
    }

    static func kindLabel(_ kind: Decision.Kind) -> String {
        switch kind {
        case .decision: "Decisione"
        case .action: "Attività"
        case .milestone: "Tappa"
        case .openQuestion: "Punto da chiarire"
        case .risk: "Rischio"
        case .request: "Richiesta"
        }
    }

    // MARK: Items

    func planDocument(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        let title = try requiredText(arguments, "title")
        let markdown = try requiredText(arguments, "markdown")
        let project = try writableTarget(scope, arguments)
        let stream = try stream(arguments, in: project)
        let related = try (arguments["related_item_ids"]?.strings ?? []).map { try visibleItem(scope, $0) }
        let date = try when(arguments, source: nil, projectID: project.id)
        var summary = [
            "Documento: «\(title)» (\(markdown.count) caratteri)",
            "Progetto: \(project.name)" + (stream.map { " · stream \($0.name)" } ?? ""),
            date.line,
        ]
        if !related.isEmpty {
            summary.append("Collegato a: " + related.map { "«\($0.title)»" }.joined(separator: ", "))
        }
        let doubts = [date.doubt, try streamDoubt(project, chosen: stream)].compactMap { $0 }
        return WritePlan(summary: summary, doubts: doubts) { writer, returned in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
                "iago-mcp-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let file = folder.appendingPathComponent("documento.md")
            let content = markdown.hasPrefix("# ") ? markdown : "# \(title)\n\n\(markdown)"
            try Data(content.utf8).write(to: file)
            let item = try writer.importDocument(
                file, isImage: false, markdown: content, title: title, occurredAt: date.date ?? clock())
            try writer.updateItem(item.id) {
                $0.projectId = project.id
                $0.source = .mcp
            }
            if let stream { try writer.setStreams([stream.id], itemID: item.id) }
            for other in related { try writer.addLink(from: item.id, to: other.id, kind: .related, origin: .mcp) }
            try writer.recordMCPChange(.item, id: item.id, action: .create)
            returned.append(item.id)
            return "Documento «\(title)» creato in «\(project.name)» (item_id `\(item.id)`). \(date.line) "
                + Self.writeNotice
        }
    }

    func planEmail(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        let subject = try requiredText(arguments, "subject")
        let body = try requiredText(arguments, "body")
        let project = try writableTarget(scope, arguments)
        let stream = try stream(arguments, in: project)
        let direction: EmailMeta.Direction? =
            switch arguments["direction"]?.string {
            case "inbound": .inbound
            case "outbound": .outbound
            default: nil
            }
        let sentAt = try moment(arguments)
        let from = arguments["from"]?.string.flatMap(Self.address)
        let to = (arguments["to"]?.strings ?? []).compactMap(Self.address)
        var summary = [
            "Email: «\(subject)»"
                + (direction == .outbound ? " (inviata)" : direction == .inbound ? " (ricevuta)" : ""),
            "Progetto: \(project.name)" + (stream.map { " · stream \($0.name)" } ?? ""),
        ]
        if let from { summary.append("Da: \(from.name ?? from.address)") }
        if !to.isEmpty { summary.append("A: " + to.map { $0.name ?? $0.address }.joined(separator: ", ")) }
        var doubts = [try streamDoubt(project, chosen: stream)].compactMap { $0 }
        if let sentAt {
            summary.append("Data dell'email: \(minute(sentAt)). " + (try place(sentAt, project.id)))
        } else {
            summary.append("Data: adesso, \(minute(clock())). In cima alla timeline del progetto.")
            doubts.append("Manca la data dell'email: chiedi all'utente quando è stata inviata o ricevuta.")
        }
        if direction == nil { doubts.append("Non è indicato se l'email è inviata o ricevuta: chiedilo all'utente.") }
        let attachments = try (arguments["attachment_paths"]?.strings ?? []).map(localFile)
        if !attachments.isEmpty {
            summary.append("Allegati: " + attachments.map { "«\($0.lastPathComponent)»" }.joined(separator: ", "))
        }
        return WritePlan(summary: summary, doubts: doubts) { writer, returned in
            let item = try writer.importEmail(
                EmailInput(
                    from: from, to: to, subject: subject, sentAt: sentAt ?? clock(), bodyMarkdown: body,
                    direction: direction),
                original: nil)
            try writer.updateItem(item.id) {
                $0.projectId = project.id
                $0.source = .mcp
            }
            if let stream { try writer.setStreams([stream.id], itemID: item.id) }
            try writer.recordMCPChange(.item, id: item.id, action: .create)
            returned.append(item.id)
            for file in attachments {
                let document = try Self.importLocalFile(
                    file, title: file.deletingPathExtension().lastPathComponent, occurredAt: item.occurredAt,
                    projectID: project.id, writer: writer)
                if let stream { try writer.setStreams([stream.id], itemID: document.id) }
                try writer.addLink(from: document.id, to: item.id, kind: .attachmentOf, origin: .mcp)
                try writer.recordMCPChange(.item, id: document.id, action: .create)
                returned.append(document.id)
            }
            return "Email «\(subject)» inserita in «\(project.name)» (item_id `\(item.id)`)"
                + (attachments.isEmpty ? ". " : ", con \(attachments.count) allegati collegati. ") + Self.writeNotice
        }
    }

    /// Files Claude may import (ADR-0047, amended 2026-10-20): regular files in the user's home folder, up to 200 MB.
    static let fileLimit = 200 << 20

    func localFile(_ path: String) throws -> URL {
        let expanded = (path.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL.resolvingSymlinksInPath()
        let home = filesRoot.standardizedFileURL.resolvingSymlinksInPath().path
        guard url.path.hasPrefix(home + "/") else {
            throw ToolError("Posso importare solo file nella cartella dell'utente (\(home)).")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw ToolError("File non trovato: \(url.path). Chiedi all'utente il percorso esatto.")
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.fileLimit else { throw ToolError("Il file è troppo grande (oltre 200 MB).") }
        return url
    }

    /// Imports one local file as a document of the project: original kept, text extracted (OCR when needed).
    static func importLocalFile(_ url: URL, title: String, occurredAt: Date, projectID: String, writer: Archive)
        throws -> Item
    {
        let isImage = UTType(filenameExtension: url.pathExtension.lowercased())?.conforms(to: .image) ?? false
        let markdown = ContentExtractor.canExtract(url) ? ((try? ContentExtractor.extract(url).markdown) ?? "") : ""
        let item = try writer.importDocument(
            url, isImage: isImage, markdown: markdown, title: title, occurredAt: occurredAt)
        try writer.updateItem(item.id) {
            $0.projectId = projectID
            $0.source = .mcp
        }
        return item
    }

    enum FileKind { case email, document, appOnly }

    /// The same files the app imports: emails and documents here; audio, video and Teams transcripts through the
    /// app, which converts and transcribes them.
    static func kind(of url: URL) -> FileKind {
        let ext = url.pathExtension.lowercased()
        if ["eml", "emlx"].contains(ext) { return .email }
        if ["vtt"].contains(ext) || (ext == "docx" && (try? TeamsTranscript.parse(url, itemID: "")) != nil) {
            return .appOnly
        }
        if let type = UTType(filenameExtension: ext),
            type.conforms(to: .audio) || type.conforms(to: .movie) || type.conforms(to: .audiovisualContent)
        {
            return .appOnly
        }
        return .document
    }

    func planFile(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        let url = try localFile(try requiredText(arguments, "path"))
        let project = try writableTarget(scope, arguments)
        let stream = try stream(arguments, in: project)
        let related = try (arguments["related_item_ids"]?.strings ?? []).map { try visibleItem(scope, $0) }
        let title =
            arguments["title"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? url.deletingPathExtension().lastPathComponent
        let date = try when(arguments, source: nil, projectID: project.id)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let kind = Self.kind(of: url)
        let sizeText = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        var summary = ["Progetto: \(project.name)" + (stream.map { " · stream \($0.name)" } ?? "")]
        switch kind {
        case .email:
            summary.insert(
                "Email: «\(url.lastPathComponent)» (\(sizeText)): mittente, destinatari, data e allegati dal file.",
                at: 0)
        case .appOnly:
            guard inbox != nil else { throw ToolError("Questo tipo di file lo può importare solo l'app IAGO.") }
            summary.insert(
                "File: «\(url.lastPathComponent)» (\(sizeText)). Audio, video e trascrizioni li importa l'app IAGO, come quando li trascini: li converte e li trascrive. IAGO deve essere aperto.",
                at: 0)
        case .document:
            summary.insert("File: «\(url.lastPathComponent)» (\(sizeText)), come documento «\(title)»", at: 0)
            summary.append(
                ContentExtractor.canExtract(url)
                    ? "IAGO conserva l'originale cifrato ed estrae il testo (OCR se serve)."
                    : "IAGO conserva l'originale cifrato; da questo tipo di file non estrae testo.")
            summary.append(date.line)
        }
        if !related.isEmpty {
            summary.append("Collegato a: " + related.map { "«\($0.title)»" }.joined(separator: ", "))
        }
        let doubts = [kind == .document ? date.doubt : nil, try streamDoubt(project, chosen: stream)].compactMap { $0 }
        let inbox = self.inbox
        return WritePlan(summary: summary, doubts: doubts) { writer, returned in
            switch kind {
            case .email:
                let message = try EmailParser.parse(Data(contentsOf: url))
                let item = try writer.importEmail(
                    EmailInput(
                        from: message.from.map { EmailMeta.Address(name: $0.name, address: $0.address) },
                        to: message.to.map { EmailMeta.Address(name: $0.name, address: $0.address) },
                        cc: message.cc.map { EmailMeta.Address(name: $0.name, address: $0.address) },
                        subject: message.subject, sentAt: message.date, messageID: message.messageID,
                        inReplyTo: message.inReplyTo, references: message.references,
                        bodyMarkdown: message.bodyMarkdown, direction: nil),
                    original: try Data(contentsOf: url))
                try writer.updateItem(item.id) {
                    $0.projectId = project.id
                    $0.source = .mcp
                }
                if let stream { try writer.setStreams([stream.id], itemID: item.id) }
                for other in related { try writer.addLink(from: item.id, to: other.id, kind: .related, origin: .mcp) }
                try writer.recordMCPChange(.item, id: item.id, action: .create)
                returned.append(item.id)
                return
                    "Email «\(message.subject ?? url.lastPathComponent)» importata in «\(project.name)» (item_id `\(item.id)`). "
                    + Self.writeNotice
            case .appOnly:
                guard let inbox else { throw ToolError("Questo tipo di file lo può importare solo l'app IAGO.") }
                try MCPInbox.hand(
                    url,
                    request: .init(
                        projectID: project.id, streamID: stream?.id, title: arguments["title"]?.string,
                        relatedItemIDs: related.map(\.id)),
                    to: inbox)
                return
                    "File «\(url.lastPathComponent)» passato a IAGO: lo importa e lo trascrive in «\(project.name)» appena è aperto, e compare come inserito tramite Claude (MCP)."
            case .document:
                let item = try Self.importLocalFile(
                    url, title: title, occurredAt: date.date ?? clock(), projectID: project.id, writer: writer)
                if let stream { try writer.setStreams([stream.id], itemID: item.id) }
                for other in related { try writer.addLink(from: item.id, to: other.id, kind: .related, origin: .mcp) }
                try writer.recordMCPChange(.item, id: item.id, action: .create)
                returned.append(item.id)
                return
                    "File «\(url.lastPathComponent)» importato in «\(project.name)» come documento (item_id `\(item.id)`). \(date.line) "
                    + Self.writeNotice
            }
        }
    }

    /// "Nome Cognome <nome@dominio.it>" or a bare address.
    static func address(_ text: String) -> EmailMeta.Address? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let open = trimmed.lastIndex(of: "<"), let close = trimmed.lastIndex(of: ">"), open < close {
            let name = trimmed[..<open].trimmingCharacters(in: CharacterSet(charactersIn: " \""))
            return EmailMeta.Address(
                name: name.isEmpty ? nil : name, address: String(trimmed[trimmed.index(after: open)..<close]))
        }
        return trimmed.contains("@")
            ? EmailMeta.Address(name: nil, address: trimmed) : EmailMeta.Address(name: trimmed, address: "")
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
