import Foundation
import GRDB
import IAGOCore
import IAGOStore

/// Which part of the archive the graph covers (the sidebar selection).
public enum GraphScope: Sendable, Hashable {
    case all
    case project(String)
    case client(String)
    case stream(String)
}

/// The relation graph as a projection of the archive (FR-160, spec 10.5, ADR-0045): no table of its own, one
/// read of the existing ones.
public enum GraphBuilder {
    public static func build(_ scope: GraphScope, archive: Archive) throws -> Graph {
        let ownAddresses = Set(try archive.userEmailAddresses().map { $0.lowercased() })
        return try archive.database.writer.read { db in
            var nodes: [String: GraphNode] = [:]
            var edges: [GraphEdge] = []

            // Projects and clients in scope.
            var projectFilter = "deleted_at IS NULL AND trashed_at IS NULL"
            var arguments: StatementArguments = []
            switch scope {
            case .all: break
            case .project(let id):
                projectFilter += " AND id = ?"
                arguments = [id]
            case .client(let id):
                projectFilter += " AND client_id = ?"
                arguments = [id]
            case .stream(let id):
                projectFilter += " AND id = (SELECT project_id FROM stream WHERE id = ?)"
                arguments = [id]
            }
            let projects = try Row.fetchAll(
                db, sql: "SELECT id, name, client_id FROM project WHERE \(projectFilter)", arguments: arguments)
            let projectIDs = Set(projects.map { $0["id"] as String })
            let clients = Dictionary(
                uniqueKeysWithValues: try Row.fetchAll(
                    db, sql: "SELECT id, name, color FROM client WHERE deleted_at IS NULL"
                ).map { ($0["id"] as String, $0) })
            for project in projects {
                let id: String = project["id"]
                nodes["project:\(id)"] = GraphNode(
                    id: "project:\(id)", kind: .project, label: project["name"], recordID: id)
                if let clientID: String = project["client_id"], let client = clients[clientID] {
                    nodes["client:\(clientID)"] = GraphNode(
                        id: "client:\(clientID)", kind: .client, label: client["name"], recordID: clientID,
                        color: client["color"])
                    edges.append(GraphEdge(from: "project:\(id)", to: "client:\(clientID)", kind: .ofClient))
                }
            }

            // Items.
            var itemSQL = "SELECT id, type, title, occurred_at, project_id FROM item WHERE deleted_at IS NULL"
            itemSQL += " AND trashed_at IS NULL"
            var itemArguments: StatementArguments = []
            switch scope {
            case .all: break
            case .stream(let id):
                itemSQL += " AND id IN (SELECT item_id FROM item_stream WHERE stream_id = ?)"
                itemArguments = [id]
            case .project, .client:
                itemSQL +=
                    " AND project_id IN (\(projectIDs.map { _ in "?" }.joined(separator: ",").ifEmpty("NULL")))"
                itemArguments = StatementArguments(Array(projectIDs))
            }
            let items = try Row.fetchAll(db, sql: itemSQL, arguments: itemArguments)
            var itemIDs = Set<String>()
            for item in items {
                let id: String = item["id"]
                itemIDs.insert(id)
                let kind: GraphNode.Kind =
                    switch item["type"] as String {
                    case "email": .email
                    case "document": .document
                    default: .call
                    }
                let title: String = item["title"]
                nodes["item:\(id)"] = GraphNode(
                    id: "item:\(id)", kind: kind, label: title.isEmpty ? "Senza titolo" : title,
                    date: item["occurred_at"], recordID: id)
                if let projectID: String = item["project_id"] {
                    if nodes["project:\(projectID)"] == nil,
                        let project = try Row.fetchOne(
                            db, sql: "SELECT name FROM project WHERE id = ? AND deleted_at IS NULL",
                            arguments: [projectID])
                    {
                        nodes["project:\(projectID)"] = GraphNode(
                            id: "project:\(projectID)", kind: .project, label: project["name"], recordID: projectID)
                    }
                    if nodes["project:\(projectID)"] != nil {
                        edges.append(GraphEdge(from: "item:\(id)", to: "project:\(projectID)", kind: .inProject))
                    }
                }
            }
            let itemList = Array(itemIDs)
            let placeholders = itemList.map { _ in "?" }.joined(separator: ",").ifEmpty("NULL")
            let itemArgs = StatementArguments(itemList)

            // Tags.
            for row in try Row.fetchAll(
                db,
                sql: """
                    SELECT item_tag.item_id, tag.id, tag.name FROM item_tag JOIN tag ON tag.id = item_tag.tag_id
                    WHERE tag.deleted_at IS NULL AND item_tag.item_id IN (\(placeholders))
                    """, arguments: itemArgs)
            {
                let tagID: String = row["id"]
                nodes["tag:\(tagID)"] = GraphNode(
                    id: "tag:\(tagID)", kind: .tag, label: "#\(row["name"] as String)", recordID: tagID)
                edges.append(GraphEdge(from: "item:\(row["item_id"] as String)", to: "tag:\(tagID)", kind: .tagged))
            }

            // People: entities, contacts, named speakers, email correspondents.
            let entities = Dictionary(
                uniqueKeysWithValues: try Row.fetchAll(
                    db, sql: "SELECT id, name, normalized FROM entity WHERE deleted_at IS NULL AND type = 'person'"
                ).map { ($0["id"] as String, $0) })
            let entityByName = Dictionary(
                entities.values.map { (normalize($0["name"] as String), $0["id"] as String) },
                uniquingKeysWith: { first, _ in first })
            let entityByAddress = Dictionary(
                try Row.fetchAll(
                    db,
                    sql:
                        "SELECT lower(email) AS email, entity_id FROM contact WHERE deleted_at IS NULL AND email IS NOT NULL"
                ).map { ($0["email"] as String, $0["entity_id"] as String) }, uniquingKeysWith: { first, _ in first })
            func person(entity id: String) -> String? {
                guard let entity = entities[id] else { return nil }
                nodes["person:\(id)"] = GraphNode(
                    id: "person:\(id)", kind: .person, label: entity["name"], recordID: id)
                return "person:\(id)"
            }
            func person(name: String) -> String? {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard isPersonName(trimmed) else { return nil }
                if let id = entityByName[normalize(trimmed)] { return person(entity: id) }
                let key = "person:n:\(normalize(trimmed))"
                if nodes[key] == nil { nodes[key] = GraphNode(id: key, kind: .person, label: trimmed) }
                return key
            }
            func person(address: EmailMeta.Address) -> String? {
                let email = address.address.lowercased()
                guard !email.isEmpty, !ownAddresses.contains(email) else { return nil }
                if let id = entityByAddress[email] { return person(entity: id) }
                if let name = address.name, !name.isEmpty, let id = entityByName[normalize(name)] {
                    return person(entity: id)
                }
                let key = "person:a:\(email)"
                if nodes[key] == nil {
                    nodes[key] = GraphNode(id: key, kind: .person, label: address.name ?? email)
                }
                return key
            }
            for row in try Row.fetchAll(
                db, sql: "SELECT item_id, label, entity_id FROM item_speaker WHERE item_id IN (\(placeholders))",
                arguments: itemArgs)
            {
                let target = (row["entity_id"] as String?).flatMap(person(entity:)) ?? person(name: row["label"])
                if let target {
                    edges.append(GraphEdge(from: "item:\(row["item_id"] as String)", to: target, kind: .involves))
                }
            }
            for meta in try EmailMeta.fetchAll(
                db, sql: "SELECT * FROM email_meta WHERE item_id IN (\(placeholders))", arguments: itemArgs)
            {
                for address in [meta.from].compactMap({ $0 }) + meta.to + meta.cc {
                    if let target = person(address: address) {
                        edges.append(GraphEdge(from: "item:\(meta.itemId)", to: target, kind: .involves))
                    }
                }
            }

            // Links between items.
            for row in try Row.fetchAll(
                db,
                sql: """
                    SELECT from_item_id, to_item_id FROM item_link WHERE deleted_at IS NULL
                    AND from_item_id IN (\(placeholders)) AND to_item_id IN (\(placeholders))
                    """, arguments: itemArgs + itemArgs)
            {
                edges.append(
                    GraphEdge(
                        from: "item:\(row["from_item_id"] as String)", to: "item:\(row["to_item_id"] as String)",
                        kind: .linked))
            }

            // Decisions.
            let projectPlaceholders = projectIDs.map { _ in "?" }.joined(separator: ",").ifEmpty("NULL")
            var decisionSQL = """
                SELECT id, kind, text, decided_at, project_id, source_item_id, status, derived_from_id FROM decision
                WHERE deleted_at IS NULL AND \(Archive.outsideTrashedProjects("project_id"))
                """
            var decisionArgs: StatementArguments = []
            if scope != .all {
                decisionSQL +=
                    " AND (project_id IN (\(projectPlaceholders)) OR source_item_id IN (\(placeholders)))"
                decisionArgs = StatementArguments(Array(projectIDs)) + itemArgs
            }
            let decisions = try Row.fetchAll(db, sql: decisionSQL, arguments: decisionArgs)
            let decisionIDs = Set(decisions.map { $0["id"] as String })
            for row in decisions {
                let id: String = row["id"]
                let node = "decision:\(id)"
                let kind: GraphNode.Kind =
                    switch row["kind"] as String {
                    case "action": .activity
                    case "milestone": .milestone
                    case "open_question": .question
                    case "risk": .risk
                    case "request": .request
                    default: .decision
                    }
                // Valid decisions and milestones, and work still open, are drawn in full.
                let open = Decision.Status(rawValue: row["status"] as String).map { $0.isOpen } ?? false
                nodes[node] = GraphNode(
                    id: node, kind: kind, label: row["text"], date: row["decided_at"], recordID: id,
                    inactive: !open)
                if let projectID: String = row["project_id"], nodes["project:\(projectID)"] != nil {
                    edges.append(GraphEdge(from: node, to: "project:\(projectID)", kind: .inProject))
                }
                if let itemID: String = row["source_item_id"], itemIDs.contains(itemID) {
                    edges.append(GraphEdge(from: node, to: "item:\(itemID)", kind: .source))
                }
            }
            // ADR-0052: every link, not only the most recent.
            for row in try Row.fetchAll(db, sql: "SELECT newer_id, older_id FROM decision_supersede") {
                let newer: String = row["newer_id"]
                let older: String = row["older_id"]
                guard decisionIDs.contains(newer), decisionIDs.contains(older) else { continue }
                edges.append(GraphEdge(from: "decision:\(newer)", to: "decision:\(older)", kind: .supersedes))
            }
            // ADR-0074: "nata da" and "dipende da".
            for row in decisions {
                guard let origin: String = row["derived_from_id"], decisionIDs.contains(origin) else { continue }
                edges.append(
                    GraphEdge(from: "decision:\(row["id"] as String)", to: "decision:\(origin)", kind: .derivedFrom))
            }
            for row in try Row.fetchAll(db, sql: "SELECT blocked_id, blocker_id FROM decision_dependency") {
                let blocked: String = row["blocked_id"]
                let blocker: String = row["blocker_id"]
                guard decisionIDs.contains(blocked), decisionIDs.contains(blocker) else { continue }
                edges.append(GraphEdge(from: "decision:\(blocked)", to: "decision:\(blocker)", kind: .dependsOn))
            }
            let decisionList = Array(decisionIDs)
            let decisionPlaceholders = decisionList.map { _ in "?" }.joined(separator: ",").ifEmpty("NULL")
            for row in try Row.fetchAll(
                db,
                sql:
                    "SELECT decision_id, entity_id FROM decision_entity WHERE decision_id IN (\(decisionPlaceholders))",
                arguments: StatementArguments(decisionList))
            {
                if let target = person(entity: row["entity_id"]) {
                    edges.append(
                        GraphEdge(from: "decision:\(row["decision_id"] as String)", to: target, kind: .involves))
                }
            }
            for row in try Row.fetchAll(
                db,
                sql: """
                    SELECT decision_tag.decision_id, tag.id, tag.name FROM decision_tag
                    JOIN tag ON tag.id = decision_tag.tag_id
                    WHERE tag.deleted_at IS NULL AND decision_tag.decision_id IN (\(decisionPlaceholders))
                    """, arguments: StatementArguments(decisionList))
            {
                let tagID: String = row["id"]
                nodes["tag:\(tagID)"] = GraphNode(
                    id: "tag:\(tagID)", kind: .tag, label: "#\(row["name"] as String)", recordID: tagID)
                edges.append(
                    GraphEdge(from: "decision:\(row["decision_id"] as String)", to: "tag:\(tagID)", kind: .tagged))
            }

            // Notes (hidden by default in the view).
            var noteSQL = "SELECT id, body, noted_at, item_id, project_id FROM note WHERE deleted_at IS NULL"
            noteSQL +=
                " AND (item_id IN (\(placeholders)) OR (item_id IS NULL AND project_id IN (\(projectPlaceholders))))"
            for row in try Row.fetchAll(
                db, sql: noteSQL, arguments: itemArgs + StatementArguments(Array(projectIDs)))
            {
                let id: String = row["id"]
                let body: String = row["body"]
                let firstLine = body.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
                nodes["note:\(id)"] = GraphNode(
                    id: "note:\(id)", kind: .note,
                    label: firstLine.count > 50 ? String(firstLine.prefix(50)) + "…" : firstLine,
                    date: row["noted_at"], recordID: id)
                if let itemID: String = row["item_id"] {
                    edges.append(GraphEdge(from: "note:\(id)", to: "item:\(itemID)", kind: .about))
                } else if let projectID: String = row["project_id"] {
                    edges.append(GraphEdge(from: "note:\(id)", to: "project:\(projectID)", kind: .about))
                }
            }
            return Graph(nodes: nodes, edges: edges.filter { nodes[$0.from] != nil && nodes[$0.to] != nil })
        }
    }

    /// Generic speaker labels are not people ("Io", "Speaker 2", "Stanza").
    static func isPersonName(_ label: String) -> Bool {
        guard !label.isEmpty else { return false }
        return !["Io", "Speaker", "Stanza"].contains { label == $0 || label.hasPrefix("\($0) ") }
    }

    static func normalize(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

extension String {
    fileprivate func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
