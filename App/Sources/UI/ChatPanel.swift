import IAGOEngine
import IAGOIntelligence
import IAGOStore
import SwiftUI

/// "Chiedi" (ADR-0049, FR-121): questions on the project, client or archive in view, answered by the local engine
/// from the user's own content, with numbered sources that open the item at the minute. Conversations are saved for
/// 48 hours unless the user keeps or pins them; reopening one warns when new material may change the answer.
struct ChatPanel: View {
    @Bindable var model: AppModel
    /// Over the whole window: the conversations in a column, the conversation in the middle (ADR-0092).
    var fullWindow = false
    // The conversation lives in the model (`ChatState`), so it survives the pane moving or closing.
    private var question: String {
        get { model.chat.question }
        nonmutating set { model.chat.question = newValue }
    }
    private var conversation: Conversation? {
        get { model.chat.conversation }
        nonmutating set { model.chat.conversation = newValue }
    }
    private var turns: [Turn] {
        get { model.chat.turns }
        nonmutating set { model.chat.turns = newValue }
    }
    private var task: Task<Void, Never>? {
        get { model.chat.task }
        nonmutating set { model.chat.task = newValue }
    }
    private var showsList: Bool {
        get { model.chat.showsList }
        nonmutating set { model.chat.showsList = newValue }
    }
    @State private var confirmingDelete = false
    @State private var conversations: [Conversation] = []
    private var newMaterial: Int {
        get { model.chat.newMaterial }
        nonmutating set { model.chat.newMaterial = newValue }
    }
    private var chosenScope: SearchScope? {
        get { model.chat.chosenScope }
        nonmutating set { model.chat.chosenScope = newValue }
    }
    /// «Aggiungi progetti» or «Restringi contesto» open.
    @State private var picker: ContextPicker.Mode?
    @FocusState private var focused: Bool

    struct Turn: Identifiable {
        let id = UUID()
        var question: String
        var answer: String?
        var sources: [ChatSource] = []
        var cited: [Int] = []
        var failure: String?
        var model: String?
        var askedAt = Date()
    }

    /// The scope of the open conversation, or the chosen or sidebar one for a new conversation.
    private var scope: SearchScope { conversation?.scope ?? chosenScope ?? model.chatScope }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if fullWindow {
                HStack(spacing: 0) {
                    list.frame(width: 260)
                    Divider()
                    conversationView.frame(maxWidth: 760).frame(maxWidth: .infinity)
                }
            } else if showsList {
                list
            } else {
                conversationView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { focused = true }
        .task(id: model.intelligence.revision) { reloadList() }
    }

    /// Context, notices, the questions and answers, and the field to ask.
    private var conversationView: some View {
        VStack(alignment: .leading, spacing: 0) {
            contextStrip
            banners
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if turns.isEmpty { intro }
                        ForEach(turns) { turn in turnView(turn).id(turn.id) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                }
                .onChange(of: turns.last?.answer) {
                    if let last = turns.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            composer
        }
    }

    // MARK: Header and banners

    /// Gemini-like: the name, then quiet icons for history, a new conversation and closing.
    private var header: some View {
        HStack(spacing: 10) {
            Text(String(localized: "Chiedi a IAGO")).font(.headline)
            Spacer()
            if let conversation, !showsList {
                iconButton(
                    conversation.pinned ? "pin.fill" : "pin",
                    conversation.pinned
                        ? String(localized: "Togli dalle fissate") : String(localized: "Fissa in alto (e conserva)")
                ) {
                    model.perform {
                        try model.archive.setConversationKept(
                            conversation.id, keep: conversation.keep, pinned: !conversation.pinned)
                    }
                    refresh(conversation.id)
                }
            }
            iconButton("magnifyingglass", String(localized: "Passa alla ricerca semplice")) { model.openSearch() }
            iconButton(
                model.chatFullWindow ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                model.chatFullWindow ? String(localized: "Riduci a pannello") : String(localized: "A tutta finestra")
            ) {
                model.chatFullWindow.toggle()
            }
            if !fullWindow {
                iconButton(
                    showsList ? "bubble.left" : "clock.arrow.circlepath",
                    showsList ? String(localized: "Torna alla conversazione") : String(localized: "Conversazioni")
                ) {
                    showsList.toggle()
                    reloadList()
                }
            }
            iconButton("square.and.pencil", String(localized: "Nuova conversazione")) { startNew() }
            iconButton("xmark", String(localized: "Chiudi")) { model.showsChat = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: Context

    /// "Contesto" (ADR-0091): the projects the answers come from, as tiles (✕ takes one out when there are several),
    /// whether it follows the open section or was chosen, and «Cambia contesto».
    private var contextStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(String(localized: "Contesto")).font(.caption2).textCase(.uppercase).tracking(0.7).opacity(0.75)
                Spacer(minLength: 4)
                if chosenScope != nil {
                    Label(String(localized: "Scelto da te: resta anche cambiando sezione"), systemImage: "pin")
                        .foregroundStyle(.orange)
                } else {
                    Text(String(localized: "Segue la sezione aperta")).foregroundStyle(.secondary)
                }
            }
            .font(.caption2).lineLimit(1)
            FlowLayout(spacing: 6) {
                ForEach(chips, id: \.self) { chip in contextChip(chip) }
            }
            contextMenu
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.16)))
        .padding(.horizontal, 14).padding(.bottom, 4)
        .popover(item: $picker, arrowEdge: .leading) { mode in
            ContextPicker(model: model, mode: mode, start: Self.projectIDs(scope, model)) { ids in
                picker = nil
                change(to: .chosen(ids))
            } cancel: {
                picker = nil
            }
        }
    }

    /// The tiles of the context: one per project, or the client, the stream, or the whole memory.
    private var chips: [SearchScope] {
        if case .projects(let ids) = scope {
            let alive = ids.filter { model.project($0) != nil }
            return alive.isEmpty ? [.all] : alive.map { .project($0) }
        }
        return [scope]
    }

    private func contextChip(_ chip: SearchScope) -> some View {
        let removable = chips.count > 1
        return HStack(spacing: 5) {
            switch chip {
            case .all:
                Image(systemName: "globe").imageScale(.small)
            case .client(let id):
                RoundedRectangle(cornerRadius: 2).fill(Color.iago(model.client(id)?.color)).frame(width: 8, height: 8)
            case .project(let id):
                RoundedRectangle(cornerRadius: 2).fill(Color.iago(model.client(model.project(id)?.clientId)?.color))
                    .frame(width: 8, height: 8)
            case .stream(let id):
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.iago(model.client(model.project(model.stream(id)?.projectId)?.clientId)?.color))
                    .frame(width: 8, height: 8)
            case .projects: EmptyView()
            }
            Text(chipName(chip)).lineLimit(1)
            if removable, case .project(let id) = chip {
                Button {
                    change(
                        to: .chosen(
                            chips.compactMap { if case .project(let other) = $0, other != id { other } else { nil } }))
                } label: {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 14, height: 14).contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(task != nil)
                .help(String(localized: "Togli «\(chipName(chip))» dal contesto"))
            }
        }
        .font(.callout)
        .padding(.leading, 8).padding(.trailing, removable ? 4 : 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.accentColor.opacity(chip == .all ? 0.06 : 0.14)))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.accentColor.opacity(0.3)))
        .help(Self.levels(chip, model).map { Self.levelName($0, model) }.joined(separator: " › "))
    }

    /// A stream shows its project too; a client is all its projects.
    private func chipName(_ chip: SearchScope) -> String {
        switch chip {
        case .stream(let id):
            [model.project(model.stream(id)?.projectId)?.name, model.stream(id)?.name].compactMap { $0 }
                .joined(separator: " › ")
        case .client(let id): String(localized: "\(model.client(id)?.name ?? ""), tutti i progetti")
        default: Self.levelName(chip, model)
        }
    }

    /// «Cambia contesto»: add projects, narrow them, the whole memory, or back to following the section.
    private var contextMenu: some View {
        let ids = Self.projectIDs(scope, model)
        let canNarrow = scope == .all || ids.count > 1
        return Menu {
            Button {
                picker = .add
            } label: {
                Text(String(localized: "Aggiungi progetti…"))
                Text(String(localized: "Spunta altri progetti da includere"))
            }
            Button {
                picker = .narrow
            } label: {
                Text(String(localized: "Restringi contesto…"))
                Text(
                    canNarrow
                        ? String(localized: "Togli la spunta ai progetti da escludere")
                        : String(localized: "Serve più di un progetto: con uno solo non c'è da restringere"))
            }
            .disabled(!canNarrow)
            Button {
                change(to: .all)
            } label: {
                Text(String(localized: "Contesto globale"))
                Text(String(localized: "Tutta la memoria, tutti i progetti"))
            }
            .disabled(scope == .all)
            Divider()
            Button {
                follow()
            } label: {
                Text(String(localized: "Segui la sezione aperta"))
                Text(String(localized: "Il contesto cambia con la barra laterale"))
            }
            .disabled(chosenScope == nil && conversation == nil)
        } label: {
            // A text link in the accent colour: a borderless menu would ignore the colour.
            HStack(spacing: 3) {
                Text(String(localized: "Cambia contesto"))
                Image(systemName: "chevron.down").imageScale(.small)
            }
            .font(.caption.weight(.medium)).foregroundStyle(Color.accentColor).contentShape(Rectangle())
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .disabled(task != nil)
    }

    /// A new context, kept until the user changes it: before the first question it simply applies; afterwards it
    /// opens a new conversation there and asks the last question again (a conversation keeps its context).
    private func change(to level: SearchScope) {
        let last = turns.last?.question
        if !turns.isEmpty || conversation != nil { startNew() }
        chosenScope = level
        if let last {
            question = last
            send()
        }
    }

    /// Back to the context of the open section.
    private func follow() {
        if !turns.isEmpty || conversation != nil { startNew() }
        chosenScope = nil
    }

    /// The projects of a context: what «Aggiungi progetti» and «Restringi contesto» start from (everything for the
    /// whole memory when narrowing is handled by the picker).
    static func projectIDs(_ scope: SearchScope, _ model: AppModel) -> [String] {
        switch scope {
        case .all: []
        case .project(let id): [id]
        case .projects(let ids): ids
        case .client(let id): model.projects.filter { $0.clientId == id }.map(\.id)
        case .stream(let id): model.stream(id).map { [$0.projectId] } ?? []
        }
    }

    /// Cliente, Progetto, Stream down to `scope`.
    static func levels(_ scope: SearchScope, _ model: AppModel) -> [SearchScope] {
        switch scope {
        case .all, .projects: return [scope]
        case .client: return [scope]
        case .project(let id):
            return (model.project(id)?.clientId.map { [SearchScope.client($0)] } ?? []) + [scope]
        case .stream(let id):
            guard let projectID = model.stream(id)?.projectId else { return [scope] }
            return levels(.project(projectID), model) + [scope]
        }
    }

    static func levelName(_ scope: SearchScope, _ model: AppModel) -> String {
        switch scope {
        case .all: String(localized: "Tutta la memoria")
        case .project(let id): model.project(id)?.name ?? ""
        case .client(let id): model.client(id)?.name ?? ""
        case .stream(let id): model.stream(id)?.name ?? ""
        case .projects(let ids):
            ids.count <= 3
                ? ListFormatter.localizedString(byJoining: ids.compactMap { model.project($0)?.name })
                : String(localized: "\(ids.count) progetti")
        }
    }

    static func levelKind(_ scope: SearchScope) -> String {
        switch scope {
        case .all: String(localized: "Tutti i clienti, i progetti e gli elementi da classificare")
        case .project: String(localized: "Progetto")
        case .client: String(localized: "Cliente")
        case .stream: String(localized: "Stream")
        case .projects: String(localized: "Progetti scelti")
        }
    }

    private func iconButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 26, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var banners: some View {
        if let conversation {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: conversation.keep ? "checkmark.circle" : "clock")
                    if !conversation.keep, let expires = conversation.expiresAt {
                        Text(
                            String(
                                localized:
                                    "Conversazione temporanea: si cancella il \(expires.formatted(date: .abbreviated, time: .shortened))."
                            ))
                    } else {
                        Text(String(localized: "Conversazione conservata: resta finché non la elimini."))
                    }
                }
                HStack(spacing: 8) {
                    if !conversation.keep {
                        Button(String(localized: "Conserva"), systemImage: "tray.and.arrow.down") {
                            model.perform { try model.archive.setConversationKept(conversation.id, keep: true) }
                            refresh(conversation.id)
                        }
                    }
                    Button(String(localized: "Elimina"), systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                }
                .controlSize(.small)
            }
            .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08))
            .confirmationDialog(
                String(localized: "Eliminare questa conversazione?"), isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Elimina"), role: .destructive) {
                    model.perform { try model.archive.deleteConversation(conversation.id) }
                    startNew()
                    reloadList()
                }
                Button(String(localized: "Annulla"), role: .cancel) {}
            } message: {
                Text(String(localized: "Domande e risposte vengono cancellate subito. Le note salvate restano."))
            }
        }
        if newMaterial > 0, task == nil {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(
                    String(
                        localized:
                            "Nuovo materiale aggiunto (\(newMaterial)) dopo l'ultima risposta: potrebbe essere parziale."
                    ))
                Spacer()
                Button(String(localized: "Chiedi di nuovo")) { askAgain() }.controlSize(.small)
            }
            .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
        }
    }

    private var list: some View {
        List {
            if conversations.isEmpty {
                Text(
                    String(
                        localized:
                            "Nessuna conversazione. Le conversazioni restano 48 ore, a meno che tu non le conservi.")
                )
                .foregroundStyle(.secondary)
            }
            ForEach(conversations) { entry in
                Button {
                    open(entry)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if entry.pinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
                            Text(entry.title).fontWeight(.semibold).lineLimit(2)
                        }
                        HStack(spacing: 4) {
                            Text(Self.scopeName(entry.scope, model))
                            Text("· \(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            if entry.keep {
                                Text(String(localized: "· conservata"))
                            } else if let expires = entry.expiresAt {
                                Text(
                                    String(
                                        localized:
                                            "· fino al \(expires.formatted(date: .abbreviated, time: .shortened))"))
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(entry.pinned ? String(localized: "Togli dalle fissate") : String(localized: "Fissa in alto"))
                    {
                        model.perform {
                            try model.archive.setConversationKept(entry.id, keep: entry.keep, pinned: !entry.pinned)
                        }
                        reloadList()
                    }
                    if !entry.keep {
                        Button(String(localized: "Conserva")) {
                            model.perform { try model.archive.setConversationKept(entry.id, keep: true) }
                            reloadList()
                        }
                    }
                    Button(String(localized: "Elimina"), role: .destructive) {
                        model.perform { try model.archive.deleteConversation(entry.id) }
                        if conversation?.id == entry.id { startNew() }
                        reloadList()
                    }
                }
            }
        }
    }

    /// A rounded field like Gemini's, with the round send button inside.
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                scope == .all
                    ? String(localized: "Chiedi su tutta la memoria")
                    : String(localized: "Chiedi su \(Self.levelName(scope, model))"),
                text: Bindable(model.chat).question, axis: .vertical
            )
            .textFieldStyle(.plain).lineLimit(1...6).focused($focused)
            .onSubmit(send)
            .padding(.vertical, 6)
            if task != nil {
                Button {
                    task?.cancel()
                    task = nil
                    model.intelligence.chatBusy = false
                } label: {
                    Image(systemName: "stop.fill").font(.system(size: 11)).foregroundStyle(.white)
                        .frame(width: 28, height: 28).background(Circle().fill(Color.primary.opacity(0.75)))
                }
                .buttonStyle(.plain).help(String(localized: "Ferma"))
            } else {
                let empty = question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(empty ? Color.secondary.opacity(0.35) : IAGOBrand.green))
                }
                .buttonStyle(.plain).disabled(empty)
                .keyboardShortcut(.return, modifiers: .command)
                .help(String(localized: "Invia (⌘↩)"))
            }
        }
        .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.secondary.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.secondary.opacity(0.18)))
        .padding(.horizontal, 14).padding(.bottom, 14).padding(.top, 6)
    }

    static func scopeName(_ scope: SearchScope, _ model: AppModel) -> String {
        switch scope {
        case .all: String(localized: "· tutta la memoria")
        case .project(let id): "· " + (model.project(id)?.name ?? "")
        case .client(let id): "· " + (model.client(id)?.name ?? "")
        case .stream(let id): "· " + (model.stream(id)?.name ?? "")
        case .projects: "· " + levelName(scope, model)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Ciao, cosa vuoi sapere?")).font(.title2.weight(.semibold))
            Text(
                "Rispondo con i contenuti di \(Text(scope == .all ? String(localized: "tutta la memoria") : Self.levelName(scope, model)).bold()) e ti mostro le fonti, con il minuto della call."
            )
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(
                    [
                        String(localized: "Cosa abbiamo deciso sul contributo?"),
                        String(localized: "Chi deve mandare il modulo?"),
                        String(localized: "Riassumi l'ultima call"),
                    ], id: \.self
                ) { example in
                    Button {
                        question = example
                        send()
                    } label: {
                        Text(example).font(.callout).padding(.horizontal, 12).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
            Group {
                if model.engine.activeModel == nil {
                    Text(String(localized: "Serve un motore locale: alla prima domanda ti spiego come averlo."))
                } else if model.engine.activeModel?.id == "qwen3.5-4b" {
                    Text(
                        String(
                            localized: "Con il motore più leggero le risposte possono sbagliare: controlla le fonti."))
                }
                if model.engine.embedder == nil {
                    Text(String(localized: "Senza il modello di ricerca cerco solo per parole."))
                }
                Text(String(localized: "Le conversazioni restano 48 ore, a meno che tu non le conservi."))
            }
            .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private func turnView(_ turn: Turn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer(minLength: 40)
                Text(turn.question).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.secondary.opacity(0.14)))
                    .textSelection(.enabled)
            }
            if let failure = turn.failure {
                Text(failure).foregroundStyle(.red).font(.callout)
            } else if let answer = turn.answer {
                HStack(alignment: .top, spacing: 10) {
                    IAGOMark(size: 22)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LocalizedStringKey(answer)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
                        if !turn.sources.isEmpty { sourcesView(turn) }
                        // Nothing cited here: the answer may be in a wider context.
                        if turn.cited.isEmpty, turn.id == turns.last?.id, scope != .all, task == nil {
                            contextMenu
                        }
                        HStack(spacing: 12) {
                            if case .project(let projectID) = scope {
                                Button {
                                    save(turn, projectID: projectID)
                                } label: {
                                    Label(String(localized: "Salva come nota"), systemImage: "note.text.badge.plus")
                                }
                                .buttonStyle(.plain).foregroundStyle(.secondary)
                            }
                            if let name = turn.model.flatMap({ id in
                                (model.engine.activeModel?.id == id ? model.engine.activeModel?.name : nil) ?? id
                            }) {
                                Text("\(name) · \(turn.askedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .font(.caption)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    IAGOMark(size: 22)
                    ProgressView().controlSize(.small)
                    Text(String(localized: "Cerco nelle fonti…")).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Sources as compact rows that wrap: number and title; a click opens the item at the minute.
    private func sourcesView(_ turn: Turn) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(turn.sources.filter { turn.cited.isEmpty || turn.cited.contains($0.number) }) { source in
                Button {
                    open(source)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(source.number)").font(.caption2.weight(.bold)).monospacedDigit()
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Circle().fill(IAGOBrand.yellow.opacity(0.35)))
                        Text(
                            available(source)
                                ? label(source) : String(localized: "\(label(source)) (non più disponibile)")
                        )
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .font(.caption).padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                    .foregroundStyle(available(source) ? .primary : .secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!available(source))
            }
        }
    }

    private func available(_ source: ChatSource) -> Bool {
        if let decisionID = source.decisionID { return (try? model.archive.decision(decisionID)) ?? nil != nil }
        if let noteID = source.noteID, source.itemID == nil { return (try? model.archive.note(noteID)) ?? nil != nil }
        if let itemID = source.itemID { return model.item(itemID).map { $0.trashedAt == nil } ?? false }
        return false
    }

    private func label(_ source: ChatSource) -> String {
        let date = source.date.formatted(date: .abbreviated, time: .omitted)
        switch source.kind {
        case .call: return "\(source.title) · \(date)" + (source.atSec.map { " · \(Format.clock($0))" } ?? "")
        case .email: return String(localized: "Email «\(source.title)» · \(date)")
        case .document: return String(localized: "Documento «\(source.title)» · \(date)")
        case .note: return String(localized: "Nota del \(date)")
        case .decision: return String(localized: "Decisione: \(source.title) · \(date)")
        }
    }

    private func open(_ source: ChatSource) {
        if let decisionID = source.decisionID {
            model.selectedDecisionID = decisionID
        } else if let noteID = source.noteID, source.itemID == nil {
            model.selectedNoteID = noteID
        } else if let itemID = source.itemID {
            if let at = source.atSec { model.pendingSeek = (itemID, at) }
            model.selectedItemID = itemID
        }
    }

    // MARK: Conversations

    private func reloadList() { conversations = (try? model.archive.conversations()) ?? [] }

    private func startNew() {
        task?.cancel()
        conversation = nil
        turns = []
        newMaterial = 0
        showsList = false
        focused = true
    }

    private func refresh(_ id: String) {
        conversation = (try? model.archive.conversations())?.first { $0.id == id }
        reloadList()
    }

    private func open(_ entry: Conversation) {
        task?.cancel()
        conversation = entry
        turns = ((try? model.archive.conversationTurns(entry.id)) ?? []).map { turn in
            let sources = ChatAnswerer.decode(turn.sources)
            return Turn(
                question: turn.question, answer: turn.answer, sources: sources,
                cited: ChatAnswerer.citations(in: turn.answer, sources: sources), model: turn.model,
                askedAt: turn.askedAt)
        }
        showsList = false
        Task { await checkNewMaterial() }
    }

    /// New items of the scope after the last answer; with the search model, only those about the last question.
    private func checkNewMaterial() async {
        newMaterial = 0
        guard let last = turns.last,
            let changed = try? model.archive.changedSince(last.askedAt, scope: scope)
        else { return }
        let total = changed.items.count + changed.notes + changed.decisions
        guard total > 0 else { return }
        guard let embedder = model.engine.embedder else {
            newMaterial = total
            return
        }
        let hits =
            (try? await EngineLane.$interactive.withValue(true) {
                try await EngineLane.$preempts.withValue(false) {
                    try await HybridSearch.search(
                        last.question, scope: scope, archive: model.archive, embedder: embedder,
                        cache: model.intelligence.cache, limit: 60)
                }
            }) ?? []
        let fresh = Set(changed.items)
        newMaterial = Set(hits.compactMap(\.itemID).filter(fresh.contains)).count + changed.decisions
    }

    private func askAgain() {
        guard let last = turns.last?.question else { return }
        question = last
        newMaterial = 0
        send()
    }

    // MARK: Asking

    private func send() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, task == nil, let engine = model.engine.engine(for: .chat) else { return }
        question = ""
        let history = turns.compactMap { turn in turn.answer.map { (question: turn.question, answer: $0) } }
        turns.append(Turn(question: text))
        let index = turns.count - 1
        let scope = self.scope
        model.intelligence.chatBusy = true
        task = Task {
            defer {
                task = nil
                model.intelligence.chatBusy = false
            }
            do {
                // The chat goes first in the engine lane: background work waits or is interrupted (ADR-0069).
                let (sources, answer) = try await EngineLane.$interactive.withValue(true) {
                    let sources = try await ChatAnswerer.sources(
                        for: text, scope: scope, archive: model.archive, embedder: model.engine.embedder,
                        cache: model.intelligence.cache)
                    return (
                        sources, try await ChatAnswerer.answer(text, history: history, sources: sources, engine: engine)
                    )
                }
                guard !Task.isCancelled, index < turns.count else { return }
                turns[index].sources = sources
                turns[index].answer = answer
                turns[index].cited = ChatAnswerer.citations(in: answer, sources: sources)
                turns[index].model = engine.modelID
                turns[index].askedAt = Date()
                let encoded = ChatAnswerer.encode(sources)
                if let conversation {
                    model.perform {
                        try model.archive.addTurn(
                            to: conversation.id, question: text, answer: answer, sources: encoded, model: engine.modelID
                        )
                    }
                    refresh(conversation.id)
                } else {
                    conversation = try model.archive.startConversation(
                        scope: scope, question: text, answer: answer, sources: encoded, model: engine.modelID)
                    reloadList()
                }
            } catch is CancellationError {
                if index < turns.count { turns[index].failure = String(localized: "Risposta fermata.") }
            } catch {
                if index < turns.count { turns[index].failure = ErrorText.describe(error) }
            }
        }
    }

    private func save(_ turn: Turn, projectID: String) {
        guard let answer = turn.answer else { return }
        let sources = turn.sources.filter { turn.cited.contains($0.number) }.map { "[\($0.number)] \(label($0))" }
        let body =
            "**Domanda:** \(turn.question)\n\n\(answer)"
            + (sources.isEmpty ? "" : "\n\n**Fonti**\n" + sources.map { "- \($0)" }.joined(separator: "\n"))
        model.perform { try model.archive.addNote(itemID: nil, projectID: projectID, body: body) }
        model.reload()
    }
}
