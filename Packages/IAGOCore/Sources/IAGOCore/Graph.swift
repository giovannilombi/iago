import Foundation

/// A node of the relation graph (FR-160, ADR-0045). Computed from the archive, never stored.
public struct GraphNode: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case project, client, call, email, document, person, tag, decision, activity, milestone, note
        /// Items of one month, grouped when the graph is too large (FR-165).
        case group
    }

    /// Stable: "<kind>:<record id>" (persons: entity, address or name).
    public var id: String
    public var kind: Kind
    public var label: String
    /// When it happened (items, decisions, notes): drives the time slider (FR-163).
    public var date: Date?
    /// The record behind the node (item, decision, note, project, client, tag or entity id).
    public var recordID: String?
    /// Palette name for clients.
    public var color: String?
    /// Decisions no longer valid are drawn faded.
    public var inactive = false

    public init(
        id: String, kind: Kind, label: String, date: Date? = nil, recordID: String? = nil, color: String? = nil,
        inactive: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.date = date
        self.recordID = recordID
        self.color = color
        self.inactive = inactive
    }
}

public struct GraphEdge: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case inProject, ofClient, tagged, involves, linked, source, supersedes, about, grouped
    }

    public var from: String
    public var to: String
    public var kind: Kind

    public init(from: String, to: String, kind: Kind) {
        self.from = from
        self.to = to
        self.kind = kind
    }
}

public struct Graph: Sendable, Equatable {
    public var nodes: [String: GraphNode]
    public var edges: [GraphEdge]

    public init(nodes: [String: GraphNode] = [:], edges: [GraphEdge] = []) {
        self.nodes = nodes
        self.edges = Array(Set(edges)).sorted {
            ($0.from, $0.to, $0.kind.rawValue) < ($1.from, $1.to, $1.kind.rawValue)
        }
    }

    /// IDs of the nodes one edge away.
    public func neighbors(of id: String) -> Set<String> {
        var result = Set<String>()
        for edge in edges {
            if edge.from == id { result.insert(edge.to) }
            if edge.to == id { result.insert(edge.from) }
        }
        return result
    }

    /// Only these nodes and the edges among them.
    public func restricted(to ids: Set<String>) -> Graph {
        Graph(
            nodes: nodes.filter { ids.contains($0.key) },
            edges: edges.filter { ids.contains($0.from) && ids.contains($0.to) })
    }

    /// The graph as it was at `date` (FR-163): dated nodes after it are gone; undated ones (people, tags,
    /// projects) stay only if something left still points to them.
    public func asOf(_ date: Date) -> Graph {
        let dated = Set(nodes.values.filter { $0.date.map { $0 <= date } ?? false }.map(\.id))
        var keep = dated
        for edge in edges {
            if dated.contains(edge.from), nodes[edge.to]?.date == nil { keep.insert(edge.to) }
            if dated.contains(edge.to), nodes[edge.from]?.date == nil { keep.insert(edge.from) }
        }
        // A project's client stays with the project.
        for edge in edges where edge.kind == .ofClient && keep.contains(edge.from) { keep.insert(edge.to) }
        return restricted(to: keep)
    }

    /// At most `limit` nodes (FR-165): notes go first, then the oldest items are grouped by month (by year, or
    /// all together, when months are not enough).
    public func limited(to limit: Int, calendar: Calendar = .current) -> Graph {
        guard nodes.count > limit else { return self }
        let base = restricted(to: Set(nodes.values.filter { $0.kind != .note }.map(\.id)))
        guard base.nodes.count > limit else { return base }
        let items = base.nodes.values.filter { [.call, .email, .document].contains($0.kind) && $0.date != nil }
            .sorted { $0.date! < $1.date! }
        var result = base
        for granularity in [Calendar.Component.month, .year, .era] {
            // Periods oldest first; each grouped period turns its items into one node.
            var periods: [(key: String, items: [GraphNode])] = []
            for item in items {
                let key: String
                switch granularity {
                case .month:
                    let parts = calendar.dateComponents([.year, .month], from: item.date!)
                    key = "group:\(parts.year!)-\(parts.month!)"
                case .year: key = "group:\(calendar.component(.year, from: item.date!))"
                default: key = "group:all"
                }
                if periods.last?.key == key {
                    periods[periods.count - 1].items.append(item)
                } else {
                    periods.append((key, [item]))
                }
            }
            var count = base.nodes.count
            var replaced: [String: String] = [:]
            var groups: [String: GraphNode] = [:]
            for period in periods where count > limit && period.items.count > 1 {
                count -= period.items.count - 1
                for item in period.items { replaced[item.id] = period.key }
                let first = period.items[0].date!
                let label: String =
                    switch granularity {
                    case .month: first.formatted(.dateTime.month(.abbreviated).year())
                    case .year: first.formatted(.dateTime.year())
                    default: "fino al \(period.items.last!.date!.formatted(date: .abbreviated, time: .omitted))"
                    }
                groups[period.key] = GraphNode(
                    id: period.key, kind: .group, label: "\(period.items.count) elementi · \(label)", date: first)
            }
            var nodes = base.nodes
            for id in replaced.keys { nodes[id] = nil }
            for (key, node) in groups { nodes[key] = node }
            result = Graph(
                nodes: nodes,
                edges: base.edges.compactMap { edge in
                    let from = replaced[edge.from] ?? edge.from
                    let to = replaced[edge.to] ?? edge.to
                    return from == to ? nil : GraphEdge(from: from, to: to, kind: edge.kind)
                })
            if count <= limit { break }
        }
        return result
    }
}
