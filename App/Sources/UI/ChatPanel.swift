import IAGOIntelligence
import IAGOStore
import SwiftUI

/// "Chiedi" (ADR-0049, FR-121): questions on the project, client or archive in view, answered by the local engine
/// from the user's own content, with numbered sources that open the item at the minute. Conversations are saved for
/// 48 hours unless the user keeps or pins them; reopening one warns when new material may change the answer.
struct ChatPanel: View {
    @Bindable var model: AppModel
    @State private var question = ""
    @State private var conversation: Conversation?
    @State private var turns: [Turn] = []
    @State private var task: Task<Void, Never>?
    @State private var showsList = false
    @State private var confirmingDelete = false
    @State private var conversations: [Conversation] = []
    /// Items of the scope added or changed after the last answer that concern it.
    @State private var newMaterial: Int = 0
    /// A context chosen with "Allarga contesto" for the next conversation, instead of the sidebar's.
    @State private var scopeOverride: SearchScope?
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
    private var scope: SearchScope { conversation?.scope ?? scopeOverride ?? model.chatScope }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if showsList {
                list
            } else {
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
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { focused = true }
        .task(id: model.intelligence.revision) { reloadList() }
        // A new conversation follows the section the user moves to.
        .onChange(of: model.chatScope) { if conversation == nil, turns.isEmpty { scopeOverride = nil } }
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
            iconButton(
                showsList ? "bubble.left" : "clock.arrow.circlepath",
                showsList ? String(localized: "Torna alla conversazione") : String(localized: "Conversazioni")
            ) {
                showsList.toggle()
                reloadList()
            }
            iconButton("square.and.pencil", String(localized: "Nuova conversazione")) { startNew() }
            iconButton("xmark", String(localized: "Chiudi")) { model.showsChat = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: Context

    /// "Contesto": where the answers come from (Cliente › Progetto › Stream, or Tutta la memoria), with
    /// "Allarga contesto" underneath.
    private var contextStrip: some View {
        let everything = scope == .all
        return VStack(alignment: .trailing, spacing: 3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Contesto")).font(.caption2).textCase(.uppercase).tracking(0.7).opacity(0.75)
                Text(contextPath).font(.callout).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .foregroundStyle(everything ? Color.primary : Color.accentColor)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(everything ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(everything ? Color.secondary.opacity(0.2) : Color.accentColor.opacity(0.35))
            )
            .help(Self.levels(scope, model).map { Self.levelName($0, model) }.joined(separator: " › "))
            contextMenu
        }
        .padding(.horizontal, 14).padding(.bottom, 4)
    }

    /// The client's square, the ancestors in regular weight and the current level in semibold.
    private var contextPath: AttributedString {
        let levels = Self.levels(scope, model)
        guard scope != .all else {
            var all = AttributedString("◎ " + Self.levelName(.all, model))
            all.font = .callout.weight(.semibold)
            return all
        }
        var path = AttributedString()
        if case .client(let id)? = levels.first {
            var square = AttributedString("■ ")
            square.foregroundColor = model.client(id)?.color.flatMap(Color.init(hex:)) ?? .secondary
            path += square
        }
        for (index, level) in levels.enumerated() {
            var name = AttributedString(Self.levelName(level, model))
            name.font = .callout.weight(index == levels.count - 1 ? .semibold : .regular)
            path += name
            if index < levels.count - 1 {
                var separator = AttributedString(" › ")
                separator.font = .callout
                path += separator
            }
        }
        return path
    }

    /// "Allarga contesto": the wider levels and, once widened, the section Chiedi was opened from.
    @ViewBuilder
    private var contextMenu: some View {
        let wider = Self.wider(scope, model)
        let origin = model.chatScope
        let back = origin != scope && !wider.contains(origin) ? origin : nil
        if !wider.isEmpty || back != nil {
            Menu {
                if !wider.isEmpty {
                    Section(String(localized: "Allarga a")) {
                        ForEach(wider, id: \.self) { level in
                            Button {
                                change(to: level)
                            } label: {
                                Text(Self.levelName(level, model))
                                Text(Self.levelKind(level))
                            }
                        }
                    }
                }
                if let back {
                    Section(String(localized: "Torna a")) {
                        Button {
                            change(to: back)
                        } label: {
                            Text(Self.levelName(back, model))
                            Text(String(localized: "\(Self.levelKind(back)), dove hai aperto Chiedi"))
                        }
                    }
                }
            } label: {
                // A text link in the accent colour: a borderless menu would ignore the colour.
                HStack(spacing: 3) {
                    Text(back == nil ? String(localized: "Allarga contesto") : String(localized: "Cambia contesto"))
                    Image(systemName: "chevron.down").imageScale(.small)
                }
                .font(.caption).foregroundStyle(Color.accentColor).contentShape(Rectangle())
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .disabled(task != nil)
        }
    }

    /// A new context: before the first question it simply applies; afterwards it opens a new conversation
    /// there and asks the last question again (a conversation keeps the context it was started in).
    private func change(to level: SearchScope) {
        let last = turns.last?.question
        if !turns.isEmpty { startNew() }
        scopeOverride = level
        if let last {
            question = last
            send()
        }
    }

    /// Cliente, Progetto, Stream down to `scope`.
    static func levels(_ scope: SearchScope, _ model: AppModel) -> [SearchScope] {
        switch scope {
        case .all: return [.all]
        case .client: return [scope]
        case .project(let id):
            return (model.project(id)?.clientId.map { [SearchScope.client($0)] } ?? []) + [scope]
        case .stream(let id):
            guard let projectID = model.stream(id)?.projectId else { return [scope] }
            return levels(.project(projectID), model) + [scope]
        }
    }

    /// The levels above `scope`, nearest first, ending with Tutta la memoria.
    static func wider(_ scope: SearchScope, _ model: AppModel) -> [SearchScope] {
        guard scope != .all else { return [] }
        return levels(scope, model).dropLast().reversed() + [.all]
    }

    static func levelName(_ scope: SearchScope, _ model: AppModel) -> String {
        switch scope {
        case .all: String(localized: "Tutta la memoria")
        case .project(let id): model.project(id)?.name ?? ""
        case .client(let id): model.client(id)?.name ?? ""
        case .stream(let id): model.stream(id)?.name ?? ""
        }
    }

    static func levelKind(_ scope: SearchScope) -> String {
        switch scope {
        case .all: String(localized: "Tutti i clienti, i progetti e gli elementi da classificare")
        case .project: String(localized: "Progetto")
        case .client: String(localized: "Cliente")
        case .stream: String(localized: "Stream")
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
                text: $question, axis: .vertical
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
        scopeOverride = nil
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
            (try? await HybridSearch.search(
                last.question, scope: scope, archive: model.archive, embedder: embedder,
                cache: model.intelligence.cache, limit: 60)) ?? []
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
                let sources = try await ChatAnswerer.sources(
                    for: text, scope: scope, archive: model.archive, embedder: model.engine.embedder,
                    cache: model.intelligence.cache)
                let answer = try await ChatAnswerer.answer(text, history: history, sources: sources, engine: engine)
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
