import IAGOCore
import IAGOIntelligence
import IAGOStore
import SwiftUI

/// "Grafo" (FR-160…165, ADR-0045): relations among projects, items, people, tags and decisions of the sidebar
/// scope. Centered on an item (depth 1, double click expands a node) or the whole scope; filters by type, a
/// time slider, pan and zoom. A click opens items, decisions and notes in the detail pane.
struct GraphView: View {
    @Bindable var model: AppModel

    enum Mode: Hashable { case centered, whole }

    @State private var full = Graph()
    /// `visible`, computed once per change (filters, mode, data) rather than at every frame.
    @State private var shown = Graph()
    @State private var mode = Mode.whole
    @State private var focus: String?
    @State private var expanded: Set<String> = []
    @State private var kinds: Set<GraphNode.Kind> = Set(GraphNode.Kind.allCases).subtracting([.note])
    @State private var cutoff: Date?
    @State private var positions: [String: CGPoint] = [:]
    @State private var pinned: Set<String> = []
    @State private var offset = CGSize.zero
    @State private var panStart: CGSize?
    @State private var scale: CGFloat = 1
    @State private var scaleStart: CGFloat?
    @State private var draggedNode: String?
    @State private var selected: String?
    @State private var hovered: String?
    @State private var layoutTask: Task<Void, Never>?

    static let nodeLimit = 500

    var body: some View {
        VStack(spacing: 0) {
            ViewModePicker(model: model)
            controls
            Divider()
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    canvas(size: geometry.size)
                    if let selected, let node = shown.nodes[selected] { card(node) }
                    legend.padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
        .task(id: "\(model.revision)|\(scopeKey)") { await rebuild() }
        .onChange(of: visibleKey) { _, _ in relayout() }
        .onAppear {
            if let item = model.selectedItemID {
                focus = "item:\(item)"
                mode = .centered
            }
        }
    }

    // MARK: Data

    private var scope: GraphScope {
        switch model.sidebar {
        case .library(.project(let id)): .project(id)
        case .library(.client(let id)): .client(id)
        case .library(.stream(let id)): .stream(id)
        default: .all
        }
    }

    private var scopeKey: String { "\(scope)" }

    private func rebuild() async {
        let archive = model.archive
        let scope = self.scope
        let graph = await Task.detached(priority: .userInitiated) {
            (try? GraphBuilder.build(scope, archive: archive)) ?? Graph()
        }.value
        full = graph
        if let focus, graph.nodes[focus] == nil { self.focus = nil }
        relayout()
    }

    /// What is on screen: mode, filters, time slider and the node limit applied to the full graph.
    private var visible: Graph {
        var graph = full
        if let cutoff { graph = graph.asOf(cutoff) }
        graph = graph.restricted(
            to: Set(graph.nodes.values.filter { kinds.contains($0.kind) || $0.id == focus }.map(\.id)))
        if mode == .centered, let focus, graph.nodes[focus] != nil {
            var ids: Set<String> = [focus]
            ids.formUnion(graph.neighbors(of: focus))
            for node in expanded where graph.nodes[node] != nil {
                ids.insert(node)
                ids.formUnion(graph.neighbors(of: node))
            }
            graph = graph.restricted(to: ids)
        }
        return graph.limited(to: Self.nodeLimit)
    }

    private var visibleKey: String {
        "\(full.nodes.count)|\(mode)|\(focus ?? "")|\(expanded.sorted())|\(kinds.map(\.rawValue).sorted())|\(cutoff?.timeIntervalSince1970 ?? 0)"
    }

    private var dateRange: ClosedRange<Date>? {
        let dates = full.nodes.values.compactMap(\.date)
        guard let first = dates.min(), let last = dates.max(), first < last else { return nil }
        return first...last
    }

    // MARK: Layout

    /// Force-directed layout off the main thread; nodes already placed keep their place, new ones start near a
    /// neighbor.
    private func relayout() {
        let graph = visible
        shown = graph
        var start = positions.filter { graph.nodes[$0.key] != nil }
        for id in graph.nodes.keys where start[id] == nil {
            let anchor = graph.neighbors(of: id).compactMap { start[$0] }.first ?? .zero
            start[id] = CGPoint(
                x: anchor.x + .random(in: -40...40), y: anchor.y + .random(in: -40...40))
        }
        let fixed = pinned.intersection(graph.nodes.keys)
        let focusID = mode == .centered ? focus : nil
        let initial = start
        layoutTask?.cancel()
        layoutTask = Task {
            let result = await Task.detached(priority: .userInitiated) {
                ForceLayout.run(graph: graph, start: initial, fixed: fixed, center: focusID, iterations: 220)
            }.value
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { positions = result }
        }
        positions = initial
    }

    // MARK: Drawing

    private func canvas(size: CGSize) -> some View {
        let graph = shown
        let center = CGPoint(x: size.width / 2 + offset.width, y: size.height / 2 + offset.height)
        let neighborhood = selected.map { graph.neighbors(of: $0).union([$0]) }
        return Canvas { context, _ in
            func point(_ id: String) -> CGPoint? {
                positions[id].map { CGPoint(x: center.x + $0.x * scale, y: center.y + $0.y * scale) }
            }
            for edge in graph.edges {
                guard let from = point(edge.from), let to = point(edge.to) else { continue }
                var path = Path()
                path.move(to: from)
                path.addLine(to: to)
                let highlighted = neighborhood.map { $0.contains(edge.from) && $0.contains(edge.to) } ?? false
                let faded = neighborhood != nil && !highlighted
                context.stroke(
                    path,
                    with: .color(
                        edge.kind == .supersedes
                            ? Color.green.opacity(faded ? 0.15 : 0.7)
                            : Color.secondary.opacity(faded ? 0.08 : highlighted ? 0.7 : 0.3)),
                    style: StrokeStyle(
                        lineWidth: highlighted ? 1.6 : 1,
                        dash: [.supersedes, .derivedFrom, .dependsOn].contains(edge.kind) ? [4, 3] : []))
            }
            for node in graph.nodes.values {
                guard let p = point(node.id) else { continue }
                let faded = neighborhood.map { !$0.contains(node.id) } ?? false
                let radius = GraphStyle.radius(node.kind) * max(0.7, min(scale, 1.6))
                let shape = GraphStyle.path(node.kind, center: p, radius: radius)
                let color = GraphStyle.color(node).opacity(faded ? 0.2 : node.inactive ? 0.45 : 1)
                if node.kind == .person {
                    context.stroke(shape, with: .color(color), lineWidth: 2)
                } else {
                    context.fill(shape, with: .color(color))
                }
                if node.id == selected || node.id == focus {
                    context.stroke(
                        Path(
                            ellipseIn: CGRect(
                                x: p.x - radius - 4, y: p.y - radius - 4, width: 2 * radius + 8,
                                height: 2 * radius + 8)),
                        with: .color(.accentColor), lineWidth: 2)
                }
                let showsLabel =
                    !faded
                    && (scale > 0.85 || node.id == hovered || node.id == selected || node.id == focus
                        || [.project, .client, .group].contains(node.kind))
                if showsLabel {
                    let label = node.label.count > 34 ? String(node.label.prefix(34)) + "…" : node.label
                    context.draw(
                        Text(label).font(.system(size: 10)).foregroundStyle(faded ? .tertiary : .secondary),
                        at: CGPoint(x: p.x, y: p.y + radius + 8), anchor: .top)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if draggedNode == nil, panStart == nil {
                        draggedNode = hit(value.startLocation, graph: graph, center: center)
                        if draggedNode == nil { panStart = offset }
                    }
                    if let node = draggedNode {
                        positions[node] = CGPoint(
                            x: (value.location.x - center.x) / scale, y: (value.location.y - center.y) / scale)
                        pinned.insert(node)
                    } else if let panStart {
                        offset = CGSize(
                            width: panStart.width + value.translation.width,
                            height: panStart.height + value.translation.height)
                    }
                }
                .onEnded { _ in
                    draggedNode = nil
                    panStart = nil
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    if scaleStart == nil { scaleStart = scale }
                    scale = min(max((scaleStart ?? 1) * value.magnification, 0.2), 4)
                }
                .onEnded { _ in scaleStart = nil }
        )
        .onTapGesture(count: 2) { location in
            guard let id = hit(location, graph: graph, center: center) else { return }
            expand(id)
        }
        .onTapGesture { location in
            open(hit(location, graph: graph, center: center))
        }
        .onContinuousHover { phase in
            if case .active(let location) = phase {
                hovered = hit(location, graph: graph, center: center)
            } else {
                hovered = nil
            }
        }
        .overlay {
            if graph.nodes.isEmpty {
                ContentUnavailableView(
                    String(localized: "Niente da mostrare"), systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text(
                        String(localized: "Prova a togliere qualche filtro o a spostare la data più avanti.")))
            }
        }
    }

    private func hit(_ location: CGPoint, graph: Graph, center: CGPoint) -> String? {
        var best: (String, CGFloat)?
        for (id, position) in positions where graph.nodes[id] != nil {
            let p = CGPoint(x: center.x + position.x * scale, y: center.y + position.y * scale)
            let distance = hypot(p.x - location.x, p.y - location.y)
            if distance < 14, distance < (best?.1 ?? .infinity) { best = (id, distance) }
        }
        return best?.0
    }

    // MARK: Interaction

    /// Items, decisions and notes open in the detail pane; the others get a small card here.
    private func open(_ id: String?) {
        selected = id
        guard let id, let node = full.nodes[id], let record = node.recordID else { return }
        switch node.kind {
        case .call, .email, .document: model.selectedItemID = record
        case .decision: model.selectedDecisionID = record
        case .note: model.selectedNoteID = record
        default: break
        }
    }

    private func expand(_ id: String) {
        if mode == .whole {
            mode = .centered
            focus = id
            expanded = []
        } else if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    private func card(_ node: GraphNode) -> some View {
        let links = shown.neighbors(of: node.id).count
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                GraphStyle.swatch(node).frame(width: 12, height: 12)
                Text(GraphStyle.name(node.kind)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    selected = nil
                } label: {
                    Image(systemName: "xmark").font(.caption)
                }
                .buttonStyle(.plain)
            }
            Text(node.label).font(.headline).lineLimit(2)
            if let date = node.date {
                Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
            }
            Text(String(localized: "\(links) collegamenti visibili")).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(String(localized: "Centra qui")) {
                    mode = .centered
                    focus = node.id
                    expanded = []
                    offset = .zero
                }
                Button(
                    expanded.contains(node.id) ? String(localized: "Comprimi") : String(localized: "Espandi")
                ) { expand(node.id) }
                .disabled(mode == .whole)
                if let action = openAction(node) {
                    Button(String(localized: "Apri"), action: action)
                }
            }
            .buttonStyle(.link).font(.caption)
        }
        .padding(12)
        .frame(width: 260, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2)))
        .padding(12)
    }

    private func openAction(_ node: GraphNode) -> (() -> Void)? {
        guard let record = node.recordID else { return nil }
        switch node.kind {
        case .project: return { model.select(.library(.project(record))) }
        case .client: return { model.select(.library(.client(record))) }
        case .tag: return { model.select(.library(.tag(record))) }
        default: return nil
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Picker("", selection: $mode) {
                    Text(String(localized: "Centrato")).tag(Mode.centered)
                    Text(String(localized: "Tutto")).tag(Mode.whole)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .disabled(focus == nil && mode == .whole)
                .help(
                    String(
                        localized:
                            "Centrato: l'elemento e i suoi vicini (doppio clic su un nodo per espanderlo). Tutto: l'intero progetto, cliente o archivio."
                    ))
                Menu {
                    ForEach(GraphNode.Kind.allCases.filter { $0 != .group }, id: \.self) { kind in
                        Toggle(
                            GraphStyle.name(kind),
                            isOn: Binding(
                                get: { kinds.contains(kind) },
                                set: { on in
                                    if on { kinds.insert(kind) } else { kinds.remove(kind) }
                                }))
                    }
                } label: {
                    Label(String(localized: "Tipi"), systemImage: "line.3.horizontal.decrease.circle")
                }
                .fixedSize()
                Spacer()
                Button {
                    scale = max(scale / 1.25, 0.2)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                Button {
                    scale = min(scale * 1.25, 4)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                Button {
                    scale = 1
                    offset = .zero
                    pinned = []
                    relayout()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help(String(localized: "Ridisponi"))
            }
            .buttonStyle(.borderless)
            if let range = dateRange {
                HStack(spacing: 8) {
                    Image(systemName: "clock").foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { (cutoff ?? range.upperBound).timeIntervalSince1970 },
                            set: { value in
                                let date = Date(timeIntervalSince1970: value)
                                cutoff = date >= range.upperBound ? nil : date
                            }),
                        in: range.lowerBound.timeIntervalSince1970...range.upperBound.timeIntervalSince1970)
                    Text(
                        cutoff.map { String(localized: "fino al \($0.formatted(date: .abbreviated, time: .omitted))") }
                            ?? String(localized: "oggi")
                    )
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary).frame(
                        width: 110, alignment: .trailing)
                }
                .help(String(localized: "Il grafo com'era fino a una data"))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var legend: some View {
        let present = Set(shown.nodes.values.map(\.kind))
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(GraphNode.Kind.allCases.filter { present.contains($0) }, id: \.self) { kind in
                HStack(spacing: 5) {
                    GraphStyle.swatch(GraphNode(id: "", kind: kind, label: "")).frame(width: 9, height: 9)
                    Text(GraphStyle.name(kind)).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial.opacity(0.8)))
    }
}

// MARK: - Style

/// Colours and shapes per node type (FR-162): every type differs in both.
enum GraphStyle {
    static func name(_ kind: GraphNode.Kind) -> String {
        switch kind {
        case .project: String(localized: "Progetti")
        case .client: String(localized: "Clienti")
        case .call: String(localized: "Call")
        case .email: String(localized: "Email")
        case .document: String(localized: "Documenti")
        case .person: String(localized: "Persone")
        case .tag: String(localized: "Tag")
        case .decision: String(localized: "Decisioni")
        case .activity: String(localized: "Attività")
        case .milestone: String(localized: "Tappe")
        case .question: String(localized: "Punti da chiarire")
        case .risk: String(localized: "Rischi")
        case .request: String(localized: "Richieste")
        case .note: String(localized: "Note")
        case .group: String(localized: "Gruppi")
        }
    }

    static func color(_ node: GraphNode) -> Color {
        switch node.kind {
        case .project: .blue
        case .client: Color.iago(node.color)
        case .call: .purple
        case .email: .indigo
        case .document: .teal
        case .person: .orange
        case .tag: .gray
        case .decision: .green
        case .activity: .pink
        case .milestone: .blue.opacity(0.75)
        case .question: .mint
        case .risk: .red
        case .request: .brown
        case .note: .yellow
        case .group: .secondary
        }
    }

    static func radius(_ kind: GraphNode.Kind) -> CGFloat {
        switch kind {
        case .client: 11
        case .project: 10
        case .group: 10
        case .call, .email, .document, .decision, .activity, .milestone, .question, .risk, .request: 7
        case .person: 6
        case .tag: 5.5
        case .note: 4.5
        }
    }

    static func path(_ kind: GraphNode.Kind, center p: CGPoint, radius r: CGFloat) -> Path {
        let rect = CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
        switch kind {
        case .project: return Path(roundedRect: rect, cornerRadius: r * 0.35)
        case .client, .note: return Path(rect)
        case .call, .person: return Path(ellipseIn: rect)
        case .email:
            var path = Path()
            path.move(to: CGPoint(x: p.x, y: p.y - r))
            path.addLine(to: CGPoint(x: p.x + r, y: p.y))
            path.addLine(to: CGPoint(x: p.x, y: p.y + r))
            path.addLine(to: CGPoint(x: p.x - r, y: p.y))
            path.closeSubpath()
            return path
        case .document: return Path(CGRect(x: p.x - r * 0.75, y: p.y - r, width: r * 1.5, height: 2 * r))
        case .tag: return polygon(p, r, sides: 6, rotation: 0)
        case .decision: return star(p, r)
        case .activity: return polygon(p, r, sides: 5, rotation: -.pi / 2)
        case .milestone: return polygon(p, r * 1.15, sides: 3, rotation: -.pi / 2)
        case .question: return polygon(p, r, sides: 8, rotation: .pi / 8)
        case .risk: return polygon(p, r * 1.15, sides: 3, rotation: .pi / 2)
        case .request: return Path(CGRect(x: p.x - r, y: p.y - r * 0.7, width: 2 * r, height: r * 1.4))
        case .group: return Path(roundedRect: rect.insetBy(dx: -r * 0.4, dy: 0), cornerRadius: r)
        }
    }

    static func swatch(_ node: GraphNode) -> some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2
            let shape = path(node.kind, center: CGPoint(x: size.width / 2, y: size.height / 2), radius: r * 0.9)
            if node.kind == .person {
                context.stroke(shape, with: .color(color(node)), lineWidth: 1.5)
            } else {
                context.fill(shape, with: .color(color(node)))
            }
        }
    }

    static func polygon(_ p: CGPoint, _ r: CGFloat, sides: Int, rotation: CGFloat) -> Path {
        var path = Path()
        for index in 0..<sides {
            let angle = CGFloat(index) / CGFloat(sides) * 2 * .pi + rotation
            let point = CGPoint(x: p.x + cos(angle) * r, y: p.y + sin(angle) * r)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    static func star(_ p: CGPoint, _ r: CGFloat) -> Path {
        var path = Path()
        for index in 0..<10 {
            let angle = CGFloat(index) / 10 * 2 * .pi - .pi / 2
            let radius = index.isMultiple(of: 2) ? r * 1.2 : r * 0.55
            let point = CGPoint(x: p.x + cos(angle) * radius, y: p.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Layout

/// Spring-electrical layout: nodes repel, edges pull, a weak gravity keeps the graph together. O(n²) per step,
/// fine up to the 500-node limit (ADR-0045).
nonisolated enum ForceLayout {
    static func run(
        graph: Graph, start: [String: CGPoint], fixed: Set<String>, center: String?, iterations: Int
    ) -> [String: CGPoint] {
        let ids = Array(graph.nodes.keys).sorted()
        guard !ids.isEmpty else { return [:] }
        let index = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        var x = ids.map { Double(start[$0]?.x ?? .random(in: -100...100)) }
        var y = ids.map { Double(start[$0]?.y ?? .random(in: -100...100)) }
        let links = graph.edges.compactMap { edge -> (Int, Int)? in
            guard let a = index[edge.from], let b = index[edge.to] else { return nil }
            return (a, b)
        }
        let isFixed = ids.map { fixed.contains($0) || $0 == center }
        if let center, let c = index[center], !fixed.contains(center) {
            x[c] = 0
            y[c] = 0
        }
        let n = ids.count
        let repulsion = 2_400.0
        let springLength = 70.0
        var temperature = 30.0
        for _ in 0..<iterations {
            var dx = [Double](repeating: 0, count: n)
            var dy = [Double](repeating: 0, count: n)
            for i in 0..<n {
                for j in (i + 1)..<n {
                    var vx = x[i] - x[j]
                    var vy = y[i] - y[j]
                    var d2 = vx * vx + vy * vy
                    if d2 < 0.01 {
                        vx = .random(in: -1...1)
                        vy = .random(in: -1...1)
                        d2 = 1
                    }
                    let force = repulsion / d2
                    let d = d2.squareRoot()
                    dx[i] += vx / d * force
                    dy[i] += vy / d * force
                    dx[j] -= vx / d * force
                    dy[j] -= vy / d * force
                }
            }
            for (a, b) in links {
                let vx = x[b] - x[a]
                let vy = y[b] - y[a]
                let d = max((vx * vx + vy * vy).squareRoot(), 0.1)
                let force = (d - springLength) * 0.06
                dx[a] += vx / d * force
                dy[a] += vy / d * force
                dx[b] -= vx / d * force
                dy[b] -= vy / d * force
            }
            for i in 0..<n where !isFixed[i] {
                dx[i] -= x[i] * 0.01
                dy[i] -= y[i] * 0.01
                let length = max((dx[i] * dx[i] + dy[i] * dy[i]).squareRoot(), 0.0001)
                let step = min(length, temperature)
                x[i] += dx[i] / length * step
                y[i] += dy[i] / length * step
            }
            temperature = max(temperature * 0.985, 1.5)
        }
        return Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, CGPoint(x: x[$0], y: y[$0])) })
    }
}
