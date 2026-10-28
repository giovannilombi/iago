import IAGOStore
import SwiftUI
import UniformTypeIdentifiers
import os

/// Main window (FR-70, reduced for phase 1): sidebar, item list, detail. Files dropped anywhere on the
/// window are imported (FR-30).
struct MainView: View {
    @Bindable var model: AppModel
    @State private var isDropTargeted = false
    @State private var creatingProject = false
    /// The floating "Chiedi a IAGO" closed with its X: the entry moves to the sidebar.
    @AppStorage("askButtonHidden") private var askButtonHidden = false
    /// Width of the "Chiedi a IAGO" pane, chosen by dragging its edge.
    @AppStorage("chatWidth") private var chatWidth = 400.0

    var body: some View {
        // One three-column layout for both views: the inspector-based timeline layout looped in AppKit's
        // constraint pass and crashed the window.
        NavigationSplitView {
            sidebar
        } content: {
            Group {
                if model.showsSearch, !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    SearchResultsView(model: model)
                } else if model.sidebar == .importer {
                    ImportView(model: model)
                } else if model.sidebar == .trash {
                    TrashView(model: model)
                } else if model.sidebar == .activity {
                    ActivityView(model: model)
                } else if model.sidebar == .labels {
                    LabelsBrowser(model: model)
                } else if model.showsGraph {
                    GraphView(model: model)
                } else if model.showsDecisions {
                    DecisionsView(model: model)
                } else if model.showsTimeline {
                    ProjectTimeline(model: model)
                } else {
                    ItemList(model: model)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !model.showsSearch, !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    BackToSearchBar(model: model).background(.bar)
                }
            }
            .navigationSplitViewColumnWidth(min: contentWidth.min, ideal: contentWidth.ideal)
        } detail: {
            // "Chiedi a IAGO" sits next to the detail as a plain pane: the system inspector looped AppKit's
            // constraint pass in this three-column window and crashed it.
            // Both get an exact width, so the detail wraps its text instead of pushing the panel out.
            GeometryReader { geometry in
                let chat = model.showsChat ? ChatPane.width(stored: chatWidth, available: geometry.size.width) : 0
                HStack(spacing: 0) {
                    detail.frame(width: geometry.size.width - chat).clipped()
                    if model.showsChat {
                        ChatPane(model: model, width: $chatWidth, available: geometry.size.width)
                            .frame(width: chat)
                            .transition(.move(edge: .trailing))
                    }
                }
            }
        }
        .searchable(
            text: $model.searchText, placement: .toolbar,
            prompt: Text(String(localized: "Cerca nell'archivio  ·  #tag  ·  categoria:"))
        )
        .searchSuggestions { LabelSuggestions(model: model) }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    model.openSettings?()
                } label: {
                    Label(String(localized: "Impostazioni"), systemImage: "gearshape")
                }
                .help(String(localized: "Impostazioni (⌘,)"))
            }
            // Next to Settings, far from the search: an icon everyone reads as help, with its name.
            ToolbarItem(placement: .navigation) {
                Button {
                    model.openHelp?()
                } label: {
                    Label(String(localized: "Guida"), systemImage: "questionmark.circle")
                        .labelStyle(.titleAndIcon)
                }
                .help(String(localized: "Guida di IAGO, a tutta pagina"))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !model.showsChat, !askButtonHidden {
                AskIAGOButton(model: model) { askButtonHidden = true }
                    .padding(.trailing, 22).padding(.bottom, 20)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.showsChat)
        .sheet(item: Binding(get: { model.engine.neededFor }, set: { model.engine.neededFor = $0 })) { feature in
            EngineNeededSheet(model: model, feature: feature)
        }
        .sheet(item: $model.scopeSettings) { target in
            ScopeSettingsSheet(model: model, target: target)
        }
        .sheet(item: $model.editingDecision) { draft in
            DecisionEditor(model: model, draft: draft)
        }
        .sheet(item: $model.closingKeyPoint) { closing in
            KeyPointClosingSheet(model: model, closing: closing)
        }
        .sheet(
            item: Binding(
                get: { model.pendingEmails.first },
                set: { if $0 == nil, !model.pendingEmails.isEmpty { model.pendingEmails.removeFirst() } })
        ) { draft in
            EmailImportSheet(model: model, draft: draft) {
                if !model.pendingEmails.isEmpty { model.pendingEmails.removeFirst() }
            }
        }
        .sheet(isPresented: $model.composingEmail) { NewEmailSheet(model: model) }
        .sheet(item: $model.exporting) { kind in
            switch kind {
            case .llm: LLMExportSheet(model: model, scope: .current(model))
            case .audio: AudioExportSheet(model: model, scope: .current(model))
            }
        }
        .sheet(
            isPresented: Binding(get: { model.emailBatch != nil }, set: { if !$0 { model.emailBatch = nil } })
        ) {
            if let batch = model.emailBatch { EmailBatchSheet(model: model, drafts: batch) }
        }
        .sheet(item: Binding(get: { model.engine.readyToAnnounce }, set: { model.engine.readyToAnnounce = $0 })) {
            entry in EngineReadySheet(model: model, entry: entry)
        }
        .sheet(item: $model.editingNote) { draft in
            NoteEditor(model: model, draft: draft) { model.saveNote($0) }
        }
        .sheet(isPresented: $creatingProject) {
            NewProjectSheet(model: model, clientID: currentClientID) { project in
                model.select(.library(.project(project.id)))
            }
        }
        // Files, and emails dragged from Outlook or Mail (promised files, ADR-0040).
        // Anything is accepted and logged: Outlook offers a whole thread in forms a narrower list refused.
        .onDrop(of: [.item], isTargeted: $isDropTargeted) { providers in
            Self.importDropped(providers, model: model)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 3).padding(4)
                    .allowsHitTesting(false)
            }
        }
        .alert(
            String(localized: "Si è verificato un errore"), isPresented: .constant(model.lastError != nil),
            presenting: model.lastError
        ) { _ in
            Button(String(localized: "OK")) { model.lastError = nil }
        } message: { message in
            Text(message)
        }
        .frame(minWidth: 900, minHeight: 560)
    }

    /// "Nuovo progetto" while viewing a client creates it in that client.
    private var currentClientID: String? {
        if case .library(.client(let id)) = model.sidebar { return id }
        return nil
    }

    private var sidebar: some View {
        Sidebar(model: model, createProject: { creatingProject = true })
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }

    @ViewBuilder
    private var detail: some View {
        if let id = model.selectedItemID, model.item(id) != nil {
            ItemDetailView(model: model, itemID: id).id(id)
        } else if let id = model.selectedDecisionID {
            DecisionDetailView(model: model, decisionID: id).id(id)
        } else if let id = model.selectedNoteID {
            NoteDetailView(model: model, noteID: id).id(id)
        } else {
            ContentUnavailableView {
                VStack(spacing: 10) {
                    Image("Logo").resizable().scaledToFit().frame(width: 72, height: 72)
                    Text("IAGO").font(.title.weight(.semibold)).tracking(3)
                    Text(String(localized: "Nessun elemento selezionato"))
                }
            } description: {
                Text(String(localized: "Scegli un elemento dall'elenco, oppure trascina qui un file per importarlo."))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// A drop on the window or on the "Trascina qui" box of Importa. Every drop is logged (count and types,
    /// never content) to tell a drag that never arrives from one IAGO does not understand.
    @discardableResult
    static func importDropped(_ providers: [NSItemProvider], model: AppModel) -> Bool {
        let scratch = model.archiveService.paths.scratch
        Logger(subsystem: "com.giovannilombi.iago", category: "import").notice(
            "Drop received: \(providers.count) items, types \(Set(providers.flatMap(\.registeredTypeIdentifiers)).sorted().joined(separator: ", "), privacy: .public)"
        )
        Task { model.importFiles(await fileURLs(providers, scratch: scratch)) }
        return true
    }

    /// A dragged message that is not a file yet (Outlook, Mail): its data is written to the scratch folder. Text
    /// drags (e.g. a project moved in the sidebar) are ignored. The offered types are logged, without content,
    /// to understand drags that are not recognized.
    static func promisedFile(_ provider: NSItemProvider, into scratch: URL) async -> URL? {
        let types = provider.registeredTypeIdentifiers
        Logger(subsystem: "com.giovannilombi.iago", category: "import").notice(
            "Drop offered types: \(types.joined(separator: ", "), privacy: .public)")
        let candidates = types.compactMap(UTType.init).filter { type in
            !type.conforms(to: .text) || type.conforms(to: .emailMessage)
        }
        // An email, a folder of emails (a thread can arrive this way), or any other file.
        guard
            let type = candidates.first(where: { $0.conforms(to: .emailMessage) })
                ?? candidates.first(where: { $0.conforms(to: .folder) || $0.conforms(to: .directory) })
                ?? candidates.first(where: { $0.conforms(to: .data) })
        else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                // The file is deleted when this handler returns: copy it first.
                let folder = scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
                var name = provider.suggestedName ?? url.deletingPathExtension().lastPathComponent
                name = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
                let ext =
                    url.pathExtension.isEmpty ? (type.conforms(to: .emailMessage) ? "eml" : "") : url.pathExtension
                let destination = folder.appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: url, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    static func fileURLs(_ providers: [NSItemProvider], scratch: URL? = nil) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            if let url = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? URL {
                urls.append(url)
            } else if let data = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            {
                urls.append(url)
            } else if let scratch, let url = await promisedFile(provider, into: scratch) {
                urls.append(url)
            }
        }
        // No filter on the extension: files with a wrong one (e.g. WhatsApp voice notes) are recognized by
        // content; anything unreadable is reported by the import.
        return urls
    }
}

extension MainView {
    /// Width of the content column for what it shows.
    var contentWidth: (min: CGFloat, ideal: CGFloat) {
        switch model.sidebar {
        case .importer: return (560, 730)
        case .activity, .labels: return (420, 560)
        default:
            if model.showsGraph { return (420, 730) }
            if model.showsTimeline || model.showsDecisions { return (280, 560) }
            return (280, 320)
        }
    }
}

private struct Sidebar: View {
    @Bindable var model: AppModel
    let createProject: () -> Void
    @State private var creatingClient = false
    @State private var projectFilter = ""
    @State private var trashCount = 0
    /// Height of the fixed part, measured on its last row (starts generous so every row is laid out).
    @State private var topHeight: CGFloat = 320
    @State private var topListY: CGFloat?
    @State private var lastRowBottom: CGFloat?
    /// Shared with the floating "Chiedi a IAGO": hidden there, shown here.
    @AppStorage("askButtonHidden") private var askButtonHidden = false
    /// Past this many projects a "Filtra progetti" field appears.
    static let filterThreshold = 15

    private var selection: Binding<AppModel.SidebarSelection?> {
        Binding(get: { model.sidebar }, set: { model.select($0) })
    }

    /// Three parts: the views (fixed), clients and projects (the only part that scrolls), the bar at the bottom.
    var body: some View {
        VStack(spacing: 0) {
            List(selection: selection) { views }
                .listStyle(.sidebar).scrollDisabled(true).scrollContentBackground(.hidden)
                .onGeometryChange(for: CGFloat.self) {
                    $0.frame(in: .global).minY
                } action: {
                    topListY = $0
                    fitTop()
                }
                .frame(height: topHeight)
            Hairline()
            // The title of the whole section, apart from the views above.
            Text(String(localized: "Progetti").uppercased()).font(.subheadline.weight(.bold)).tracking(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.top, 20).padding(.bottom, 5)
            List(selection: selection) {
                if model.projects.count > Self.filterThreshold {
                    TextField(String(localized: "Filtra progetti"), text: $projectFilter)
                        .textFieldStyle(.roundedBorder).controlSize(.small).selectionDisabled()
                }
                ProjectTree(model: model, filter: projectFilter)
            }
            .listStyle(.sidebar).scrollContentBackground(.hidden)
            Hairline()
            bottomBar
        }
        .background(SidebarMaterial().ignoresSafeArea())
        .task(id: model.revision) { trashCount = (try? model.archive.trashedItems().count) ?? 0 }
        .sheet(isPresented: $creatingClient) {
            NewClientSheet(model: model) { client in
                model.select(.library(.client(client.id)))
            }
        }
    }

    @ViewBuilder
    private var views: some View {
        Label {
            HStack {
                Text(String(localized: "Da classificare"))
                Spacer()
                if model.unclassifiedCount > 0 {
                    Text("\(model.unclassifiedCount)").foregroundStyle(.secondary).monospacedDigit()
                }
            }
        } icon: {
            Image(systemName: "tray")
        }
        .tag(AppModel.SidebarSelection.library(.unclassified))
        Label(String(localized: "Recenti"), systemImage: "clock").tag(AppModel.SidebarSelection.library(.recent))
        Label(String(localized: "Punti chiave"), systemImage: "checkmark.seal").tag(AppModel.SidebarSelection.decisions)
        Label(String(localized: "Importa"), systemImage: "square.and.arrow.down").tag(
            AppModel.SidebarSelection.importer)
        Label {
            HStack {
                Text(String(localized: "Attività"))
                Spacer()
                let count = ActivityCount.badge(model)
                if count > 0 {
                    Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit()
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                }
            }
        } icon: {
            Image(systemName: "gauge.with.dots.needle.67percent")
        }
        .tag(AppModel.SidebarSelection.activity)
        Label(String(localized: "Categorie e tag"), systemImage: "tag").tag(AppModel.SidebarSelection.labels)
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).maxY
            } action: {
                guard !askButtonHidden else { return }
                lastRowBottom = $0
                fitTop()
            }
        if askButtonHidden {
            AskIAGOSidebarRow(model: model) { askButtonHidden = false }
                .onGeometryChange(for: CGFloat.self) {
                    $0.frame(in: .global).maxY
                } action: {
                    lastRowBottom = $0
                    fitTop()
                }
        }
    }

    /// The fixed part as tall as its rows (they follow the sidebar icon size of System Settings).
    private func fitTop() {
        guard let top = topListY, let bottom = lastRowBottom, bottom > top else { return }
        let wanted = bottom - top + 10
        if abs(wanted - topHeight) > 1 { topHeight = wanted }
    }

    /// "＋" for a new project or client on the left, the trash on the right: always there, never in the way.
    private var bottomBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button(String(localized: "Nuovo progetto…"), action: createProject)
                Button(String(localized: "Nuovo cliente…")) { creatingClient = true }
            } label: {
                Image(systemName: "plus").font(.system(size: 13, weight: .medium))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help(String(localized: "Nuovo progetto o cliente"))
            Spacer()
            Button {
                model.select(.trash)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash").font(.system(size: 12))
                    if trashCount > 0 { Text("\(trashCount)").font(.caption).monospacedDigit() }
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5).fill(
                        model.sidebar == .trash ? Color.primary.opacity(0.12) : Color.clear))
            }
            .buttonStyle(.plain).foregroundStyle(model.sidebar == .trash ? .primary : .secondary)
            .help(String(localized: "Cestino"))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

/// The thin line between the parts of the sidebar.
private struct Hairline: View {
    var body: some View {
        Rectangle().fill(Color.primary.opacity(0.09)).frame(height: 0.5).padding(.horizontal, 12)
    }
}

/// The sidebar's translucent background, behind its three parts.
private struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Elenco / Timeline / Decisioni, always at the top left of the content. The global register (sidebar
/// "Decisioni") has no list or timeline, so it shows no picker.
struct ViewModePicker: View {
    @Bindable var model: AppModel

    /// Where the view is: the client, or the stream with its project (ADR-0038).
    @ViewBuilder
    private var scopeTitle: some View {
        switch model.sidebar {
        case .library(.client(let id)):
            if let client = model.client(id) {
                HStack(spacing: 4) {
                    ClientMark(color: client.color)
                    Text(client.name).font(.headline)
                }
            }
        case .library(.stream(let id)):
            if let stream = model.stream(id) {
                HStack(spacing: 5) {
                    Circle().fill(Color.iago(stream.color)).frame(width: 8, height: 8)
                    Text(stream.name).font(.headline)
                    Text("· \(model.project(stream.projectId)?.name ?? "")").foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }
        case .library(.project(let id)):
            // Where the project is: client › project.
            if let project = model.project(id) {
                HStack(spacing: 4) {
                    if let client = model.client(project.clientId) {
                        ClientMark(color: client.color)
                        Text(client.name).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    Text(project.name).font(.headline)
                }
                .layoutPriority(1)
            }
            Spacer(minLength: 8)
            // FR-172/173 and ADR-0046: a project note, an activity, a milestone or a decision on the timeline.
            Menu {
                Button {
                    var draft = NoteDraft(projectID: id)
                    draft.streamIDs = model.scopeStreamIDs
                    model.editingNote = draft
                } label: {
                    Label(String(localized: "Nota"), systemImage: "note.text")
                }
                Divider()
                ForEach(DecisionRow.allKinds, id: \.self) { kind in
                    Button {
                        model.newKeyPoint(kind, projectID: id)
                    } label: {
                        Label(DecisionRow.kindLabel(kind), systemImage: DecisionRow.kindIcon(kind))
                    }
                }
            } label: {
                Label(String(localized: "Aggiungi"), systemImage: "plus.circle")
            }
            .menuStyle(.borderlessButton).fixedSize()
            .help(
                String(
                    localized: "Aggiungi alla timeline del progetto una nota, un'attività, una tappa o una decisione"))
        case .library(.category(let id)):
            if let category = model.categories.first(where: { $0.id == id }) {
                labelTitle(category.name, systemImage: "square.grid.2x2", key: "category:\(id)")
            }
        case .library(.tag(let id)):
            if let tag = model.tags.first(where: { $0.id == id }) {
                labelTitle("#\(tag.name)", systemImage: "tag", key: "tag:\(id)")
            }
        default:
            EmptyView()
        }
    }

    /// A category or a tag across projects, with its pin for "In evidenza".
    private func labelTitle(_ title: String, systemImage: String, key: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(String(localized: "· in tutti i progetti")).foregroundStyle(.secondary)
            Button {
                model.togglePinnedLabel(key)
            } label: {
                Image(systemName: model.isPinnedLabel(key) ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help(
                model.isPinnedLabel(key)
                    ? String(localized: "Togli da «In evidenza»") : String(localized: "Fissa in «In evidenza»"))
        }
        .lineLimit(1)
    }

    private var hasScopeTitle: Bool {
        switch model.sidebar {
        case .library(.client), .library(.stream), .library(.project), .library(.category), .library(.tag): true
        default: false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if model.sidebar != .decisions {
                    Picker(String(localized: "Vista"), selection: $model.viewMode) {
                        Label(String(localized: "Elenco"), systemImage: "list.bullet").tag(AppModel.ViewMode.list)
                        Label(String(localized: "Timeline"), systemImage: "calendar.day.timeline.left").tag(
                            AppModel.ViewMode.timeline)
                        Label(String(localized: "Punti chiave"), systemImage: "checkmark.seal").tag(
                            AppModel.ViewMode.decisions)
                        Label(String(localized: "Grafo"), systemImage: "point.3.connected.trianglepath.dotted").tag(
                            AppModel.ViewMode.graph)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                } else {
                    Label(String(localized: "Tutti i punti chiave"), systemImage: "checkmark.seal").font(.headline)
                }
                Spacer(minLength: 8)
                if case .library = model.sidebar {
                    Menu {
                        Button(String(localized: "Per LLM (Markdown)…")) { model.exporting = .llm }
                        Button(String(localized: "Audio…")) { model.exporting = .audio }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .help(String(localized: "Esporta gli elementi di questa vista"))
                }
            }
            if hasScopeTitle {
                // Second line: where the view is (client, stream) and its actions, never squeezed next to the picker.
                HStack(spacing: 10) {
                    scopeTitle
                    Spacer(minLength: 0)
                }
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 10)
    }
}

private struct ItemList: View {
    @Bindable var model: AppModel

    var body: some View {
        List(model.summaries, selection: $model.selectedItemID) { summary in
            ItemRow(summary: summary, suggestions: model.pendingSuggestions[summary.id] ?? 0).tag(summary.id)
                .contextMenu { ItemContextMenu(model: model, summary: summary) }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                ViewModePicker(model: model)
                FilterBar(model: model)
            }
            .background(.bar)
        }
        .overlay {
            if model.summaries.isEmpty {
                ContentUnavailableView(String(localized: "Nessun elemento"), systemImage: "tray")
            }
        }
    }
}

/// Right click on an item: assign project or category without opening it.
struct ItemContextMenu: View {
    let model: AppModel
    let summary: ItemSummary

    var body: some View {
        Menu(String(localized: "Sposta nel progetto")) {
            Button(String(localized: "Non definito")) { model.assign(summary.id, toProject: nil) }
            Divider()
            ForEach(model.projects) { project in
                Button(project.name) { model.assign(summary.id, toProject: project.id) }
                    .disabled(summary.item.projectId == project.id)
            }
        }
        Menu(String(localized: "Categoria")) {
            Button(String(localized: "Nessuna")) { model.update(summary.id) { $0.categoryId = nil } }
            Divider()
            ForEach(model.categories) { category in
                Button(category.name) { model.update(summary.id) { $0.categoryId = category.id } }
            }
        }
        Divider()
        Button(String(localized: "Sposta nel cestino")) { model.deleteItem(summary.id, .trash) }
    }
}

/// FR-73: title, date, duration, project, category, tags, status icons.
private struct ItemRow: View {
    let summary: ItemSummary
    var suggestions = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if summary.item.type != .call {
                    Image(systemName: ItemIcon.name(summary.item, direction: summary.email?.direction))
                        .foregroundStyle(summary.item.type == .email ? Color.indigo : Color.secondary)
                }
                Text(summary.item.title).font(.headline).lineLimit(1)
                Spacer(minLength: 4)
                SuggestionBadge(count: suggestions)
                if summary.hasActiveJob { ProgressView().controlSize(.mini) }
                if summary.item.status == .error {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        .help(String(localized: "Errore nella trascrizione"))
                }
                if summary.hasAudio {
                    Image(systemName: "waveform").foregroundStyle(.secondary).help(String(localized: "Audio presente"))
                }
                if summary.hasTranscript {
                    Image(systemName: "text.alignleft").foregroundStyle(.secondary).help(
                        String(localized: "Trascritta"))
                }
            }
            HStack(spacing: 6) {
                Text(summary.item.occurredAt, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                if let duration = summary.item.durationSec { Text("· \(Format.duration(duration))") }
                if let project = summary.projectName { Text("· \(project)") }
                if let category = summary.categoryName { Text("· \(category)") }
            }
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if !summary.tags.isEmpty {
                Text(summary.tags.map { "#\($0)" }.joined(separator: " ")).font(.caption).foregroundStyle(.tint)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

enum Format {
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total) s" }
        if total < 3600 { return "\(total / 60) min" }
        return String(format: "%d h %02d min", total / 3600, total / 60 % 60)
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return total >= 3600
            ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
            : String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func bytes(_ count: Int64?) -> String {
        ByteCountFormatter.string(fromByteCount: count ?? 0, countStyle: .file)
    }
}

/// "#bud" or "categoria:sa" in the search field: the matching tags or categories, to open with one click.
private struct LabelSuggestions: View {
    let model: AppModel

    var body: some View {
        let text = model.searchText.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") {
            let needle = String(text.dropFirst())
            ForEach(model.tags.filter { needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) }.prefix(8))
            { tag in
                Button {
                    open(.tag(tag.id))
                } label: {
                    Label("#\(tag.name)", systemImage: "tag")
                }
            }
        } else if let range = text.range(of: "categoria:", options: [.caseInsensitive, .anchored]) {
            let needle = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
            ForEach(model.categories.filter { needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) }) {
                category in
                Button {
                    open(.category(category.id))
                } label: {
                    Label(category.name, systemImage: "square.grid.2x2")
                }
            }
        }
    }

    private func open(_ scope: LibraryScope) {
        model.searchText = ""
        model.select(.library(scope))
    }
}
