import AppKit
import IAGOStore
import SwiftUI
import UniformTypeIdentifiers

/// Client › Project › Stream in the sidebar (ADR-0038): pinned projects first (flat), then every client
/// with its projects, then "Senza cliente". Clients and projects with streams open and close; the state is
/// kept between launches. Projects can be dragged onto a client (or onto "Senza cliente").
struct ProjectTree: View {
    @Bindable var model: AppModel
    /// "Filtra progetti" (many projects): matching projects, or every project of a matching client.
    var filter = ""
    @State private var newStreamProject: Project?
    @State private var newProjectClient: Client?

    static let unassignedNode = "__no_client__"
    static let pinnedNode = "__pinned__"
    static let indent: CGFloat = 0

    private var filtering: Bool { !filter.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        if !filtering { pinnedSection }
        ForEach(model.clients.filter { !filtering || !projects(of: $0.id).isEmpty }) { client in
            // Like Teams: each client opens and closes on its own; while filtering, all are open.
            let open = filtering || isOpen(client.id)
            Section {
                if open { clientProjects(client) }
            } header: {
                ClientHeader(
                    model: model, client: client, open: open, toggle: { toggle(client.id, only: $0) },
                    newProject: { newProjectClient = client })
            }
        }
        unassigned
        EmptyView()
            .sheet(item: $newStreamProject) { project in
                NewStreamSheet(model: model, project: project) { stream in
                    model.expandedNodes.insert(project.id)
                    model.select(.library(.stream(stream.id)))
                }
            }
            .sheet(item: $newProjectClient) { client in
                NewProjectSheet(model: model, clientID: client.id) { project in
                    model.select(.library(.project(project.id)))
                }
            }
    }

    @ViewBuilder
    private func clientProjects(_ client: Client) -> some View {
        ForEach(projects(of: client.id)) { project in
            if project.pinned {
                // Second copy of a pinned project: distinct identity and no selection tag, so only the
                // row at the top is highlighted; a click still opens the project.
                ProjectRow(
                    model: model, project: project, depth: 0, showsClient: false, expandsStreams: false,
                    newStream: { newStreamProject = project }
                )
                .id("tree-\(project.id)")
                .contentShape(Rectangle())
                .onTapGesture { model.select(.library(.project(project.id))) }
                .selectionDisabled()
            } else {
                projectRow(project, showsClient: false)
            }
        }
        if projects(of: client.id).isEmpty {
            Text(String(localized: "Nessun progetto: trascina qui un progetto"))
                .font(.caption).foregroundStyle(.tertiary).selectionDisabled()
        }
    }

    @ViewBuilder
    private var unassigned: some View {
        let open = filtering || isOpen(Self.unassignedNode)
        Section {
            if open {
                ForEach(projects(of: nil)) { project in projectRow(project, showsClient: false) }
                // Classified items without a project: a container, last.
                Label {
                    Text(String(localized: "Non definito")).foregroundStyle(.secondary)
                } icon: {
                    Circle().strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                        .frame(width: 9, height: 9)
                }
                .help(String(localized: "Elementi classificati senza progetto"))
                .tag(AppModel.SidebarSelection.library(.undefinedProject))
            }
        } header: {
            UnassignedHeader(model: model, open: open) { toggle(Self.unassignedNode, only: $0) }
        }
    }

    /// Pinned projects (with their client in small type), then pinned categories and tags.
    @ViewBuilder
    private var pinnedSection: some View {
        let pinned = model.projects.filter(\.pinned)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let labels = model.pinnedLabels
        if !pinned.isEmpty || !labels.isEmpty {
            let open = isOpen(Self.pinnedNode)
            Section {
                if open {
                    ForEach(pinned) { project in projectRow(project, showsClient: true) }
                    ForEach(labels, id: \.self) { key in pinnedLabel(key) }
                }
            } header: {
                GroupHeader(
                    title: String(localized: "In evidenza"), open: open, count: pinned.count + labels.count,
                    mark: { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.red) }
                ) { toggle(Self.pinnedNode, only: $0) }
            }
        }
    }

    @ViewBuilder
    private func pinnedLabel(_ key: String) -> some View {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            if parts[0] == "tag", let tag = model.tags.first(where: { $0.id == parts[1] }) {
                Label("#\(tag.name)", systemImage: "tag")
                    .tag(AppModel.SidebarSelection.library(.tag(tag.id)))
                    .contextMenu { unpin(key) }
            } else if parts[0] == "category", let category = model.categories.first(where: { $0.id == parts[1] }) {
                Label {
                    Text(category.name)
                } icon: {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(category.color.flatMap(Color.init(hex:)) ?? Color.secondary.opacity(0.5))
                        .frame(width: 9, height: 9)
                }
                .tag(AppModel.SidebarSelection.library(.category(category.id)))
                .contextMenu { unpin(key) }
            } else if parts[0] == "stream", let stream = model.streams.first(where: { $0.id == parts[1] }) {
                Label {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(stream.name).lineLimit(1)
                        if let project = model.project(stream.projectId) {
                            Text(project.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                } icon: {
                    Text("–").foregroundStyle(.secondary)
                }
                .tag(AppModel.SidebarSelection.library(.stream(stream.id)))
                .contextMenu { unpin(key) }
            }
        }
    }

    private func unpin(_ key: String) -> some View {
        Button(String(localized: "Togli da «In evidenza»")) { model.togglePinnedLabel(key) }
    }

    /// Clients start open; closing one is remembered.
    private func isOpen(_ id: String) -> Bool { !model.expandedNodes.contains("closed:\(id)") }

    /// A click opens or closes; with ⌥ it opens this one and closes all the others (to focus).
    private func toggle(_ id: String, only: Bool) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if only {
                for other in model.clients.map(\.id) + [Self.unassignedNode, Self.pinnedNode] where other != id {
                    model.expandedNodes.insert("closed:\(other)")
                }
                model.expandedNodes.remove("closed:\(id)")
            } else if isOpen(id) {
                model.expandedNodes.insert("closed:\(id)")
            } else {
                model.expandedNodes.remove("closed:\(id)")
            }
        }
    }

    /// Every project of a client (nil: without a client), pinned ones included; while filtering, the matching ones
    /// (all of them when the client's name matches).
    private func projects(of clientID: String?) -> [Project] {
        let needle = filter.trimmingCharacters(in: .whitespaces)
        let clientMatches =
            clientID.flatMap { id in model.clients.first { $0.id == id } }
            .map { $0.name.localizedCaseInsensitiveContains(needle) } ?? false
        return model.projects.filter { $0.clientId == clientID }
            .filter { needle.isEmpty || clientMatches || $0.name.localizedCaseInsensitiveContains(needle) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @ViewBuilder
    private func projectRow(_ project: Project, showsClient: Bool) -> some View {
        ProjectRow(
            model: model, project: project, depth: 0, showsClient: showsClient, expandsStreams: true,
            newStream: { newStreamProject = project }
        )
        .tag(AppModel.SidebarSelection.library(.project(project.id)))
        if model.expandedNodes.contains(project.id) {
            ForEach(model.streams(of: project.id)) { stream in
                StreamRow(model: model, stream: stream, depth: 1)
                    .tag(AppModel.SidebarSelection.library(.stream(stream.id)))
            }
        }
    }
}

/// A group of the sidebar that opens and closes like a client ("In evidenza"): chevron, mark, title, count when closed.
private struct GroupHeader<Mark: View>: View {
    let title: String
    let open: Bool
    let count: Int
    @ViewBuilder let mark: () -> Mark
    let toggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                .rotationEffect(.degrees(open ? 90 : 0)).frame(width: 10)
            // As wide as a client's colour mark, so marks and titles line up.
            mark().frame(width: 18, height: 11)
            SidebarSectionTitle(text: title)
            if !open, count > 0 { Text("\(count)").font(.caption2).monospacedDigit().foregroundStyle(.tertiary) }
            Spacer()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { toggle(NSEvent.modifierFlags.contains(.option)) }
    }
}

/// Section titles of the sidebar: small capitals, grey, like the system's.
struct SidebarSectionTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(0.7).foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

/// Disclosure chevron used by every level of the tree.
private struct Chevron: View {
    let expanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .frame(width: 12, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.secondary)
    }
}

/// A client as the title of its section: colour, name in small capitals, "+" for a new project. A click on the name
/// opens the client; projects can be dropped on it.
private struct ClientHeader: View {
    let model: AppModel
    let client: Client
    let open: Bool
    /// true: ⌥-click, open only this client.
    let toggle: (Bool) -> Void
    let newProject: () -> Void
    @State private var dropTargeted = false
    @State private var renaming = false
    @State private var deleting = false
    @State private var hovering = false

    var body: some View {
        let selected = model.sidebar == .library(.client(client.id))
        let count = model.projects.filter { $0.clientId == client.id }.count
        HStack(spacing: 6) {
            Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                .rotationEffect(.degrees(open ? 90 : 0)).frame(width: 10)
            ColorMark(color: client.color, square: true) { color in
                model.perform { try model.archive.updateClient(client.id) { $0.color = color } }
            }
            Text(client.name.uppercased()).font(.caption.weight(.semibold)).tracking(0.7)
                .foregroundStyle(selected ? Color.accentColor : Color.secondary).lineLimit(1)
            if !open, count > 0 {
                Text("\(count)").font(.caption2).monospacedDigit().foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            if hovering {
                Button {
                    model.select(.library(.client(client.id)))
                } label: {
                    Image(systemName: "arrow.right.circle").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help(String(localized: "Apri tutti gli elementi di «\(client.name)»"))
                Button(action: newProject) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help(String(localized: "Nuovo progetto in «\(client.name)»"))
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { toggle(NSEvent.modifierFlags.contains(.option)) }
        .help(String(localized: "Clic: apri o chiudi · ⌥-clic: solo questo cliente"))
        .onHover { hovering = $0 }
        .background(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: dropTargeted ? 2 : 0))
        .onDrop(of: [.plainText], isTargeted: $dropTargeted) { providers in
            ProjectDrag.receive(providers) { projectID in model.setProjectClient(projectID, client.id) }
        }
        .contextMenu {
            Button(String(localized: "Apri «\(client.name)»")) { model.select(.library(.client(client.id))) }
            Button(String(localized: "Impostazioni…")) {
                model.scopeSettings = ScopeSettingsTarget(scope: .client(client.id))
            }
            Button(String(localized: "Nuovo progetto in «\(client.name)»…"), action: newProject)
            Button(String(localized: "Rinomina…")) { renaming = true }
            Divider()
            Button(String(localized: "Elimina cliente…"), role: .destructive) { deleting = true }
        }
        .sheet(isPresented: $renaming) {
            RenameSheet(title: String(localized: "Rinomina cliente"), name: client.name) { name in
                model.perform { try model.archive.updateClient(client.id) { $0.name = name } }
            }
        }
        .confirmationDialog(
            String(localized: "Eliminare il cliente «\(client.name)»?"), isPresented: $deleting,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Elimina cliente"), role: .destructive) {
                model.perform { try model.archive.deleteClient(client.id) }
                if model.sidebar == .library(.client(client.id)) { model.select(.library(.unclassified)) }
            }
        } message: {
            Text(String(localized: "I suoi progetti restano, senza cliente. Nessun elemento viene eliminato."))
        }
    }
}

private struct UnassignedHeader: View {
    let model: AppModel
    let open: Bool
    let toggle: (Bool) -> Void
    @State private var dropTargeted = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                .rotationEffect(.degrees(open ? 90 : 0)).frame(width: 10)
            RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.55)).frame(width: 11, height: 11)
                .frame(width: 18)
            SidebarSectionTitle(text: String(localized: "Senza cliente"))
            Spacer()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { toggle(NSEvent.modifierFlags.contains(.option)) }
        .background(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: dropTargeted ? 2 : 0))
        .onDrop(of: [.plainText], isTargeted: $dropTargeted) { providers in
            ProjectDrag.receive(providers) { model.setProjectClient($0, nil) }
        }
    }
}

/// Project row: chevron when it has streams, a small pin (tilted and grey when not pinned), the client in
/// small type for pinned copies at the top. Draggable onto a client.
private struct ProjectRow: View {
    let model: AppModel
    let project: Project
    let depth: Int
    let showsClient: Bool
    let expandsStreams: Bool
    let newStream: () -> Void
    @State private var hovering = false
    @State private var renaming = false

    var body: some View {
        let streams = model.streams(of: project.id)
        HStack(spacing: 4) {
            if expandsStreams, !streams.isEmpty {
                Chevron(expanded: model.expandedNodes.contains(project.id)) {
                    withAnimation(.easeInOut(duration: 0.15)) { model.toggleExpanded(project.id) }
                }
            } else {
                Color.clear.frame(width: 12, height: 1)
            }
            // Projects stay neutral: a small dot in the text colour (clients carry the colour).
            Circle().fill(Color.primary.opacity(0.75)).frame(width: 5, height: 5).frame(width: 14, height: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(project.name).lineLimit(1)
                if showsClient, let client = model.client(project.clientId) {
                    Text(client.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            AccessMark(model: model, project: project)
            Spacer(minLength: 4)
            Button {
                model.setPinned(project, !project.pinned)
            } label: {
                Image(systemName: project.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 10))
                    .rotationEffect(.degrees(project.pinned ? 0 : 45))
                    .foregroundStyle(project.pinned ? Color.primary : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .opacity(project.pinned || hovering ? 1 : 0.45)
            .help(project.pinned ? String(localized: "Togli dall'alto") : String(localized: "Fissa in alto"))
        }
        .padding(.leading, ProjectTree.indent + CGFloat(depth) * 15)
        .onHover { hovering = $0 }
        .onDrag { ProjectDrag.provider(project.id) }
        .contextMenu {
            Button(String(localized: "Impostazioni…")) {
                model.scopeSettings = ScopeSettingsTarget(scope: .project(project.id))
            }
            Button(String(localized: "Nuovo stream…"), action: newStream)
            Menu(String(localized: "Sposta nel cliente")) {
                // The current client is ticked, not greyed out (it looked like the action was unavailable).
                Toggle(
                    String(localized: "Nessun cliente"),
                    isOn: Binding(
                        get: { project.clientId == nil }, set: { _ in model.setProjectClient(project.id, nil) }))
                Divider()
                ForEach(model.clients) { client in
                    Toggle(
                        client.name,
                        isOn: Binding(
                            get: { project.clientId == client.id },
                            set: { _ in model.setProjectClient(project.id, client.id) }))
                }
            }
            Button(String(localized: "Rinomina…")) { renaming = true }
            Button(project.pinned ? String(localized: "Togli dall'alto") : String(localized: "Fissa in alto")) {
                model.setPinned(project, !project.pinned)
            }
        }
        .sheet(isPresented: $renaming) {
            RenameSheet(title: String(localized: "Rinomina progetto"), name: project.name) { name in
                model.perform { try model.archive.renameProject(project.id, to: name) }
            }
        }
    }
}

private struct StreamRow: View {
    let model: AppModel
    let stream: ProjectStream
    let depth: Int
    @State private var renaming = false
    @State private var deleting = false

    var body: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: 12, height: 1)
            Text("–").foregroundStyle(.secondary).frame(width: 14)
            Text(stream.name).lineLimit(1)
            Spacer()
        }
        .padding(.leading, ProjectTree.indent + CGFloat(depth) * 15 + 12)
        .contextMenu {
            Button(String(localized: "Rinomina…")) { renaming = true }
            Button(
                model.isPinnedLabel("stream:\(stream.id)")
                    ? String(localized: "Togli dall'alto") : String(localized: "Fissa in alto")
            ) { model.togglePinnedLabel("stream:\(stream.id)") }
            Divider()
            Button(String(localized: "Elimina stream…"), role: .destructive) { deleting = true }
        }
        .sheet(isPresented: $renaming) {
            RenameSheet(title: String(localized: "Rinomina stream"), name: stream.name) { name in
                model.perform { try model.archive.updateStream(stream.id) { $0.name = name } }
            }
        }
        .confirmationDialog(
            String(localized: "Eliminare lo stream «\(stream.name)»?"), isPresented: $deleting,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Elimina stream"), role: .destructive) {
                model.perform { try model.archive.deleteStream(stream.id) }
                if model.isPinnedLabel("stream:\(stream.id)") { model.togglePinnedLabel("stream:\(stream.id)") }
                if model.sidebar == .library(.stream(stream.id)) {
                    model.select(.library(.project(stream.projectId)))
                }
            }
        } message: {
            Text(String(localized: "Elementi e decisioni restano nel progetto: perdono solo l'etichetta dello stream."))
        }
    }
}

/// A project dragged in the sidebar travels as plain text with a prefix, so it is never mistaken for a file.
enum ProjectDrag {
    static let prefix = "iago-project:"

    static func provider(_ projectID: String) -> NSItemProvider {
        NSItemProvider(object: "\(prefix)\(projectID)" as NSString)
    }

    static func receive(_ providers: [NSItemProvider], _ apply: @escaping @MainActor (String) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String, text.hasPrefix(prefix) else { return }
            let id = String(text.dropFirst(prefix.count))
            Task { @MainActor in apply(id) }
        }
        return true
    }
}

// MARK: - Sheets

/// New client with the same duplicate check as projects.
struct NewClientSheet: View {
    let model: AppModel
    let onDone: (Client) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let similar = trimmed.isEmpty ? [] : model.similarClients(to: trimmed)
        NameSheetLayout(
            title: String(localized: "Nuovo cliente"), placeholder: String(localized: "Nome del cliente"),
            name: $name, similar: similar.map { ($0.id, $0.name) }, icon: "building.2",
            use: { id in
                if let client = model.client(id) { onDone(client) }
                dismiss()
            },
            create: {
                if let client = model.createClient(named: trimmed) { onDone(client) }
                dismiss()
            }, cancel: { dismiss() })
    }
}

struct NewStreamSheet: View {
    let model: AppModel
    let project: Project
    let onDone: (ProjectStream) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let similar =
            trimmed.isEmpty
            ? [] : model.streams(of: project.id).filter { ProjectNameMatcher.isSimilar(trimmed, $0.name) }
        NameSheetLayout(
            title: String(localized: "Nuovo stream in «\(project.name)»"),
            placeholder: String(localized: "Nome dello stream (es. Design, Sviluppo, Legale)"),
            name: $name, similar: similar.map { ($0.id, $0.name) }, icon: "circle.fill",
            use: { id in
                if let stream = model.stream(id) { onDone(stream) }
                dismiss()
            },
            create: {
                if let stream = model.createStream(named: trimmed, in: project.id) { onDone(stream) }
                dismiss()
            }, cancel: { dismiss() })
    }
}

/// Name field with "esistono già … simili: Usa questo" and "Crea comunque".
struct NameSheetLayout: View {
    let title: String
    let placeholder: String
    @Binding var name: String
    let similar: [(id: String, name: String)]
    let icon: String
    let use: (String) -> Void
    let create: () -> Void
    let cancel: () -> Void

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3).bold()
            TextField(placeholder, text: $name)
                .textFieldStyle(.roundedBorder).frame(width: 380)
                .onSubmit { if similar.isEmpty, !trimmed.isEmpty { create() } }
            if !similar.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "Esistono già nomi simili:"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    ForEach(similar, id: \.id) { entry in
                        HStack {
                            Image(systemName: icon)
                            Text(entry.name).bold()
                            Spacer()
                            Button(String(localized: "Usa questo")) { use(entry.id) }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel, action: cancel).keyboardShortcut(.cancelAction)
                if similar.isEmpty {
                    Button(String(localized: "Crea"), action: create)
                        .keyboardShortcut(.defaultAction).disabled(trimmed.isEmpty)
                } else {
                    Button(String(localized: "Crea comunque \"\(trimmed)\""), action: create)
                }
            }
        }
        .padding(20)
    }
}

struct RenameSheet: View {
    let title: String
    @State var name: String
    let save: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3).bold()
            TextField("", text: $name).textFieldStyle(.roundedBorder).frame(width: 340)
                .onSubmit(commit)
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(String(localized: "Rinomina"), action: commit).keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        save(trimmed)
        dismiss()
    }
}

// MARK: - Streams on items and decisions

/// Multiple choice among the streams of a project, plus "Nuovo stream…" (ADR-0038).
struct StreamChooser: View {
    let model: AppModel
    let projectID: String
    @Binding var selection: [String]
    @State private var creating = false

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(model.streams(of: projectID)) { stream in
                let on = selection.contains(stream.id)
                Button {
                    if on { selection.removeAll { $0 == stream.id } } else { selection.append(stream.id) }
                } label: {
                    HStack(spacing: 5) {
                        Circle().fill(Color.iago(stream.color)).frame(width: 8, height: 8)
                        Text(stream.name)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(
                        Capsule().fill(on ? Color.iago(stream.color).opacity(0.25) : Color.secondary.opacity(0.1))
                    )
                    .overlay(Capsule().stroke(on ? Color.iago(stream.color) : Color.secondary.opacity(0.25)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Button(String(localized: "+ Nuovo stream")) { creating = true }
                .buttonStyle(.link).font(.caption)
        }
        .sheet(isPresented: $creating) {
            if let project = model.project(projectID) {
                NewStreamSheet(model: model, project: project) { stream in
                    if !selection.contains(stream.id) { selection.append(stream.id) }
                }
            }
        }
    }
}

/// Colored dots of an item's or decision's streams.
struct StreamDots: View {
    let model: AppModel
    let streamIDs: [String]
    var showsNames = true

    var body: some View {
        let streams = streamIDs.compactMap { model.stream($0) }.sorted { $0.sortOrder < $1.sortOrder }
        if !streams.isEmpty {
            HStack(spacing: 6) {
                ForEach(streams) { stream in
                    HStack(spacing: 3) {
                        Circle().fill(Color.iago(stream.color)).frame(width: 7, height: 7)
                        if showsNames { Text(stream.name).font(.caption).foregroundStyle(.secondary) }
                    }
                    .help(stream.name)
                }
            }
        }
    }
}

extension Color {
    /// Palette names stored on clients and streams (`Archive.palette`).
    static func iago(_ name: String?) -> Color {
        switch name {
        case "blue": .blue
        case "green": .green
        case "orange": .orange
        case "purple": .purple
        case "pink": .pink
        case "teal": .teal
        case "yellow": .yellow
        case "red": .red
        case "indigo": .indigo
        case "brown": .brown
        default: .accentColor
        }
    }
}

/// A client in the sidebar: a small rounded square in its colour, so it never looks like a project folder.
struct ClientMark: View {
    let color: String?

    var body: some View {
        RoundedRectangle(cornerRadius: 3).fill(Color.iago(color)).frame(width: 11, height: 11)
            .frame(width: 18, height: 16)
    }
}

/// "In evidenza" / "Tutti": a small label inside the Progetti section, not selectable.
private struct GroupLabel: View {
    let text: String

    var body: some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(.tertiary)
            .padding(.leading, ProjectTree.indent + 4).padding(.top, 6)
            .selectionDisabled()
    }
}
