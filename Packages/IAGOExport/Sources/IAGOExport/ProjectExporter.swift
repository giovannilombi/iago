import Foundation
import IAGOCore
import IAGOStore

/// One Markdown file with a whole project (or client, stream, selection) for an LLM (FR-90/91, spec 11.2/11.3):
/// index, decision register, then items and project notes in chronological order, each headed by its type.
public enum ProjectExporter {
    public struct Options: Sendable {
        public enum Documents: Sendable, Hashable {
            case full
            /// The first characters, with a pointer to the item in IAGO.
            case excerpt(Int)
        }

        /// Shown as the export title and in the front matter.
        public var title: String
        /// Items to include, already filtered as in the library; any order (sorted by date here).
        public var itemIDs: [String]
        /// Project notes of these projects are included (FR-172).
        public var projectNoteIDs: [String]
        public var decisionScope: DecisionQuery.Scope?
        public var includeNotes: Bool
        public var includeDecisions: Bool
        public var documents: Documents
        /// Free-text description of the filters, for the front matter.
        public var filtersDescription: String

        public init(
            title: String, itemIDs: [String], projectNoteIDs: [String] = [], decisionScope: DecisionQuery.Scope? = nil,
            includeNotes: Bool = true, includeDecisions: Bool = true, documents: Documents = .full,
            filtersDescription: String = "nessuno"
        ) {
            self.title = title
            self.itemIDs = itemIDs
            self.projectNoteIDs = projectNoteIDs
            self.decisionScope = decisionScope
            self.includeNotes = includeNotes
            self.includeDecisions = includeDecisions
            self.documents = documents
            self.filtersDescription = filtersDescription
        }
    }

    /// Rough token count for an LLM: about one token every 3.6 characters of Italian text.
    public static func estimatedTokens(_ text: String) -> Int {
        Int((Double(text.count) / 3.6).rounded(.up))
    }

    enum Entry {
        case item(ItemDocument, email: EmailMeta?, content: String?, attachments: [String])
        case projectNote(Note, projectName: String?)

        var date: Date {
            switch self {
            case .item(let document, _, _, _): document.item.occurredAt
            case .projectNote(let note, _): note.notedAt
            }
        }
    }

    public static func markdown(
        _ options: Options, archive: Archive, now: Date = Date(), timeZone: TimeZone = .current
    ) throws -> String {
        var entries: [Entry] = []
        for id in options.itemIDs {
            entries.append(try itemEntry(id, archive: archive, includeNotes: options.includeNotes))
        }
        if options.includeNotes {
            let projects = try archive.projects(includeArchived: true)
            for projectID in options.projectNoteIDs {
                let name = projects.first { $0.id == projectID }?.name
                entries += try archive.notes(projectID: projectID).map { .projectNote($0, projectName: name) }
            }
        }
        entries.sort { $0.date < $1.date }

        let dates = entries.map(\.date)
        var lines = [
            "---",
            "project: \(TranscriptRenderer.yaml(options.title))",
            "exported_at: \(TranscriptRenderer.format(now, "yyyy-MM-dd'T'HH:mm", timeZone))",
            "items: \(options.itemIDs.count)",
        ]
        if let first = dates.min(), let last = dates.max() {
            lines.append(
                "period: \(TranscriptRenderer.format(first, "yyyy-MM-dd", timeZone)) → \(TranscriptRenderer.format(last, "yyyy-MM-dd", timeZone))"
            )
        }
        lines += [
            "filters: \(TranscriptRenderer.yaml(options.filtersDescription))", "---", "",
            "# \(options.title) — archivio di progetto", "",
            "> Esportato da IAGO. Le informazioni sono in ordine cronologico: in caso di conflitto prevale la più recente; per \"cosa vale oggi\" usa le decisioni con stato Attiva.",
            "", "## Indice", "",
        ]
        for (index, entry) in entries.enumerated() {
            lines.append("\(index + 1). \(heading(entry, timeZone: timeZone, withTime: false))")
        }

        if options.includeDecisions, let scope = options.decisionScope {
            let decisions = try archive.decisions(DecisionQuery(scope: scope, statuses: []))
                .sorted { $0.decision.decidedAt < $1.decision.decidedAt }
            if !decisions.isEmpty {
                lines += ["", "## Punti chiave (decisioni, tappe e lavoro aperto)", ""]
                for summary in decisions {
                    let inChain = summary.supersedes != nil || summary.supersededBy != nil
                    let chainName = inChain ? try archive.chainName(of: summary.id) : nil
                    let checklist =
                        summary.checklist.total > 0 ? try archive.checklistItems(decisionID: summary.id) : []
                    lines += decisionLines(summary, chainName: chainName, checklist: checklist, timeZone: timeZone)
                }
            }
        }

        for (index, entry) in entries.enumerated() {
            lines += ["", "---", "", "## \(index + 1). \(heading(entry, timeZone: timeZone, withTime: true))", ""]
            switch entry {
            case .projectNote(let note, _):
                lines.append(note.body)
            case .item(let document, let email, let content, let attachments):
                lines += body(
                    document, email: email, content: content, attachments: attachments, options: options,
                    timeZone: timeZone)
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// One item on its own, in the same format as in the project export: heading, facts, transcript or text,
    /// notes. Used by the MCP server's `get_item` (ADR-0043).
    public static func itemMarkdown(_ itemID: String, archive: Archive, timeZone: TimeZone = .current) throws
        -> String
    {
        let entry = try itemEntry(itemID, archive: archive, includeNotes: true)
        guard case .item(let document, let email, let content, let attachments) = entry else { return "" }
        let lines =
            ["## \(heading(entry, timeZone: timeZone, withTime: true))", ""]
            + body(
                document, email: email, content: content, attachments: attachments,
                options: Options(title: "", itemIDs: []), timeZone: timeZone)
        return lines.joined(separator: "\n") + "\n"
    }

    /// One decision as a Markdown list entry, with status, source, chain, open work details, checklist and
    /// description (FR-155, ADR-0074).
    public static func decisionMarkdown(
        _ summary: DecisionSummary, chainName: String? = nil, checklist: [ChecklistItem] = [],
        timeZone: TimeZone = .current
    ) -> String {
        decisionLines(summary, chainName: chainName, checklist: checklist, timeZone: timeZone).joined(separator: "\n")
    }

    static func itemEntry(_ id: String, archive: Archive, includeNotes: Bool) throws -> Entry {
        var document = try ItemDocument.load(id, from: archive)
        if !includeNotes { document.notes = [] }
        var content: String?
        if document.item.type != .call,
            let asset = try archive.assets(itemID: id).first(where: { $0.kind == .contentMD })
        {
            content = String(decoding: try archive.readAssetData(asset), as: UTF8.self)
        }
        let email = document.item.type == .email ? try archive.emailMeta(itemID: id) : nil
        let attachments = try archive.links(itemID: id)
            .filter { $0.link.kind == .attachmentOf && !$0.outgoing }.map(\.item.title)
        return .item(document, email: email, content: content, attachments: attachments)
    }

    // MARK: Pieces

    static func heading(_ entry: Entry, timeZone: TimeZone, withTime: Bool) -> String {
        let pattern = withTime ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
        let date = TranscriptRenderer.format(entry.date, pattern, timeZone)
        switch entry {
        case .projectNote(_, let project):
            return "\(date) · Nota di progetto" + (project.map { " · \($0)" } ?? "")
        case .item(let document, let email, _, _):
            let item = document.item
            switch item.type {
            case .email:
                let direction = email?.direction == .outbound ? "Email inviata" : "Email ricevuta"
                let from = email?.from.map { " · Da: \($0.display)" } ?? ""
                return "\(date) · \(direction)\(from) · Oggetto: \(item.title)"
            case .document:
                return "\(date) · Documento · \(item.title)"
            case .call:
                let category = document.categoryName.map { " · \($0)" } ?? ""
                let audioOnly = document.transcript == nil ? " (solo audio)" : ""
                return "\(date) · Call\(category) · \(item.title)\(audioOnly)"
            }
        }
    }

    static func body(
        _ document: ItemDocument, email: EmailMeta?, content: String?, attachments: [String], options: Options,
        timeZone: TimeZone
    ) -> [String] {
        var lines: [String] = []
        var facts: [String] = []
        if document.transcript != nil, !document.participants.isEmpty {
            facts.append("Partecipanti: \(document.participants.joined(separator: ", "))")
        }
        if let email {
            if !email.to.isEmpty { facts.append("A: \(email.to.map(\.display).joined(separator: ", "))") }
            if !email.cc.isEmpty { facts.append("Cc: \(email.cc.map(\.display).joined(separator: ", "))") }
        }
        if let project = document.projectName { facts.append("Progetto: \(project)") }
        if !document.tags.isEmpty { facts.append("Tag: \(document.tags.joined(separator: ", "))") }
        if let duration = document.item.durationSec { facts.append("Durata: \(TranscriptRenderer.minutes(duration))") }
        if !facts.isEmpty { lines += [facts.joined(separator: " · "), ""] }
        if let summary = document.summary {
            lines += ["### Sintesi", "", ItemDocument.plainSummary(summary, headingLevel: 4), ""]
        }

        switch document.item.type {
        case .call:
            lines.append("### Trascrizione")
            lines.append("")
            if let transcript = document.transcript {
                lines += transcript.segments.map {
                    "**[\(TranscriptRenderer.clock($0.start))] \(document.label(for: $0.speaker)):** \($0.text)"
                }
            } else {
                lines.append("_(solo audio, non trascritta)_")
            }
        case .email:
            lines += ["### Messaggio", "", strippingHeading(content ?? "")]
            if !attachments.isEmpty { lines += ["", "Allegati: \(attachments.joined(separator: ", "))"] }
        case .document:
            let text = strippingHeading(content ?? "")
            switch options.documents {
            case .full:
                lines.append(text)
            case .excerpt(let limit):
                if text.count > limit {
                    lines.append(String(text.prefix(limit)) + "…")
                    lines.append("")
                    lines.append("_(estratto: documento completo in IAGO, «\(document.item.title)»)_")
                } else {
                    lines.append(text)
                }
            }
        }
        if !document.notes.isEmpty {
            lines += ["", "### Note"]
            for note in document.notes {
                lines += [
                    "",
                    "**\(TranscriptRenderer.format(note.notedAt, "yyyy-MM-dd HH:mm", timeZone)) · \(TranscriptRenderer.kindLabel(note.kind))**",
                    note.body,
                ]
            }
        }
        return lines
    }

    /// One decision with status, date, source and its "supera" chain (FR-155); for open work also owner, due date,
    /// waiting for, outcome and checklist (ADR-0074): `[Punto da chiarire · Chiarito] … → answer`.
    static func decisionLines(
        _ summary: DecisionSummary, chainName: String? = nil, checklist: [ChecklistItem] = [], timeZone: TimeZone
    ) -> [String] {
        let decision = summary.decision
        let status = KeyPointLabels.tag(decision, closedBy: summary.supersededByAll)
        var line =
            "- **[\(status)] \(TranscriptRenderer.format(decision.decidedAt, "yyyy-MM-dd", timeZone))** \(decision.text)"
        if let outcome = decision.outcome, !outcome.isEmpty { line += " → \(outcome)" }
        var details: [String] = []
        if let title = summary.sourceTitle {
            details.append(
                "fonte: \(title)" + (decision.sourceAtSec.map { " @ \(TranscriptRenderer.clock($0))" } ?? ""))
        } else if summary.sourceState == .deleted {
            details.append("fonte eliminata")
        }
        if let chainName { details.append("evoluzione: «\(chainName)»") }
        if !summary.people.isEmpty { details.append("persone: \(summary.people.joined(separator: ", "))") }
        details += KeyPointLabels.workDetails(summary, timeZone: timeZone)
        if !summary.supersedesAll.isEmpty {
            details.append("supera: " + summary.supersedesAll.map { "«\($0.text)»" }.joined(separator: ", "))
        }
        if !summary.supersededByAll.isEmpty {
            let closedBy = decision.kind.isWork ? "chiusa da: " : "superata da: "
            details.append(closedBy + summary.supersededByAll.map { "«\($0.text)»" }.joined(separator: ", "))
        }
        if !details.isEmpty { line += " — " + details.joined(separator: "; ") }
        var lines = [line]
        lines += checklist.map { "  - \(KeyPointLabels.checklistLine($0))" }
        if let description = decision.notes, !description.isEmpty {
            lines += description.components(separatedBy: "\n").map { "  > \($0)" }
        }
        return lines
    }

    /// The stored Markdown of emails and documents starts with `# Title`: already in the heading.
    static func strippingHeading(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        if lines.first?.hasPrefix("# ") == true { lines.removeFirst() }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
