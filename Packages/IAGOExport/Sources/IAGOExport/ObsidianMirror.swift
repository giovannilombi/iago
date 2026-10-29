import Foundation
import IAGOCore
import IAGOStore

/// One-way mirror IAGO → Obsidian vault (FR-122, spec 10.4). Only projects the user enabled are written, in
/// clear text, under `<vault>/IAGO/`. Every file IAGO writes carries `iago_id` in its front matter: only those
/// files are rewritten or removed, any other note in the vault is never touched.
public enum ObsidianMirror {
    public struct Result: Sendable, Equatable {
        public var written: Int
        public var removed: Int
        /// Files IAGO keeps in the vault, changed or not.
        public var total: Int = 0
    }

    public static let folderName = "IAGO"

    public static func sync(
        archive: Archive, vault: URL, projectIDs: Set<String>, timeZone: TimeZone = .current
    ) throws -> Result {
        let root = vault.appendingPathComponent(folderName, isDirectory: true)
        var files: [String: String] = [:]  // relative path → content
        let projects = try archive.projects(includeArchived: true).filter { projectIDs.contains($0.id) }
        let clients = try archive.clients(includeArchived: true)
        // People known by name: entities (decisions, contacts) and renamed speakers of the mirrored calls.
        var people = Set(try archive.people().map(\.name))
        var documents: [String: ItemDocument] = [:]
        for project in projects {
            for summary in try archive.summaries(.project(project.id)) {
                let document = try ItemDocument.load(summary.id, from: archive)
                documents[summary.id] = document
                people.formUnion(document.participants.filter(Self.isPerson))
                if let meta = summary.email {
                    people.formUnion(([meta.from].compactMap { $0 } + meta.to).compactMap(\.name))
                }
            }
        }

        for project in projects {
            let projectFolder = safe(project.name)
            let client = clients.first { $0.id == project.clientId }
            let items = try archive.summaries(.project(project.id))
            var lines = ["---", "iago_id: project-\(project.id)", "type: progetto"]
            if let client { lines.append("client: \"[[\(safe(client.name))]]\"") }
            lines += ["---", "", "# \(project.name)", ""]
            if let client { lines.append("Cliente: [[\(safe(client.name))]]") }
            let decisions = try archive.decisions(
                DecisionQuery(scope: .project(project.id), statuses: [.active], kinds: Set(Decision.Kind.memory)))
            if !decisions.isEmpty {
                lines += ["", "## Decisioni attive", ""]
                lines += decisions.map {
                    "- \(TranscriptRenderer.format($0.decision.decidedAt, "yyyy-MM-dd", timeZone)) [[\(decisionFile(projectFolder, $0.decision, timeZone))|\($0.decision.text)]]"
                }
            }
            // ADR-0074: what is still open, with its state and owner.
            let work = try archive.decisions(
                DecisionQuery(scope: .project(project.id), kinds: Set(Decision.Kind.work)))
            if !work.isEmpty {
                lines += ["", "## Lavoro aperto", ""]
                lines += work.map { summary in
                    let decision = summary.decision
                    var line =
                        "- \(TranscriptRenderer.format(decision.decidedAt, "yyyy-MM-dd", timeZone)) [\(KeyPointLabels.tag(decision))] [[\(decisionFile(projectFolder, decision, timeZone))|\(decision.text)]]"
                    if let owner = summary.ownerName { line += " · [[\(safe(owner))]]" }
                    if let due = decision.dueAt {
                        line += " · entro \(TranscriptRenderer.format(due, "yyyy-MM-dd", timeZone))"
                    }
                    return line
                }
            }
            files["Progetti/\(projectFolder).md"] = lines.joined(separator: "\n") + "\n"
            if let client {
                let projectsOfClient = try archive.projects(includeArchived: true).filter { $0.clientId == client.id }
                    .filter { projectIDs.contains($0.id) }
                files["Clienti/\(safe(client.name)).md"] =
                    ([
                        "---", "iago_id: client-\(client.id)", "type: cliente", "---", "", "# \(client.name)", "",
                        "## Progetti", "",
                    ] + projectsOfClient.map { "- [[\(safe($0.name))]]" }).joined(separator: "\n") + "\n"
            }

            for summary in items {
                let item = summary.item
                guard let document = documents[item.id] else { continue }
                var body: String
                switch item.type {
                case .call: body = TranscriptRenderer.markdown(document, timeZone: timeZone)
                case .email, .document:
                    body = try contentNote(document, summary: summary, archive: archive, timeZone: timeZone)
                }
                body = linkify(body, project: project.name, client: client?.name, people: people)
                files["\(projectFolder)/\(itemFile(item, timeZone))"] = body
            }
            for note in try archive.notes(projectID: project.id) {
                let name = "\(TranscriptRenderer.format(note.notedAt, "yyyy-MM-dd HHmm", timeZone)) Nota di progetto.md"
                files["\(projectFolder)/Note/\(name)"] =
                    [
                        "---", "iago_id: note-\(note.id)", "type: nota", "project: \"[[\(safe(project.name))]]\"",
                        "date: \(TranscriptRenderer.format(note.notedAt, "yyyy-MM-dd'T'HH:mm", timeZone))", "---",
                        "", "# Nota di progetto · [[\(safe(project.name))]]", "", note.body,
                    ].joined(separator: "\n") + "\n"
            }
            for summary in try archive.decisions(DecisionQuery(scope: .project(project.id), statuses: [])) {
                let decision = summary.decision
                func day(_ date: Date) -> String { TranscriptRenderer.format(date, "yyyy-MM-dd", timeZone) }
                func link(_ entry: Decision) -> String {
                    "[[\(decisionFile(projectFolder, entry, timeZone))|\(entry.text)]]"
                }
                var lines = [
                    "---", "iago_id: decision-\(decision.id)", "type: decisione", "kind: \(decision.kind.rawValue)",
                    "status: \(decision.status.rawValue)", "project: \"[[\(safe(project.name))]]\"",
                    "date: \(day(decision.decidedAt))",
                ]
                if let due = decision.dueAt { lines.append("due: \(day(due))") }
                lines += [
                    "---", "", "# \(decision.text)", "",
                    "Progetto: [[\(safe(project.name))]] · \(KeyPointLabels.kind(decision.kind)) · Stato: "
                        + KeyPointLabels.status(decision, closedBy: summary.supersededByAll),
                ]
                if let outcome = decision.outcome, !outcome.isEmpty { lines.append("Esito: \(outcome)") }
                if !summary.people.isEmpty {
                    lines.append("Persone: " + summary.people.map { "[[\(safe($0))]]" }.joined(separator: ", "))
                }
                // ADR-0074: who, by when, waiting for whom; the other fields of "Gestisci".
                if let owner = summary.ownerName { lines.append("Responsabile: [[\(safe(owner))]]") }
                if let due = decision.dueAt { lines.append("Scadenza: \(day(due))") }
                if summary.waitingOnName != nil || decision.waitingUntil != nil {
                    lines.append(
                        "In attesa di: " + (summary.waitingOnName.map { "[[\(safe($0))]]" } ?? "")
                            + (decision.waitingUntil.map { " entro \(day($0))" } ?? ""))
                }
                if let severity = decision.severity { lines.append("Gravità: \(KeyPointLabels.severity(severity))") }
                if let happened = decision.happenedAt { lines.append("Diventato problema il \(day(happened))") }
                if let priority = decision.priority { lines.append("Priorità: \(KeyPointLabels.priority(priority))") }
                if let starts = decision.startsAt { lines.append("Inizio: \(day(starts))") }
                if let estimate = decision.estimate, !estimate.isEmpty { lines.append("Stima: \(estimate)") }
                if let recurrence = decision.recurrence {
                    lines.append("Ricorrenza: \(KeyPointLabels.recurrence(recurrence))")
                }
                if let origin = summary.derivedFrom { lines.append("Nata da: \(link(origin))") }
                if !summary.blockers.isEmpty {
                    lines.append("Dipende da: " + summary.blockers.map(link).joined(separator: ", "))
                }
                if let source = summary.sourceTitle, let sourceID = decision.sourceItemId,
                    let item = items.first(where: { $0.id == sourceID })?.item
                {
                    lines.append("Fonte: [[\(itemFile(item, timeZone).dropLast(3))|\(source)]]")
                }
                if !summary.supersedesAll.isEmpty {
                    lines.append(
                        "Supera: "
                            + summary.supersedesAll.map {
                                "[[\(decisionFile(projectFolder, $0, timeZone))|\($0.text)]]"
                            }
                            .joined(separator: ", "))
                }
                if summary.checklist.total > 0 {
                    lines +=
                        [""]
                        + (try archive.checklistItems(decisionID: decision.id)).map {
                            "- \(KeyPointLabels.checklistLine($0))"
                        }
                }
                if let description = decision.notes, !description.isEmpty { lines += ["", description] }
                files[decisionFile(projectFolder, decision, timeZone) + ".md"] = lines.joined(separator: "\n") + "\n"
            }
        }
        for person in people {
            files["Persone/\(safe(person)).md"] =
                [
                    "---", "iago_id: person-\(TagNormalizer.normalize(person))", "type: persona", "---", "",
                    "# \(person)",
                ]
                .joined(separator: "\n") + "\n"
        }
        return try write(files, into: root)
    }

    // MARK: Writing

    /// Writes changed files and removes IAGO files that no longer exist; other notes are left alone.
    static func write(_ files: [String: String], into root: URL) throws -> Result {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        var written = 0
        for (path, content) in files {
            let url = root.appendingPathComponent(path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let existing = try? String(contentsOf: url, encoding: .utf8) {
                guard ownedByIAGO(existing) else { continue }  // a user's note with the same name: never touched
                if existing == content { continue }
            }
            try Data(content.utf8).write(to: url, options: .atomic)
            written += 1
        }
        var removed = 0
        let wanted = Set(files.keys.map { root.appendingPathComponent($0).standardizedFileURL.path })
        if let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "md" {
                guard !wanted.contains(url.standardizedFileURL.path),
                    let text = try? String(contentsOf: url, encoding: .utf8), ownedByIAGO(text)
                else { continue }
                try fileManager.removeItem(at: url)
                removed += 1
            }
        }
        return Result(written: written, removed: removed, total: files.count)
    }

    static func ownedByIAGO(_ text: String) -> Bool {
        text.hasPrefix("---\n") && text.prefix(400).contains("\niago_id: ")
    }

    // MARK: Pieces

    static func contentNote(
        _ document: ItemDocument, summary: ItemSummary, archive: Archive, timeZone: TimeZone
    ) throws -> String {
        let item = document.item
        var lines = [
            "---", "iago_id: \(item.id)", "type: \(item.type == .email ? "email" : "documento")",
            "title: \(TranscriptRenderer.yaml(item.title))",
            "date: \(TranscriptRenderer.format(item.occurredAt, "yyyy-MM-dd'T'HH:mm", timeZone))",
        ]
        if let project = document.projectName { lines.append("project: \(TranscriptRenderer.yaml(project))") }
        lines.append("tags: [\(document.tags.map(TranscriptRenderer.yaml).joined(separator: ", "))]")
        if let meta = summary.email {
            lines.append("direction: \(meta.direction.rawValue)")
            if let from = meta.from { lines.append("from: \(TranscriptRenderer.yaml(from.display))") }
        }
        lines += ["---", ""]
        if let asset = try archive.assets(itemID: item.id).first(where: { $0.kind == .contentMD }) {
            lines.append(String(decoding: try archive.readAssetData(asset), as: UTF8.self))
        } else {
            lines.append("# \(item.title)")
        }
        if let text = document.summary {
            lines += ["", "## Sintesi", "", ItemDocument.plainSummary(text, headingLevel: 3)]
        }
        if !document.notes.isEmpty {
            lines += ["", "## Addendum"]
            for note in document.notes {
                lines += [
                    "",
                    "### \(TranscriptRenderer.format(note.notedAt, "yyyy-MM-dd HH:mm", timeZone)) · \(TranscriptRenderer.kindLabel(note.kind))",
                    "", note.body,
                ]
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Adds wikilinks to project, client and known people in the body (once each, after the front matter).
    static func linkify(_ markdown: String, project: String, client: String?, people: Set<String>) -> String {
        var links = ["Progetto: [[\(safe(project))]]"]
        if let client { links.append("Cliente: [[\(safe(client))]]") }
        guard
            let end = markdown.range(
                of: "\n---\n", range: markdown.index(markdown.startIndex, offsetBy: 3)..<markdown.endIndex)
        else { return markdown }
        var body = String(markdown[end.upperBound...])
        for person in people.sorted(by: { $0.count > $1.count }) where body.contains(person) {
            if let range = body.range(of: person), !body[..<range.lowerBound].hasSuffix("[[") {
                body.replaceSubrange(range, with: "[[\(safe(person))|\(person)]]")
            }
        }
        return String(markdown[..<end.upperBound]) + links.joined(separator: " · ") + "\n\n" + body
    }

    static func isPerson(_ label: String) -> Bool {
        !["Io", "Speaker", "Stanza"].contains { label == $0 || label.hasPrefix("\($0) ") }
    }

    static func itemFile(_ item: Item, _ timeZone: TimeZone) -> String {
        "\(TranscriptRenderer.format(item.occurredAt, "yyyy-MM-dd HHmm", timeZone)) \(safe(item.title)).md"
    }

    static func decisionFile(_ projectFolder: String, _ decision: Decision, _ timeZone: TimeZone) -> String {
        "\(projectFolder)/Decisioni/\(TranscriptRenderer.format(decision.decidedAt, "yyyy-MM-dd", timeZone)) \(safe(String(decision.text.prefix(60))))"
    }

    /// File names valid in Obsidian and on disk.
    static func safe(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]")
        let cleaned = name.unicodeScalars.map { forbidden.contains($0) ? "-" : String($0) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Senza titolo" : cleaned
    }
}
