import IAGOStore
import SwiftUI
import UniformTypeIdentifiers
import os

/// Main window (FR-70, reduced for phase 1): sidebar, item list, detail. Files dropped anywhere on the
/// window are imported (FR-30).
struct MainView: View {
    @Bindable var model: AppModel
    @State private var isDropTargeted = false
    /// The floating "Chiedi a IAGO" closed with its X: the entry moves to the sidebar.
    @AppStorage("askButtonHidden") private var askButtonHidden = false
    /// Width of the "Chiedi a IAGO" pane, chosen by dragging its edge.
    @AppStorage("chatWidth") private var chatWidth = 400.0

    var body: some View {
        Group {
            if model.isWide, !isSearching { wideLayout } else { columnsLayout }
        }
        .searchable(
            text: $model.searchText, placement: .toolbar,
            prompt: Text(
                String(
                    localized: "Cerca nell'archivio  ·  #tag  ·  categoria:",
                    comment: "In English the prefix is «category:»"))
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
            ToolbarItem(placement: .navigation) { AppearanceMenu() }
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
            // «Torna su» sits above «Chiedi a IAGO» at a fixed distance, or in its place when it is hidden (ADR-0084).
            VStack(alignment: .trailing, spacing: 10) {
                if !model.showsChat, let backToTop = model.backToTop {
                    BackToTopButton(action: backToTop)
                        .transition(.scale.combined(with: .opacity))
                }
                if !model.showsChat, !askButtonHidden {
                    AskIAGOButton(model: model) { askButtonHidden = true }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.trailing, 22).padding(.bottom, 20)
            .animation(.easeOut(duration: 0.15), value: model.backToTop == nil)
            // Only the floating button animates: an animated split view moved the sidebar under the title bar when
            // «Chiedi a IAGO» opened on a wide view.
            .animation(.easeOut(duration: 0.2), value: model.showsChat)
        }
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
        .sheet(isPresented: $model.composingEmail) {
            NewEmailSheet(model: model, projectID: model.composingEmailProject)
        }
        .sheet(item: $model.importing) { target in ImportSheet(model: model, target: target) }
        .sheet(item: $model.modeIntro) { intro in WorkModeIntroSheet(model: model, intro: intro) }
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
        .sheet(item: $model.newProject) { request in
            NewProjectSheet(model: model, clientID: request.clientID, locksClient: request.locksClient) { project in
                model.select(.library(.project(project.id)))
            }
        }
        .sheet(item: $model.newStreamProject) { project in
            NewStreamSheet(model: model, project: project) { stream in
                model.expandedNodes.insert(project.id)
                model.select(.library(.stream(stream.id)))
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

    private var isSearching: Bool {
        model.showsSearch && !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Sidebar, list and detail: the layout of the library's list and timeline, and of the other places.
    private var columnsLayout: some View {
        // One three-column layout for both views: the inspector-based timeline layout looped in AppKit's
        // constraint pass and crashed the window.
        NavigationSplitView {
            sidebar
        } content: {
            Group {
                if isSearching {
                    SearchResultsView(model: model)
                } else if model.sidebar == .importer {
                    ImportView(model: model)
                } else if model.sidebar == .trash {
                    TrashView(model: model)
                } else if model.sidebar == .activity {
                    ActivityView(model: model)
                } else if model.sidebar == .labels {
                    LabelsBrowser(model: model)
                } else if model.sidebar == .inbox {
                    WorkInbox(model: model)
                } else if model.showsDecisions {
                    DecisionsView(model: model)
                } else if model.showsTimeline {
                    ProjectTimeline(model: model)
                } else {
                    ItemList(model: model)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { backToSearch }
            .background(IAGOColor.page)
            .background(ContentColumnWidth(key: columnKey))
            .navigationSplitViewColumnWidth(min: contentWidth.min, ideal: contentWidth.ideal)
        } detail: {
            // "Chiedi a IAGO" sits next to the detail as a plain pane: the system inspector looped AppKit's
            // constraint pass in this three-column window and crashed it.
            // Both get an exact width, so the detail wraps its text instead of pushing the panel out.
            GeometryReader { geometry in
                let chat = model.showsChat ? ChatPane.width(stored: chatWidth, available: geometry.size.width) : 0
                HStack(spacing: 0) {
                    detail.frame(width: geometry.size.width - chat).clipped()
                    if model.showsChat { chatPane(chat, available: geometry.size.width) }
                }
            }
            .background(IAGOColor.page)
        }
    }

    /// Sidebar and one wide view (kanban, «Riepilogo», map, ADR-0075): what is opened from it shows in an inspector
    /// on the right, closed with ✕ or Esc.
    private var wideLayout: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            GeometryReader { geometry in
                let chat = model.showsChat ? ChatPane.width(stored: chatWidth, available: geometry.size.width) : 0
                let shown = model.hasSelection || model.keepsInspector
                let inspector = shown ? min(480, (geometry.size.width - chat) * 0.45) : 0
                HStack(spacing: 0) {
                    wideContent.safeAreaInset(edge: .top, spacing: 0) { backToSearch }
                        .background(IAGOColor.page)
                        .frame(width: geometry.size.width - chat - inspector).clipped()
                    if shown {
                        inspectorPane.frame(width: inspector)
                            .transition(.move(edge: .trailing))
                    }
                    if model.showsChat { chatPane(chat, available: geometry.size.width) }
                }
            }
            .animation(.easeOut(duration: 0.15), value: model.hasSelection)
        }
    }

    @ViewBuilder
    private var wideContent: some View {
        // «Attività» and «Categorie e tag» have nothing to select: they take the whole space; what they open shows in
        // the inspector or in its own list.
        if model.sidebar == .activity {
            ActivityView(model: model)
        } else if model.sidebar == .labels {
            LabelsBrowser(model: model)
        } else {
            wideViews
        }
    }

    @ViewBuilder
    private var wideViews: some View {
        switch model.viewMode {
        case .board:
            if model.sidebar == .inbox || model.sidebar == .decisions {
                WorkBoard(model: model, scope: .all)
            } else if let scope = model.workScope {
                WorkBoard(model: model, scope: scope)
            }
        case .overview:
            if let scope = model.workScope { WorkOverview(model: model, scope: scope) }
        case .map, .list, .timeline:
            GraphView(model: model)
        }
    }

    private var inspectorPane: some View {
        HStack(spacing: 0) {
            Divider()
            VStack(spacing: 0) {
                // Kept open with nothing in it («Traccia»): no ✕, there is nothing to close.
                if model.hasSelection {
                    HStack {
                        Spacer()
                        Button {
                            model.clearSelection()
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.borderless).keyboardShortcut(.cancelAction)
                        .help(String(localized: "Chiudi il pannello (Esc)"))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    Divider()
                }
                detail
            }
        }
        .background(IAGOColor.panel)
    }

    private func chatPane(_ width: CGFloat, available: CGFloat) -> some View {
        ChatPane(model: model, width: $chatWidth, available: available)
            .frame(width: width)
            .transition(.move(edge: .trailing))
    }

    @ViewBuilder
    private var backToSearch: some View {
        if !model.showsSearch, !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            BackToSearchBar(model: model).iagoBar()
        }
    }

    /// "Nuovo progetto" while viewing a client creates it in that client.
    private var currentClientID: String? {
        if case .library(.client(let id)) = model.sidebar { return id }
        return nil
    }

    private var sidebar: some View {
        Sidebar(model: model) { model.newProject = AppModel.NewProjectRequest(clientID: currentClientID) }
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
        } else if let id = model.proposalsItemID, model.item(id) != nil {
            ItemProposalsPane(model: model, itemID: id).id(id)
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
    /// Which place the middle column's width belongs to (ADR-0087).
    var columnKey: String {
        if isSearching { return "search" }
        let view = model.showsDecisions ? "decisions" : model.showsTimeline ? "timeline" : "list"
        switch model.sidebar {
        case .inbox: return "inbox"
        case .decisions: return "decisions"
        case .importer: return "importer"
        case .activity: return "activity"
        case .labels: return "labels"
        case .trash: return "trash"
        case .library(.unclassified): return "unclassified"
        case .library(.recent): return "recent"
        case .library(.undefinedProject): return "undefined"
        case .library: return "scopes/\(view)"
        case nil: return "none"
        }
    }

    /// Width of the content column for what it shows.
    var contentWidth: (min: CGFloat, ideal: CGFloat) {
        switch model.sidebar {
        case .importer: return (560, 730)
        case .activity, .labels: return (420, 560)
        default:
            if model.sidebar == .inbox { return (360, 620) }
            // «Punti chiave»: the timeline column starts wide enough for its cards.
            if model.showsDecisions { return (440, 600) }
            if model.showsTimeline { return (280, 560) }
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
    /// The next measure may make the fixed part shorter: set when a row comes or goes.
    @State private var allowsShrink = true
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
            // Grey icons, white on the selected row (style A): colour stays on badges, clients and modes. The tint is
            // a row modifier: on the list itself it does nothing.
            List(selection: selection) { Group { views }.listItemTint(.monochrome) }
                .listStyle(.sidebar).scrollDisabled(true).scrollContentBackground(.hidden)
                .onGeometryChange(for: CGFloat.self) {
                    $0.frame(in: .global).minY
                } action: {
                    topListY = $0
                    fitTop()
                }
                .frame(height: topHeight)
            Hairline()
            // «Aggiungi» on the right, above clients and projects, with some room before them.
            HStack(spacing: 6) {
                Spacer(minLength: 6)
                newMenu
            }
            .padding(.leading, 14).padding(.trailing, 10).padding(.top, 14).padding(.bottom, 20)
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
        .background(SidebarMaterial().overlay(IAGOColor.sidebarTint).ignoresSafeArea())
        .onChange(of: askButtonHidden) { allowsShrink = true }
        .task(id: model.revision) { trashCount = (try? model.archive.trashedItems().count) ?? 0 }
        .sheet(isPresented: $creatingClient) {
            NewClientSheet(model: model) { client in
                model.select(.library(.client(client.id)))
            }
        }
    }

    /// «Inbox» first and set apart (ADR-0076), then the items waiting for a project and the other places.
    @ViewBuilder
    private var views: some View {
        WorkInboxSidebarLabel(model: model).tag(AppModel.SidebarSelection.inbox)
        Divider().selectionDisabled().padding(.vertical, 1)
        Label {
            HStack {
                Text(String(localized: "Elementi da classificare"))
                Spacer()
                if model.unclassifiedCount > 0 {
                    Text("\(model.unclassifiedCount)").foregroundStyle(.secondary).monospacedDigit()
                }
            }
        } icon: {
            Image(systemName: "questionmark.folder")
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
        // The tag goes last: after `onGeometryChange` the row was not selectable.
        Label(String(localized: "Categorie e tag"), systemImage: "tag")
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).maxY
            } action: {
                guard !askButtonHidden else { return }
                lastRowBottom = $0
                fitTop()
            }
            .tag(AppModel.SidebarSelection.labels)
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
    /// Grows at once; shrinks only when «Chiedi a IAGO» leaves the list. A measure taken mid-layout (opening
    /// «Punti chiave») was smaller than the rows and cut «Attività» and «Categorie e tag», which stopped responding.
    private func fitTop() {
        guard let top = topListY, let bottom = lastRowBottom, bottom > top else { return }
        let wanted = bottom - top + 10
        if wanted > topHeight + 1 || (allowsShrink && abs(wanted - topHeight) > 1) {
            topHeight = wanted
            allowsShrink = false
        }
    }

    /// «Aggiungi» above the projects: a client or a project, like «Aggiungi» of a project.
    private var newMenu: some View {
        Menu {
            Section(String(localized: "Aggiungi:")) {
                Button {
                    creatingClient = true
                } label: {
                    Label(String(localized: "Cliente…"), systemImage: "person.2")
                }
                Button(action: createProject) {
                    Label(String(localized: "Progetto…"), systemImage: "folder")
                }
            }
        } label: {
            Label(String(localized: "Aggiungi"), systemImage: "plus.circle").font(.callout)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help(String(localized: "Aggiungi un cliente o un progetto"))
    }

    /// «Cestino» alone at the bottom, a row like the views above: always there, never in the way.
    private var bottomBar: some View {
        List(selection: selection) {
            Label {
                HStack {
                    Text(String(localized: "Cestino"))
                    Spacer()
                    if trashCount > 0 {
                        Text("\(trashCount)").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            } icon: {
                Image(systemName: "trash")
            }
            .listItemTint(.monochrome)
            .tag(AppModel.SidebarSelection.trash)
        }
        .listStyle(.sidebar).scrollDisabled(true).scrollContentBackground(.hidden)
        .frame(height: 40)
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

/// The bar on top of every view of the library (ADR-0075, ADR-0076): where the view is, then «Riepilogo» and
/// «Elementi» each on its own, the forms of the history (Timeline, Kanban, Grafo) and on the right «Mostra», what the
/// timeline and the graph contain. A project in «Traccia» has no kanban and no «Mostra». «Punti chiave» in the sidebar
/// has only the list and the kanban.
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
                WorkModePill(model: model, project: project)
            }
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
                Divider()
                Button {
                    model.importing = AppModel.ImportTarget(projectID: id, streamIDs: model.scopeStreamIDs)
                } label: {
                    Label(String(localized: "Importa file ed elementi…"), systemImage: "square.and.arrow.down")
                }
            } label: {
                Label(String(localized: "Aggiungi"), systemImage: "plus.circle")
            }
            .menuStyle(.borderlessButton).fixedSize()
            .help(
                String(
                    localized:
                        "Aggiungi al progetto una nota o un punto chiave, oppure importa audio, documenti, email e trascrizioni"
                ))
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
            if hasScopeTitle {
                // First line: where the view is (client › project, stream) and its actions.
                HStack(spacing: 10) {
                    scopeTitle
                    Spacer(minLength: 0)
                    exportMenu
                }
                .lineLimit(1)
            }
            HStack(spacing: 8) {
                if model.sidebar == .decisions {
                    Label(String(localized: "Tutti i punti chiave"), systemImage: "checkmark.seal").font(.headline)
                    Spacer(minLength: 8)
                    if model.boardAvailable(for: .all) {
                        Picker(String(localized: "Vista"), selection: $model.viewMode) {
                            Label(String(localized: "Elenco"), systemImage: "list.bullet").tag(AppModel.ViewMode.list)
                            Label(String(localized: "Kanban"), systemImage: "rectangle.split.3x1").tag(
                                AppModel.ViewMode.board)
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                } else {
                    forms
                    Spacer(minLength: 8)
                    contentMenu
                    if !hasScopeTitle, case .library = model.sidebar { exportMenu }
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 10)
    }

    private var trackMode: Bool {
        model.workScope != nil && model.workViewsMode(for: model.decisionScope) == .track
    }

    /// «Riepilogo» and «Elementi», each on its own: the page the project opens on and its items; then how to look at
    /// the history. With «Riepilogo» or «Elementi» chosen no form is selected; a click on one goes to it.
    @ViewBuilder
    private var forms: some View {
        if model.workScope != nil {
            single(.overview, String(localized: "Riepilogo"), "list.bullet.clipboard")
                .help(
                    trackMode
                        ? String(localized: "Cosa c'è da fare, cosa tenere d'occhio, le ultime decisioni")
                        : String(localized: "La pagina del progetto: lavoro aperto, scadenze, attese, checklist"))
        }
        single(.list, String(localized: "Elementi"), "doc.on.doc")
            .help(String(localized: "Call, email, documenti e trascrizioni"))
        Divider().frame(height: 18)
        Picker(String(localized: "Vista"), selection: $model.viewMode) {
            Label(String(localized: "Timeline"), systemImage: "calendar.day.timeline.left").tag(
                AppModel.ViewMode.timeline)
            if model.workScope != nil, model.boardAvailable(for: model.decisionScope) {
                Label(String(localized: "Kanban"), systemImage: "rectangle.split.3x1").tag(AppModel.ViewMode.board)
            }
            if model.graphAvailable {
                Label(String(localized: "Grafo"), systemImage: "point.3.connected.trianglepath.dotted").tag(
                    AppModel.ViewMode.map)
            }
        }
        .pickerStyle(.segmented).labelsHidden().fixedSize()
    }

    /// One view as a segmented control of its own, selected when it is the current one.
    private func single(_ mode: AppModel.ViewMode, _ title: String, _ icon: String) -> some View {
        Picker(title, selection: $model.viewMode) {
            Label(title, systemImage: icon).labelStyle(.titleAndIcon).tag(mode)
        }
        .pickerStyle(.segmented).labelsHidden().fixedSize()
    }

    /// «Mostra»: what the timeline and the graph contain. The kanban holds open work only; «Riepilogo» and «Elementi»
    /// are what they are; a project in «Traccia» shows everything.
    @ViewBuilder
    private var contentMenu: some View {
        switch model.viewMode {
        case .board:
            Text(String(localized: "Mostra: Lavoro aperto")).font(.callout).foregroundStyle(.secondary)
                .help(String(localized: "La kanban mostra solo attività, punti da chiarire, rischi e richieste"))
        case .timeline where !trackMode, .map where !trackMode:
            Menu {
                Picker(String(localized: "Mostra"), selection: $model.viewContent) {
                    ForEach(AppModel.ViewContent.allCases, id: \.self) { content in
                        Text(Self.contentName(content)).tag(content)
                    }
                }
                .pickerStyle(.inline).labelsHidden()
            } label: {
                Text(String(localized: "Mostra: \(Self.contentName(model.viewContent))"))
            }
            .menuStyle(.borderlessButton).fixedSize()
            .help(String(localized: "Tutto, solo gli elementi (call, email, documenti, note) o solo i punti chiave"))
        default:
            EmptyView()
        }
    }

    static func contentName(_ content: AppModel.ViewContent) -> String {
        switch content {
        case .all: String(localized: "Tutto")
        case .materials: String(localized: "Elementi")
        case .keyPoints: String(localized: "Punti chiave")
        }
    }

    private var exportMenu: some View {
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

/// «Modalità Gestisci ▾» next to the project's name (ADR-0074, ADR-0076): the mode, with its sign and colour; a click
/// opens the two modes explained and, in «Traccia», the switch of the graph.
struct WorkModePill: View {
    let model: AppModel
    let project: Project
    @State private var open = false

    var body: some View {
        let mode = project.workMode ?? .manage
        Button {
            open.toggle()
        } label: {
            // Colour only in the mode's sign (style A).
            HStack(spacing: 4) {
                Image(systemName: WorkModeText.icon(mode)).foregroundStyle(WorkModeText.color(mode))
                Text(WorkModeText.fullTitle(mode))
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).fixedSize()
        .help(String(localized: "Modalità del progetto: cambiala quando vuoi, non si perde nulla"))
        .popover(isPresented: $open, arrowEdge: .bottom) {
            WorkModeMenu(model: model, project: project) { open = false }
        }
    }
}

/// The pill's popover: the two modes with what each one is, then the switches of the project.
struct WorkModeMenu: View {
    let model: AppModel
    let project: Project
    let done: () -> Void

    var body: some View {
        let mode = project.workMode ?? .manage
        VStack(alignment: .leading, spacing: 4) {
            ForEach(WorkMode.allCases, id: \.self) { option in
                Button {
                    model.chooseProjectWorkMode(project.id, option)
                    done()
                } label: {
                    WorkModeChoice(mode: option, selected: option == mode)
                }
                .buttonStyle(.plain)
            }
            if mode == .track {
                Divider().padding(.vertical, 4)
                Text(String(localized: "In questo progetto")).font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary).textCase(.uppercase).padding(.horizontal, 8)
                Toggle(
                    String(localized: "Mostra il Grafo"),
                    isOn: Binding(
                        get: { model.graphShown(projectID: project.id) },
                        set: { model.setGraphShown($0, projectID: project.id) })
                )
                .toggleStyle(.switch).controlSize(.small).padding(.horizontal, 8)
            }
        }
        .padding(8)
        .frame(width: 380)
    }
}

/// One mode as a choice: sign, name, «semplice e veloce» or «completa», and what it gives.
struct WorkModeChoice: View {
    let mode: WorkMode
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: WorkModeText.icon(mode)).foregroundStyle(WorkModeText.color(mode))
                .font(.system(size: 15)).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(WorkModeText.fullTitle(mode)).font(.body.weight(.semibold))
                    Text(WorkModeText.level(mode)).font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    Spacer(minLength: 0)
                    if selected { Image(systemName: "checkmark").foregroundStyle(.secondary) }
                }
                Text(WorkModeText.explanation(mode)).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.primary.opacity(0.06) : .clear))
        .contentShape(Rectangle())
    }
}

private struct ItemList: View {
    @Bindable var model: AppModel

    var body: some View {
        List(model.summaries, selection: $model.selectedItemID) { summary in
            ItemRow(summary: summary, suggestions: model.pendingSuggestions[summary.id] ?? 0).tag(summary.id)
                .contextMenu { ItemContextMenu(model: model, summary: summary) }
        }
        // The page's grey shows through (no full white in light).
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                ViewModePicker(model: model)
                FilterBar(model: model)
            }
            .iagoBar()
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
        } else if let range = text.range(of: "categoria:", options: [.caseInsensitive, .anchored])
            ?? text.range(of: "category:", options: [.caseInsensitive, .anchored])
        {
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
