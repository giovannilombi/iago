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
                    presa usa add_decision; se è qualcosa da fare, add_decision con kind action; una domanda \
                    che aspetta risposta, un rischio o una richiesta del cliente sono anch'essi punti chiave \
                    (kind open_question, risk, request).
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
                    Registra un punto chiave. Memoria: una decisione presa dall'utente o dal suo gruppo, una tappa \
                    (fatto avvenuto). Lavoro aperto: un'attività (da fare, anche con checklist), un punto da \
                    chiarire, un rischio (con severity), una richiesta del cliente; con responsabile (owner), \
                    scadenza (due), "in attesa di" (waiting_on, waiting_until) solo se l'utente li dice. Titolo \
                    breve in `text`, dettagli in `description`. Prima cerca con list_decisions (query) i punti \
                    chiave sullo stesso tema: se questo ne cambia o ne chiude uno o più, di qualsiasi tipo, indicali \
                    in supersedes_ids (una decisione che risponde a un punto da chiarire lo chiude come Chiarito, \
                    una che accoglie una richiesta come Accolta). Se nasce da un'altra voce senza chiuderla (per \
                    esempio un'attività nata da una richiesta) usa derived_from_id. Collegala alla fonte: \
                    source_item_id (call con at_sec, email, documento) o source_note_id.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": .object(
                        ([
                            "text": ["type": "string", "description": "Cosa è stato deciso, in breve."],
                            "kind": [
                                "type": "string",
                                "enum": ["decision", "action", "milestone", "open_question", "risk", "request"],
                                "description": """
                                decision (default), action (attività: da fare), milestone (tappa: fatto importante \
                                avvenuto), open_question (punto da chiarire), risk (rischio), request (richiesta del \
                                cliente). activity vale come action.
                                """,
                            ],
                            "status": [
                                "type": "string", "enum": ["active", "in_progress", "waiting", "blocked"],
                                "description":
                                    "Facoltativo, solo per il lavoro: active (da fare, default), in_progress, waiting, blocked.",
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
                            "supersedes_id": [
                                "type": "string", "description": "Come supersedes_ids, per una sola voce.",
                            ],
                            "people": ["type": "array", "items": ["type": "string"]],
                            "tags": ["type": "array", "items": ["type": "string"]],
                            "confirmation": confirmation,
                        ] as [String: JSON]).merging(Self.workProperties(closing: false)) { $1 }),
                    "required": ["text"],
                ], title: "Registra punto chiave"),
            ToolDefinition(
                name: "update_decision",
                description: """
                    Modifica un punto chiave: titolo, descrizione, tipo, stato, stream, nome della catena o le voci \
                    che supera (supersedes_ids: l'elenco completo, che sostituisce quello attuale; elenco vuoto per \
                    nessuna). Per il lavoro aperto anche responsabile, scadenza, in attesa di, priorità, gravità, \
                    esito (outcome_kind con outcome: la risposta a un punto da chiarire, il motivo di un rifiuto; \
                    chiude la voce), dipendenze (blocked_by_ids, elenco completo), "nata da", ricorrenza e \
                    checklist (elenco completo). Stringa vuota per togliere un campo. Per registrare che una \
                    decisione è cambiata usa add_decision con supersedes_ids.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": .object(
                        ([
                            "decision_id": ["type": "string"], "text": ["type": "string"],
                            "description": ["type": "string"],
                            "kind": [
                                "type": "string",
                                "enum": ["decision", "action", "milestone", "open_question", "risk", "request"],
                                "description": "Facoltativo: cambia il tipo (per esempio una richiesta trasformata).",
                            ],
                            "status": [
                                "type": "string",
                                "enum": ["active", "in_progress", "waiting", "blocked", "done", "cancelled"],
                                "description":
                                    "active o cancelled per tutti; in_progress, waiting, blocked e done solo per il lavoro aperto.",
                            ],
                            "stream": [
                                "type": "string", "description": "Nome dello stream; stringa vuota per toglierlo.",
                            ],
                            "supersedes_ids": [
                                "type": "array", "items": ["type": "string"],
                                "description": "Elenco completo delle voci che supera; vuoto per nessuna.",
                            ],
                            "supersedes_id": [
                                "type": "string", "description": "Una sola voce; stringa vuota per nessuna.",
                            ],
                            "chain_name": ["type": "string", "description": "Stringa vuota per toglierlo."],
                            "confirmation": confirmation,
                        ] as [String: JSON]).merging(Self.workProperties(closing: true)) { $1 }),
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
        let kind = try kindArgument(arguments) ?? .decision
        let status: Decision.Status =
            switch arguments["status"]?.string {
            case nil, "", "active": .active
            case "in_progress" where kind.isWork: .inProgress
            case "waiting" where kind.isWork: .waiting
            case "blocked" where kind.isWork: .blocked
            default:
                throw ToolError(
                    "Stato non valido per una voce nuova: active, oppure in_progress, waiting o blocked per il lavoro aperto."
                )
            }
        for key in ["outcome", "outcome_kind"] where arguments[key] != nil {
            throw ToolError("\(key) chiude una voce: si indica dopo, con update_decision.")
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
        let work = try workInput(arguments, kind: kind, project: project, current: nil)

        var summary = [
            "\(Self.kindLabel(kind)): «\(oneLine(text, limit: 120))»",
            "Progetto: \(project.name)" + (stream.map { " · stream \($0.name)" } ?? ""),
            date.line,
        ]
        if status != .active {
            var shown = Decision(text: text, decidedAt: clock(), origin: .mcp, kind: kind)
            shown.status = status
            summary.append("Stato: \(KeyPointLabels.status(shown))")
        }
        summary += work.lines
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
        var doubts = [date.doubt, try streamDoubt(project, chosen: stream)].compactMap { $0 } + work.doubts
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
            doubts.append("Il titolo sembra qualcosa da fare: chiedi all'utente se è un'attività (kind action).")
        }
        return WritePlan(summary: summary, doubts: doubts) { writer, returned in
            var draft = Decision(
                text: text, decidedAt: date.date ?? clock(), projectId: project.id, sourceItemId: sourceItem?.id,
                sourceAtSec: atSec, sourceNoteId: sourceNote?.id, origin: .mcp,
                notes: description?.isEmpty == false ? description : nil, kind: kind)
            draft.status = status
            try work.apply(to: &draft, people: try work.resolvedPeople(writer))
            let decision = try writer.createDecision(
                draft, people: people, tags: tags, streams: stream.map { [$0.id] } ?? [],
                supersedes: targets.map(\.id))
            try work.applyLinks(to: decision.id, writer)
            try writer.recordMCPChange(.decision, id: decision.id, action: .create)
            returned.append(decision.id)
            return
                "\(Self.kindLabel(kind)) \(Self.registered(kind)) in «\(project.name)» (decision_id `\(decision.id)`)"
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
        let newKind = try kindArgument(arguments)
        let kind = newKind ?? current.kind
        var status: Decision.Status? =
            switch arguments["status"]?.string {
            case "active": .active
            case "cancelled": .cancelled
            case "done" where kind.isWork: .done
            case "in_progress" where kind.isWork: .inProgress
            case "waiting" where kind.isWork: .waiting
            case "blocked" where kind.isWork: .blocked
            case nil: nil
            default:
                throw ToolError(
                    "Stato non valido: usa active o cancelled; done, in_progress, waiting e blocked solo per attività, punti da chiarire, rischi e richieste."
                )
            }
        let work = try workInput(arguments, kind: kind, project: project, current: summary)
        // An outcome closes the entry; a memory kind has no work states.
        if status == nil, case .some(.some) = work.outcomeKind, current.status.isOpen { status = .done }
        if status == nil, !kind.isWork, current.status != .active, current.status.isOpen || current.status == .done {
            status = .active
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
                || newTargets != nil || newKind != nil || !work.isEmpty
        else {
            throw ToolError(
                "Niente da modificare: indica text, description, kind, status, stream, supersedes_ids, chain_name o un campo del lavoro aperto."
            )
        }
        var lines = ["\(Self.kindLabel(current.kind)) «\(oneLine(current.text, limit: 80))» in «\(project.name)»"]
        if let text, !text.isEmpty { lines.append("Titolo: «\(oneLine(text, limit: 120))»") }
        if description != nil { lines.append("Descrizione nuova") }
        if let newKind, newKind != current.kind { lines.append("Diventa: \(Self.kindLabel(newKind))") }
        if let status {
            var after = current
            after.kind = kind
            after.status = status
            if let outcome = work.outcomeKind { after.outcomeKind = outcome }
            lines.append("Stato: \(status.rawValue) (\(KeyPointLabels.status(after)))")
        }
        lines += work.lines
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
        doubts += work.doubts
        lines.append("La data e la posizione in timeline non cambiano.")
        let (newIDs2, reorders2, streams2, status2) = (newTargets?.map(\.id), reorders, streams, status)
        return WritePlan(summary: lines, doubts: doubts) { writer, returned in
            let (newIDs, reorders, streams, status) = (newIDs2, reorders2, streams2, status2)
            let touched = [current.id] + (newIDs ?? []) + summary.supersedesAll.map(\.id)
            let changesWork = newKind != nil || work.changesRecord
            try writer.recordMCPChange(
                .decision, id: id, action: .update,
                previous: MCPPrevious(
                    text: current.text, notes: current.notes, status: current.status,
                    chainName: try archive.chainName(of: id), streamIDs: summary.streamIDs,
                    chain: newIDs == nil ? nil : try archive.decisionLinks(ofChainsOf: touched),
                    work: changesWork ? MCPPrevious.Work(current) : nil,
                    blockerIDs: work.blockers == nil ? nil : summary.blockers.map(\.id),
                    checklist: work.checklist == nil
                        ? nil
                        : try archive.checklistItems(decisionID: id).map { .init(text: $0.text, done: $0.done) }))
            let people = try work.resolvedPeople(writer)
            try writer.updateDecision(id, streams: streams, supersedes: newIDs, reorderingChain: reorders) {
                decision in
                if let text, !text.isEmpty { decision.text = text }
                if let description {
                    let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    decision.notes = trimmed.isEmpty ? nil : trimmed
                }
                if let newKind { decision.kind = newKind }
                if let status { decision.status = status }
                try work.apply(to: &decision, people: people)
            }
            try work.applyLinks(to: id, writer)
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

    static func kindLabel(_ kind: Decision.Kind) -> String { KeyPointLabels.kind(kind) }

    /// "registrata", or "registrato" for the masculine kinds (punto da chiarire, rischio).
    static func registered(_ kind: Decision.Kind) -> String {
        kind == .openQuestion || kind == .risk ? "registrato" : "registrata"
    }

    // MARK: Open work (ADR-0074)

    /// The open work arguments of add_decision and update_decision. `closing`: also the outcome (update only).
    static func workProperties(closing: Bool) -> [String: JSON] {
        let day = "Data AAAA-MM-GG; stringa vuota per toglierla."
        var properties: [String: JSON] = [
            "owner": [
                "type": "string",
                "description":
                    "Responsabile: nome di una persona (già nota a IAGO o nuova); stringa vuota per toglierlo.",
            ],
            "due": ["type": "string", "description": .string("Scadenza. " + day)],
            "waiting_on": ["type": "string", "description": "In attesa di: nome della persona."],
            "waiting_until": ["type": "string", "description": .string("In attesa fino a quando. " + day)],
            "priority": ["type": "string", "enum": ["high", "medium", "low", ""]],
            "starts_at": ["type": "string", "description": .string("Data d'inizio, solo da riportare. " + day)],
            "estimate": ["type": "string", "description": "Stima, solo da riportare (es. \"3 giorni\")."],
            "severity": [
                "type": "string", "enum": ["high", "medium", "low", ""], "description": "Gravità di un rischio.",
            ],
            "happened_at": [
                "type": "string", "description": .string("Rischio diventato problema, in che data. " + day),
            ],
            "recurrence": ["type": "string", "enum": ["daily", "weekly", "monthly", "yearly", ""]],
            "derived_from_id": [
                "type": "string",
                "description":
                    "Facoltativo: decision_id della voce da cui nasce (\"nata da\"), senza chiuderla. Stringa vuota per toglierlo.",
            ],
            "blocked_by_ids": [
                "type": "array", "items": ["type": "string"],
                "description":
                    "decision_id delle voci da cui dipende: finché una è aperta, questa è Bloccata. Elenco completo; vuoto per nessuna.",
            ],
            "checklist": [
                "type": "array", "items": ["type": "string"],
                "description":
                    "Sotto-voci da spuntare, nell'ordine; \"[x] testo\" per una già fatta. Elenco completo; vuoto per nessuna.",
            ],
        ]
        if closing {
            properties["outcome_kind"] = [
                "type": "string",
                "enum": ["answered", "accepted", "rejected", "converted", "resolved", "irrelevant", ""],
                "description": """
                Esito, chiude la voce: answered (punto da chiarire), accepted, rejected o converted (richiesta), \
                resolved o irrelevant (rischio).
                """,
            ]
            properties["outcome"] = [
                "type": "string", "description": "La risposta, il motivo del rifiuto, com'è finita.",
            ]
        }
        return properties
    }

    func kindArgument(_ arguments: JSON) throws -> Decision.Kind? {
        guard let value = arguments["kind"]?.string, !value.isEmpty else { return nil }
        guard let kind = Self.decisionKind(value) else {
            throw ToolError(
                "Tipo «\(value)» non valido: decision, action, milestone, open_question, risk o request.")
        }
        return kind
    }

    /// The open work fields given to add_decision or update_decision, checked before anything is written. For each
    /// field nil means "not given", `.some(nil)` (an empty string) "remove it".
    struct WorkInput: Sendable {
        var owner: String??
        var waitingOn: String??
        var due: Date??
        var waitingUntil: Date??
        var priority: Int??
        var startsAt: Date??
        var estimate: String??
        var severity: Decision.Severity??
        var happenedAt: Date??
        var outcome: String??
        var outcomeKind: Decision.Outcome??
        var recurrence: Decision.Recurrence??
        var derivedFromID: String??
        var checklist: [MCPPrevious.ChecklistLine]?
        var blockers: [String]?
        /// For the preview.
        var lines: [String] = []
        var doubts: [String] = []

        /// Something stored on the entry itself (not its checklist or dependencies).
        var changesRecord: Bool {
            owner != nil || waitingOn != nil || due != nil || waitingUntil != nil || priority != nil
                || startsAt != nil || estimate != nil || severity != nil || happenedAt != nil || outcome != nil
                || outcomeKind != nil || recurrence != nil || derivedFromID != nil
        }
        var isEmpty: Bool { !changesRecord && checklist == nil && blockers == nil }

        /// Owner and waiting-for as person ids, created if new ("persone già note + nuove al volo").
        struct People: Sendable {
            var owner: String??
            var waitingOn: String??
        }

        func resolvedPeople(_ writer: Archive) throws -> People {
            func resolve(_ name: String??) throws -> String?? {
                guard let name else { return nil }
                guard let name else { return .some(nil) }
                return .some(try writer.person(named: name)?.id)
            }
            return People(owner: try resolve(owner), waitingOn: try resolve(waitingOn))
        }

        func apply(to decision: inout Decision, people: People) throws {
            if let owner = people.owner { decision.ownerId = owner }
            if let waitingOn = people.waitingOn { decision.waitingOnId = waitingOn }
            if let due { decision.dueAt = due }
            if let waitingUntil { decision.waitingUntil = waitingUntil }
            if let priority { decision.priority = priority }
            if let startsAt { decision.startsAt = startsAt }
            if let estimate { decision.estimate = estimate }
            if let severity { decision.severity = severity }
            if let happenedAt { decision.happenedAt = happenedAt }
            if let outcome { decision.outcome = outcome }
            if let outcomeKind { decision.outcomeKind = outcomeKind }
            if let recurrence { decision.recurrence = recurrence }
            if let derivedFromID { decision.derivedFromId = derivedFromID }
        }

        /// Checklist and dependencies, once the entry exists.
        func applyLinks(to id: String, _ writer: Archive) throws {
            if let checklist { try writer.replaceChecklist(checklist, decisionID: id) }
            if let blockers {
                do {
                    try writer.setBlockers(blockers, of: id)
                } catch WorkError.dependencyCycle {
                    throw ToolError("Dipendenza circolare: una delle voci in blocked_by_ids dipende già da questa.")
                }
            }
        }
    }

    /// Reads and checks the open work arguments. `current`: the entry being changed (nil for a new one).
    func workInput(_ arguments: JSON, kind: Decision.Kind, project: Project, current: DecisionSummary?) throws
        -> WorkInput
    {
        var input = WorkInput()
        func text(_ key: String) -> String?? {
            guard let value = arguments[key] else { return nil }
            let trimmed: String
            switch value {
            case .string(let string): trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            case .number(let number): trimmed = number.formatted()
            case .null: trimmed = ""
            default: return nil
            }
            return .some(trimmed.isEmpty ? nil : trimmed)
        }
        func day(_ key: String) throws -> Date?? {
            guard let given = text(key) else { return nil }
            guard let given else { return .some(nil) }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let parts = given.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3,
                let date = calendar.date(
                    from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
            else { throw ToolError("\(key): data «\(given)» non valida, usa AAAA-MM-GG.") }
            return .some(date)
        }
        func choice<T>(_ key: String, _ make: (String) -> T?) throws -> T?? {
            guard let given = text(key) else { return nil }
            guard let given else { return .some(nil) }
            guard let value = make(given) else { throw ToolError("\(key): valore «\(given)» non valido.") }
            return .some(value)
        }
        func shown(_ date: Date) -> String { TranscriptRenderer.format(date, "yyyy-MM-dd", timeZone) }
        func entry(_ id: String, _ key: String) throws -> DecisionSummary {
            guard let found = try archive.decisionSummary(id), found.decision.projectId == project.id else {
                throw ToolError("\(key): il punto chiave \(id) non è in «\(project.name)».")
            }
            guard found.id != current?.id else { throw ToolError("\(key): una voce non può riferirsi a sé stessa.") }
            return found
        }
        func person(_ key: String, _ label: String) throws -> String?? {
            guard let name = text(key) else { return nil }
            guard let name else {
                input.lines.append("\(label): tolto")
                return .some(nil)
            }
            if let known = try knownPerson(name) {
                input.lines.append("\(label): \(known.name)")
                return .some(known.name)
            }
            input.lines.append("\(label): \(name) (persona nuova in IAGO)")
            let similar = try archive.similarPeople(to: name).map(\.name)
            if !similar.isEmpty {
                input.doubts.append(
                    "«\(name)» non è tra le persone di IAGO: chiedi all'utente se intende "
                        + similar.map { "«\($0)»" }.joined(separator: " o ") + " (usa il nome esatto).")
            }
            return .some(name)
        }

        // Fields of open work only; on a decision or milestone they can only be removed.
        let workOnly = [
            "owner", "due", "waiting_on", "waiting_until", "priority", "starts_at", "estimate", "severity",
            "happened_at", "outcome", "outcome_kind", "recurrence", "checklist", "blocked_by_ids",
        ]
        if !kind.isWork {
            for key in workOnly {
                let given: Bool =
                    switch arguments[key] {
                    case .array(let values)?: !values.isEmpty
                    case .some: text(key).flatMap { $0 } != nil
                    case nil: false
                    }
                if given {
                    throw ToolError(
                        "\(key) vale solo per il lavoro aperto (attività, punti da chiarire, rischi e richieste), non per \(Self.kindLabel(kind).lowercased())."
                    )
                }
            }
        }

        input.owner = try person("owner", "Responsabile")
        input.waitingOn = try person("waiting_on", "In attesa di")
        input.due = try day("due")
        input.waitingUntil = try day("waiting_until")
        input.startsAt = try day("starts_at")
        input.happenedAt = try day("happened_at")
        input.estimate = text("estimate")
        input.outcome = text("outcome")
        input.priority = try choice("priority") { ["high": 1, "medium": 2, "low": 3, "1": 1, "2": 2, "3": 3][$0] }
        input.severity = try choice("severity", Decision.Severity.init(rawValue:))
        input.recurrence = try choice("recurrence", Decision.Recurrence.init(rawValue:))
        input.outcomeKind = try choice("outcome_kind", Decision.Outcome.init(rawValue:))

        if case .some(.some) = input.severity, kind != .risk { throw ToolError("severity vale solo per i rischi.") }
        if case .some(.some) = input.happenedAt, kind != .risk {
            throw ToolError("happened_at vale solo per i rischi.")
        }
        if case .some(.some(let outcome)) = input.outcomeKind {
            let fits: Decision.Kind? =
                switch outcome {
                case .answered: .openQuestion
                case .accepted, .rejected, .converted: .request
                case .resolved, .irrelevant: .risk
                }
            guard fits == kind else {
                throw ToolError(
                    "outcome_kind \(outcome.rawValue) non vale per \(Self.kindLabel(kind).lowercased()): answered per i punti da chiarire; accepted, rejected o converted per le richieste; resolved o irrelevant per i rischi."
                )
            }
        }

        func line<T>(_ value: T??, _ label: String, _ show: (T) -> String) {
            guard let value else { return }
            input.lines.append(value.map { "\(label): \(show($0))" } ?? "\(label): tolta")
        }
        line(input.due, "Scadenza", shown)
        line(input.waitingUntil, "In attesa fino al", shown)
        line(input.priority, "Priorità", KeyPointLabels.priority)
        line(input.startsAt, "Inizio", shown)
        line(input.estimate, "Stima", { $0 })
        line(input.severity, "Gravità", KeyPointLabels.severity)
        line(input.happenedAt, "Diventato problema il", shown)
        line(input.recurrence, "Ricorrenza", KeyPointLabels.recurrence)
        line(input.outcomeKind, "Esito", KeyPointLabels.outcome)
        line(input.outcome, "Risposta o motivo", { "«\(oneLine($0, limit: 120))»" })
        if case .some(.some(let recurrence)) = input.recurrence, input.due == nil, current?.decision.dueAt == nil {
            input.doubts.append(
                "Ricorrenza \(KeyPointLabels.recurrence(recurrence)) senza scadenza: chiedi all'utente da quando.")
        }

        if let id = text("derived_from_id") {
            if let id {
                let origin = try entry(id, "derived_from_id")
                input.lines.append(
                    "Nata da: \(Self.kindLabel(origin.decision.kind).lowercased()) «\(oneLine(origin.decision.text, limit: 80))», che resta com'è"
                )
                input.derivedFromID = .some(id)
            } else {
                input.lines.append("Nata da: tolto")
                input.derivedFromID = .some(nil)
            }
        }

        if let ids = arguments["blocked_by_ids"]?.strings {
            var seen: Set<String> = []
            let blockers = try ids.filter { seen.insert($0).inserted }.map { try entry($0, "blocked_by_ids") }
            for blocker in blockers where !blocker.decision.kind.isWork {
                throw ToolError(
                    "blocked_by_ids: «\(oneLine(blocker.decision.text, limit: 60))» è una decisione o una tappa: si dipende solo da lavoro aperto."
                )
            }
            if let current {
                for blocker in blockers where try dependsOn(blocker.id, current.id) {
                    throw ToolError(
                        "Dipendenza circolare: «\(oneLine(blocker.decision.text, limit: 60))» dipende già da questa voce."
                    )
                }
            }
            input.blockers = blockers.map(\.id)
            if blockers.isEmpty {
                input.lines.append("Non dipende più da nessuna voce")
            } else {
                input.lines.append(
                    "Dipende da: "
                        + blockers.map { "«\(oneLine($0.decision.text, limit: 60))»" }.joined(separator: ", ")
                        + (blockers.contains { $0.decision.status.isOpen }
                            ? " (finché una è aperta la voce risulta Bloccata)" : ""))
            }
        }

        if let given = arguments["checklist"]?.strings {
            let existing = try current.map { try archive.checklistItems(decisionID: $0.id) } ?? []
            let checklist: [MCPPrevious.ChecklistLine] = given.compactMap { raw in
                var text = raw.trimmingCharacters(in: .whitespaces)
                var done: Bool?
                for (prefix, value) in [("[x]", true), ("[X]", true), ("☑", true), ("[ ]", false), ("☐", false)]
                where text.hasPrefix(prefix) {
                    text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    done = value
                    break
                }
                guard !text.isEmpty else { return nil }
                return .init(text: text, done: done ?? existing.first { $0.text == text }?.done ?? false)
            }
            input.checklist = checklist
            input.lines.append(
                checklist.isEmpty
                    ? "Checklist: vuota"
                    : "Checklist: " + checklist.map { ($0.done ? "☑ " : "☐ ") + $0.text }.joined(separator: "; "))
        }
        return input
    }

    /// True if `from` depends on `to`, directly or through other entries.
    func dependsOn(_ from: String, _ to: String) throws -> Bool {
        var stack = [from]
        var seen: Set<String> = []
        while let next = stack.popLast() {
            for blocker in try archive.blockers(of: next) {
                if blocker.id == to { return true }
                if seen.insert(blocker.id).inserted { stack.append(blocker.id) }
            }
        }
        return false
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
