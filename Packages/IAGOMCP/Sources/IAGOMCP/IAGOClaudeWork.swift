import Foundation
import IAGOCore
import IAGOExport
import IAGOIntelligence
import IAGOStore
import ImageIO
import UniformTypeIdentifiers

/// Claude does the work of the local engine when the user asks (ADR-0071): it finds the item (recent_items, or the
/// reference copied with «Copia per Claude»), reads it, and writes back a summary or proposals. A summary follows the
/// category's template and its quotes are checked by IAGO like the engine's; proposals wait for the user's OK.
extension IAGOTools {
    /// Archive setting: Claude may also see the images of the screenshots, not only their text (ADR-0072).
    public static let shareScreenshotsKey = Archive.shareScreenshotsWithClaudeKey
    /// Longest side of a screenshot sent to Claude: enough to read a slide, much less to send.
    static let screenshotPixels = 1_568
    static let screenshotsPerCall = 8

    static let workTitles = [
        "recent_items": "Elementi recenti", "summary_template": "Modello di sintesi",
        "get_screenshots": "Schermate", "set_summary": "Scrivi la sintesi", "propose_suggestions": "Proponi",
    ]

    // MARK: Definitions

    var workReadTools: [ToolDefinition] {
        [
            ToolDefinition(
                name: "recent_items",
                description: """
                    Gli ultimi elementi (call, email, documenti) di tutti i progetti consultabili, dal più recente: \
                    data, titolo, progetto, se ha trascrizione, sintesi, proposte in attesa, e item_id. Usalo quando \
                    l'utente parla di "la call di ieri" o "l'ultima riunione con …" senza dare un riferimento.
                    """,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "days": ["type": "integer", "description": "Quanti giorni indietro (default 14, max 120)."],
                        "types": [
                            "type": "array", "items": ["type": "string", "enum": ["call", "email", "document"]],
                            "description": "Facoltativo: solo questi tipi.",
                        ],
                        "query": ["type": "string", "description": "Facoltativo: parole che devono stare nel titolo."],
                        "limit": ["type": "integer", "description": "Massimo elementi (default 25, max 60)."],
                    ],
                ]),
            ToolDefinition(
                name: "summary_template",
                description: """
                    Il modello di sintesi della categoria di un elemento: sezioni con istruzioni e colonne, e il \
                    formato da usare in set_summary. Chiamalo prima di scrivere una sintesi.
                    """,
                inputSchema: [
                    "type": "object", "properties": ["item_id": ["type": "string"]], "required": ["item_id"],
                ]),
            ToolDefinition(
                name: "get_screenshots",
                description: """
                    Le immagini delle schermate catturate durante una call (slide, tabelle, grafici), ciascuna con \
                    il suo minuto e il testo letto da IAGO. Solo se l'utente ha scelto di condividerle con Claude; \
                    altrimenti c'è solo il loro testo, in get_item.
                    """,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "item_id": ["type": "string"],
                        "at": ["type": "string", "description": "Facoltativo: solo la schermata più vicina a mm:ss."],
                    ],
                    "required": ["item_id"],
                ]),
        ]
    }

    func workWriteTools(confirmation: JSON) -> [ToolDefinition] {
        let preview = " Funziona in due passi: anteprima, poi conferma con il codice dopo l'OK dell'utente."
        let point: JSON = [
            "type": "object",
            "properties": [
                "text": ["type": "string", "description": "Il punto, breve, in italiano."],
                "quote": [
                    "type": "string",
                    "description":
                        "La frase ESATTA del testo da cui viene, parola per parola, senza minuto né nome: IAGO la cerca e collega il punto al suo minuto.",
                ],
                "fields": [
                    "type": "object", "description": "Facoltativo: valori delle colonne della sezione (Chi, Entro…).",
                ],
                "screenshot_at": [
                    "type": "string",
                    "description": "Solo per un punto letto su una schermata: il suo minuto mm:ss (al posto di quote).",
                ],
            ],
            "required": ["text"],
        ]
        return [
            ToolDefinition(
                name: "set_summary",
                description: """
                    Scrive la sintesi di un elemento al posto del motore locale, nel modello della sua categoria \
                    (vedi summary_template). Ogni punto porta la citazione esatta del testo: IAGO la verifica e \
                    scarta i punti senza citazione o con una citazione che non trova, come fa con il suo motore. \
                    In IAGO la sintesi compare come «Sintetizzata da Claude» e si può annullare.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "item_id": ["type": "string"],
                        "brief": ["type": "string", "description": "«In breve»: 2-3 frasi sull'essenziale."],
                        "sections": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "title": ["type": "string", "description": "Titolo della sezione del modello."],
                                    "points": ["type": "array", "items": point],
                                ],
                                "required": ["title", "points"],
                            ],
                        ],
                        "confirmation": confirmation,
                    ],
                    "required": ["item_id", "sections"],
                ]),
            ToolDefinition(
                name: "propose_suggestions",
                description: """
                    Propone decisioni, attività e tag per un elemento, al posto delle proposte del motore locale. \
                    Restano proposte: l'utente le conferma o le scarta nella scheda dell'elemento, dove compaiono \
                    come «Consigliata da Claude». Ogni decisione e attività porta la citazione esatta del testo.
                    """ + preview,
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "item_id": ["type": "string"],
                        "items": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "kind": ["type": "string", "enum": ["decision", "activity", "tag"]],
                                    "text": ["type": "string"],
                                    "quote": [
                                        "type": "string",
                                        "description": "Frase esatta del testo (per decisioni e attività).",
                                    ],
                                    "owner": ["type": "string", "description": "Chi la fa (attività)."],
                                ],
                                "required": ["kind", "text"],
                            ],
                        ],
                        "confirmation": confirmation,
                    ],
                    "required": ["item_id", "items"],
                ]),
        ]
    }

    static let workGuide = """

        Sintesi e proposte fatte da Claude (quando l'utente le chiede a te invece che al motore del Mac):
        1. Trova l'elemento: se l'utente incolla un riferimento di IAGO usa il suo item_id; altrimenti recent_items \
        (o search) e, se c'è più di un candidato, chiedi quale.
        2. Sintesi: summary_template, poi get_item (e get_screenshots se ci sono schermate e l'utente le condivide), \
        poi set_summary con le sezioni del modello. Ogni punto ha la citazione esatta; i punti letti su una \
        schermata usano screenshot_at.
        3. Proposte: get_item, poi propose_suggestions con decisioni, attività e tag, ciascuna con la citazione.
        4. Come ogni scrittura: anteprima, OK dell'utente, conferma. Riferisci quanti punti IAGO ha tenuto e quali ha \
        scartato, e correggi le citazioni se serve.
        """

    // MARK: Read

    func recentItems(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String {
        let days = min(max(arguments["days"]?.int ?? 14, 1), 120)
        let limit = min(max(arguments["limit"]?.int ?? 25, 1), 60)
        let types = Set(arguments["types"]?.strings ?? [])
        let query = arguments["query"]?.string?.trimmingCharacters(in: .whitespaces) ?? ""
        let since = clock().addingTimeInterval(-Double(days) * 86_400)
        let summarized = try archive.summarizedItemIDs()
        let pending = try archive.pendingSuggestionCounts()
        let projects = Dictionary(uniqueKeysWithValues: scope.projects.map { ($0.id, $0) })
        let entries = try archive.summaries(.recent)
            .filter { summary in
                scope.visible(summary.item) && summary.item.occurredAt >= since
                    && (types.isEmpty || types.contains(summary.item.type.rawValue))
                    && (query.isEmpty || summary.item.title.localizedStandardContains(query))
            }
            .sorted { $0.item.occurredAt > $1.item.occurredAt }
            .prefix(limit)
        guard !entries.isEmpty else {
            return "Nessun elemento negli ultimi \(days) giorni tra i progetti consultabili."
                + (query.isEmpty ? "" : " Prova senza query o con più giorni.")
        }
        var lines = ["Elementi degli ultimi \(days) giorni, dal più recente:", ""]
        for summary in entries {
            let item = summary.item
            returned.append(item.id)
            var parts = [minute(item.occurredAt), "\(typeLabel(item.type)) «\(item.title)»"]
            if let project = item.projectId.flatMap({ projects[$0] }) {
                let client = project.clientId.flatMap { scope.clients[$0]?.name }
                parts.append("progetto \(project.name)" + (client.map { " (\($0))" } ?? ""))
            } else {
                parts.append(Target.unclassifiedName)
            }
            if let duration = item.durationSec { parts.append(TranscriptRenderer.minutes(duration)) }
            if item.type == .call { parts.append(summary.hasTranscript ? "trascritta" : "non ancora trascritta") }
            parts.append(summarized.contains(item.id) ? "ha la sintesi" : "senza sintesi")
            if let count = pending[item.id], count > 0 { parts.append("\(count) proposte in attesa") }
            parts.append("item_id `\(item.id)`")
            lines.append("- " + parts.joined(separator: " · "))
        }
        return lines.joined(separator: "\n")
    }

    func summaryTemplate(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> String {
        let item = try visibleItem(scope, arguments["item_id"]?.string)
        returned.append(item.id)
        let (template, category) = try template(for: item)
        var lines = [
            "Elemento: «\(item.title)» (\(minute(item.occurredAt)))",
            category.map { "Categoria: \($0.name) · modello «\(template.name)»" }
                ?? "Senza categoria: uso il modello generale «\(template.name)». L'utente può scegliere una categoria in IAGO.",
        ]
        if let existing = try archive.summary(itemID: item.id) {
            lines.append(
                "Ha già una sintesi"
                    + (existing.origin == .claude ? " scritta da Claude" : " del motore locale")
                    + (existing.edited ? ", modificata a mano dall'utente" : "")
                    + ": set_summary la sostituisce (si può annullare).")
        }
        lines += ["", "Sezioni (usa questi titoli in set_summary):"]
        for section in template.sections {
            var line = "- «\(section.title)»: \(section.instruction)"
            if !section.columns.isEmpty { line += " Colonne per fields: \(section.columns.joined(separator: ", "))." }
            lines.append(line)
        }
        lines += [
            "",
            "Formato: set_summary(item_id, brief, sections: [{title, points: [{text, quote, fields}]}]). Una sezione senza punti si omette: IAGO scrive «Non emerso».",
        ]
        return lines.joined(separator: "\n")
    }

    /// Text and images of the screenshots (ADR-0072): the images only when the user shares them with Claude.
    func screenshotsContent(_ scope: Scope, _ arguments: JSON, _ returned: inout [String]) throws -> [JSON] {
        let item = try visibleItem(scope, arguments["item_id"]?.string)
        returned.append(item.id)
        var shots = try archive.screenshots(itemID: item.id)
        guard !shots.isEmpty else { return [["type": "text", "text": "Questo elemento non ha schermate."]] }
        guard (try archive.setting(Self.shareScreenshotsKey)) == "1" else {
            throw ToolError(
                "L'utente non condivide con Claude le immagini delle schermate: il loro testo è in get_item. Può attivarle in IAGO › Impostazioni › Claude («Condividi anche le immagini delle schermate»)."
            )
        }
        if let at = arguments["at"]?.string.flatMap(Self.seconds) {
            shots = [shots.min { abs(($0.atSec ?? 0) - at) < abs(($1.atSec ?? 0) - at) }!]
        }
        var content: [JSON] = []
        for shot in shots.prefix(Self.screenshotsPerCall) {
            returned.append(shot.id)
            let at = TranscriptRenderer.clock(shot.atSec ?? 0)
            content.append([
                "type": "text", "text": .string("Schermata [\(at)]: \(shot.text ?? "(nessun testo letto)")"),
            ])
            if let jpeg = Self.jpeg(try archive.readAssetData(shot)) {
                content.append(["type": "image", "data": .string(jpeg.base64EncodedString()), "mimeType": "image/jpeg"])
            }
        }
        if shots.count > Self.screenshotsPerCall {
            content.append(
                [
                    "type": "text",
                    "text": .string(
                        "Altre \(shots.count - Self.screenshotsPerCall) schermate: chiedile una alla volta con at."),
                ])
        }
        return content
    }

    static func jpeg(_ png: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: screenshotPixels,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                ] as CFDictionary)
        else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(
            destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    /// "mm:ss", "h:mm:ss" or seconds.
    static func seconds(_ text: String) -> Double? {
        let parts = text.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
    }

    /// The category's template, the user's version first; the general one without a category.
    func template(for item: Item) throws -> (SummaryTemplate, IAGOStore.Category?) {
        let category = try item.categoryId.flatMap { try archive.category($0) }
        if let category {
            if let json = category.templateJson, var custom = SummaryTemplate.parse(json) {
                custom.id = category.templateId ?? ""
                return (custom, category)
            }
            if let template = SummaryLibrary.template(category.templateId) { return (template, category) }
        }
        return (SummaryLibrary.template("standard")!, category)
    }

    // MARK: Write

    func planSummary(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        let item = try visibleItem(scope, arguments["item_id"]?.string)
        let project = try writableProject(scope, item.projectId)
        guard let input = try SuggestionEngine.Input.load(item, from: archive), !input.lines.isEmpty else {
            throw ToolError("«\(item.title)» non ha ancora un testo da riassumere (la call non è trascritta?).")
        }
        let (template, _) = try template(for: item)
        // Generic labels ("Speaker 2") are not participants.
        let participants = Set(input.speakers.values)
            .filter { !$0.lowercased().hasPrefix("speaker") && !$0.contains(where: \.isNumber) }.sorted()
        var sections: [(title: String, points: [SummaryGenerator.ExternalPoint])] = []
        for section in arguments["sections"]?.array ?? [] {
            let points = (section["points"]?.array ?? []).compactMap { point -> SummaryGenerator.ExternalPoint? in
                guard let text = point["text"]?.string else { return nil }
                var fields: [String: String] = [:]
                if case .object(let object) = point["fields"] ?? .null {
                    for (key, value) in object { if let value = value.string { fields[key] = value } }
                }
                return .init(
                    text: text, quote: point["quote"]?.string, fields: fields,
                    screenshotAtSec: point["screenshot_at"]?.string.flatMap(Self.seconds))
            }
            sections.append((section["title"]?.string ?? "", points))
        }
        let result = SummaryGenerator.compose(
            .init(
                lines: input.lines, template: template, date: item.occurredAt, participants: participants,
                title: item.title),
            brief: arguments["brief"]?.string, sections: sections,
            screenshots: try archive.screenshots(itemID: item.id).compactMap(\.atSec))
        let kept = result.sections.reduce(0) { $0 + $1.points.count }
        guard kept > 0 else {
            throw ToolError(
                "Nessun punto verificato: "
                    + result.discarded.prefix(5).map { "«\($0.point)» (\($0.reason))" }.joined(separator: "; ")
                    + ". Usa i titoli delle sezioni di summary_template e riporta in quote le frasi esatte del testo.")
        }
        let existing = try archive.summary(itemID: item.id)
        var doubts = result.discarded.map { "Scartato «\(oneLine($0.point, limit: 80))»: \($0.reason)." }
        if let existing, existing.edited {
            doubts.append("La sintesi attuale è stata modificata a mano dall'utente: chiedi se sostituirla.")
        }
        let summary = [
            "Sintesi di «\(item.title)» nel modello «\(template.name)», progetto \(project.name)",
            "Punti verificati: \(kept); scartati: \(result.discarded.count)",
            existing == nil ? "L'elemento non ha ancora una sintesi." : "Sostituisce la sintesi attuale.",
        ]
        let client = clientName
        return WritePlan(summary: summary, doubts: doubts) { writer, returned in
            try writer.saveSummary(
                itemID: item.id, categoryID: item.categoryId, templateID: template.id, markdown: result.markdown,
                model: client, origin: .claude)
            try writer.recordMCPChange(
                .summary, id: item.id, action: existing == nil ? .create : .update,
                previous: MCPPrevious(body: result.markdown, summary: existing))
            returned.append(item.id)
            return
                "Sintesi scritta: \(kept) punti verificati. In IAGO compare come «Sintetizzata da Claude» e l'utente può annullarla da Impostazioni › Claude."
        }
    }

    func planSuggestions(_ scope: Scope, _ arguments: JSON) throws -> WritePlan {
        let item = try visibleItem(scope, arguments["item_id"]?.string)
        let project = try writableProject(scope, item.projectId)
        let input = try SuggestionEngine.Input.load(item, from: archive)
        let tags = Set(try archive.allTags().map { $0.name.lowercased() })
        var proposals: [SuggestionEngine.Proposal] = []
        var doubts: [String] = []
        for entry in arguments["items"]?.array ?? [] {
            guard let text = entry["text"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
            else { continue }
            switch entry["kind"]?.string {
            case "tag":
                proposals.append((.tag, SuggestionPayload(text: text, isNew: !tags.contains(text.lowercased()))))
            case let kind? where kind == "decision" || kind == "activity":
                guard let quote = entry["quote"]?.string, !quote.isEmpty else {
                    doubts.append("Scartata «\(oneLine(text, limit: 80))»: manca la citazione.")
                    continue
                }
                guard let lines = input?.lines, let at = KeyPointExtractor.locate(quote, in: lines, span: 3) else {
                    doubts.append("Scartata «\(oneLine(text, limit: 80))»: citazione non trovata nel testo.")
                    continue
                }
                proposals.append(
                    (
                        kind == "decision" ? .decision : .activity,
                        SuggestionPayload(
                            text: text, quote: quote, atSec: item.type == .call ? at : nil,
                            owner: entry["owner"]?.string, confidence: "high")
                    ))
            default:
                doubts.append("Voce «\(oneLine(text, limit: 80))»: kind deve essere decision, activity o tag.")
            }
        }
        guard !proposals.isEmpty else {
            throw ToolError("Nessuna proposta valida. " + doubts.joined(separator: " "))
        }
        let summary =
            ["Proposte per «\(item.title)», progetto \(project.name): restano da confermare nella scheda."]
            + proposals.map { "\(Self.kindLabel($0.kind)): \(oneLine($0.payload.text, limit: 100))" }
        let client = clientName
        return WritePlan(summary: summary, doubts: doubts) { writer, returned in
            let added = try writer.replacePendingSuggestions(
                itemID: item.id, model: client, origin: .claude, proposals)
            try writer.recordMCPChange(
                .suggestion, id: item.id, action: .create, previous: MCPPrevious(suggestionIDs: added.map(\.id)))
            returned += added.map(\.id)
            return
                "\(added.count) proposte aggiunte a «\(item.title)» (quelle già confermate o scartate dall'utente non tornano). Compaiono come «Consigliata da Claude» e l'utente le conferma nella scheda."
        }
    }

    static func kindLabel(_ kind: Suggestion.Kind) -> String {
        switch kind {
        case .decision: "Decisione"
        case .activity: "Attività"
        case .tag: "Tag"
        case .person: "Nome"
        case .project: "Progetto"
        case .link: "Collegamento"
        }
    }

    /// The app Claude is used from, as it introduced itself; "Claude" before it did.
    var clientName: String { session.client ?? "Claude" }
}
