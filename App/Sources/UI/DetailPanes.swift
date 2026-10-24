import IAGOStore
import SwiftUI

/// A decision in the detail pane: the whole text and description, where it comes from, and how it evolved
/// (the decisions it replaced and the one that replaced it, FR-151), newest first.
struct DecisionDetailView: View {
    let model: AppModel
    let decisionID: String
    @State private var summary: DecisionSummary?
    @State private var chain: [DecisionSummary] = []
    @State private var related: [DecisionSummary] = []
    @State private var chainName: String?
    @State private var naming = false
    @State private var nameDraft = ""

    var body: some View {
        ScrollView {
            if let summary {
                content(summary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ContentUnavailableView(String(localized: "Decisione non trovata"), systemImage: "checkmark.seal")
            }
        }
        .task(id: model.revision) { load() }
    }

    @ViewBuilder
    private func content(_ summary: DecisionSummary) -> some View {
        let decision = summary.decision
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(DecisionRow.kindLabel(decision.kind)).font(.callout.weight(.bold))
                    .foregroundStyle(DecisionRow.tint(decision.kind))
                Label(DecisionRow.label(decision), systemImage: DecisionRow.icon(decision))
                    .font(.callout.weight(.semibold)).foregroundStyle(DecisionRow.color(decision))
                Text(decision.decidedAt.formatted(date: .long, time: .shortened)).foregroundStyle(.secondary)
                Spacer()
                if decision.kind == .action, decision.status == .active {
                    Button(String(localized: "Segna come fatta")) { model.setDecisionStatus(decision.id, .done) }
                    Button(String(localized: "Diventa decisione…")) {
                        model.editingDecision = .superseding(summary, kind: .decision)
                    }
                } else if decision.kind == .action, decision.status == .done {
                    Button(String(localized: "Riapri")) { model.setDecisionStatus(decision.id, .active) }
                }
                Button(String(localized: "Modifica…")) { model.editingDecision = DecisionDraft(summary) }
            }
            ViaClaudeBadge(model: model, entity: .decision, id: decision.id)
            Text(decision.text).font(.title2.weight(.semibold)).textSelection(.enabled)
                .strikethrough(decision.status == .superseded || decision.status == .cancelled, color: .secondary)
                .fixedSize(horizontal: false, vertical: true)
            facts(summary)
            if let description = decision.notes, !description.isEmpty {
                SectionBox(String(localized: "Descrizione"), systemImage: "text.alignleft", tint: .secondary) {
                    MarkdownText(markdown: description).textSelection(.enabled)
                }
            }
            source(summary)
            evolution(summary)
            if chain.count <= 1, summary.decision.status == .active, !related.isEmpty { others(summary) }
        }
    }

    private func facts(_ summary: DecisionSummary) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text(String(localized: "Progetto")).foregroundStyle(.secondary)
                Text(summary.projectName ?? String(localized: "Da classificare"))
            }
            if !summary.streamIDs.isEmpty {
                GridRow {
                    Text(String(localized: "Stream")).foregroundStyle(.secondary)
                    Text(summary.streamIDs.compactMap { model.stream($0)?.name }.joined(separator: ", "))
                }
            }
            if !summary.people.isEmpty {
                GridRow {
                    Text(String(localized: "Persone")).foregroundStyle(.secondary)
                    Text(summary.people.joined(separator: ", "))
                }
            }
            if !summary.tags.isEmpty {
                GridRow {
                    Text(String(localized: "Tag")).foregroundStyle(.secondary)
                    Text(summary.tags.map { "#\($0)" }.joined(separator: " ")).foregroundStyle(.tint)
                }
            }
        }
        .font(.callout)
    }

    @ViewBuilder
    private func source(_ summary: DecisionSummary) -> some View {
        let decision = summary.decision
        switch summary.sourceState {
        case .available:
            Button {
                model.openDecisionSource(summary)
            } label: {
                Label(
                    decision.sourceNoteId != nil
                        ? String(localized: "Apri la nota da cui è nata")
                        : decision.sourceAtSec.map {
                            String(localized: "Ascolta da \(Format.clock($0)) · \(summary.sourceTitle ?? "")")
                        } ?? String(localized: "Apri la fonte · \(summary.sourceTitle ?? "")"),
                    systemImage: decision.sourceAtSec != nil ? "play.circle.fill" : "arrow.up.right.square")
            }
            .buttonStyle(.bordered)
        case .trashed:
            Label(String(localized: "La fonte è nel cestino"), systemImage: "trash").foregroundStyle(.orange)
        case .deleted:
            Label(String(localized: "La fonte è stata eliminata: la decisione resta"), systemImage: "link.badge.plus")
                .foregroundStyle(.orange)
        case .none:
            EmptyView()
        }
    }

    /// The chain of decisions, newest at the top; the open one is highlighted, the others can be opened.
    private func evolution(_ summary: DecisionSummary) -> some View {
        SectionBox(String(localized: "Evoluzione"), systemImage: "arrow.triangle.branch", tint: .green) {
            if chain.count > 1 { nameLine }
            if chain.count <= 1 {
                Text(String(localized: "Per ora è l'unica versione: non ne supera altre e nessuna l'ha superata."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            if summary.decision.status == .active {
                Button {
                    var draft = DecisionDraft(projectID: summary.decision.projectId)
                    draft.supersedesID = summary.id
                    draft.streamIDs = summary.streamIDs
                    draft.people = summary.people
                    draft.tags = summary.tags
                    model.editingDecision = draft
                } label: {
                    Label(String(localized: "Supera con una nuova decisione…"), systemImage: "plus.circle")
                }
                .buttonStyle(.link)
            }
            if !summary.supersedesAll.isEmpty || !summary.supersededByAll.isEmpty { links(summary) }
            if chain.count > 1 { chainList }
        }
    }

    /// Optional name of the chain, given by the user.
    private var nameLine: some View {
        HStack(spacing: 8) {
            if let chainName {
                Text("«\(chainName)»").font(.headline)
                Button(String(localized: "Rinomina…")) { startNaming() }.buttonStyle(.link)
            } else {
                Button {
                    startNaming()
                } label: {
                    Label(String(localized: "Dai un nome a questa catena…"), systemImage: "character.cursor.ibeam")
                }
                .buttonStyle(.link)
            }
        }
        .alert(String(localized: "Nome della catena di decisioni"), isPresented: $naming) {
            TextField(String(localized: "Es. Colore del logo"), text: $nameDraft)
            Button(String(localized: "Salva")) { saveName(nameDraft) }
            if chainName != nil {
                Button(String(localized: "Togli il nome"), role: .destructive) { saveName(nil) }
            }
            Button(String(localized: "Annulla"), role: .cancel) {}
        } message: {
            Text(String(localized: "Facoltativo: aiuta a riconoscere di cosa parla questa evoluzione."))
        }
    }

    private func startNaming() {
        nameDraft = chainName ?? ""
        naming = true
    }

    private func saveName(_ name: String?) {
        model.perform { try model.archive.setChainName(name, decisionID: decisionID) }
        load()
    }

    /// No evolution yet: the other active decisions of the same stream (or project), to say which one this
    /// replaces, or which one replaces it.
    private func others(_ summary: DecisionSummary) -> some View {
        let streams = summary.streamIDs.compactMap { model.stream($0)?.name }
        let title =
            streams.isEmpty
            ? String(localized: "Altre decisioni sul progetto")
            : streams.count == 1
                ? String(localized: "Altre decisioni sullo stream «\(streams[0])»")
                : String(localized: "Altre decisioni sugli stream \(streams.joined(separator: ", "))")
        return SectionBox(title, systemImage: "checkmark.seal", tint: .yellow) {
            Text(
                String(
                    localized:
                        "Se questa decisione ne sostituisce una, collegale: quella vecchia diventa superata e nasce l'evoluzione."
                )
            )
            .font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(related) { other in
                    relatedRow(other, current: summary.decision)
                }
            }
        }
    }

    /// ADR-0052: what the open entry supersedes and what supersedes it, each one openable.
    private func links(_ summary: DecisionSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !summary.supersedesAll.isEmpty { linkGroup(String(localized: "Supera:"), summary.supersedesAll) }
            if !summary.supersededByAll.isEmpty {
                linkGroup(String(localized: "Superata da:"), summary.supersededByAll)
            }
        }
        .font(.callout)
    }

    private func linkGroup(_ title: String, _ entries: [Decision]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).foregroundStyle(.secondary).fixedSize()
            VStack(alignment: .leading, spacing: 2) {
                ForEach(entries) { entry in
                    Button {
                        model.selectedDecisionID = entry.id
                    } label: {
                        Label(entry.text, systemImage: DecisionRow.icon(entry)).lineLimit(2)
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private func relatedRow(_ other: DecisionSummary, current: Decision) -> some View {
        let older = other.decision.decidedAt <= current.decidedAt
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal").foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(other.decision.text).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                Text(other.decision.decidedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.selectedDecisionID = other.id }
            Spacer(minLength: 8)
            if older {
                Button(String(localized: "Questa la supera")) { link(newer: current.id, older: other.id) }
                    .help(String(localized: "La decisione aperta sostituisce questa, che diventa superata"))
                    .fixedSize()
            } else {
                Button(String(localized: "È superata da questa")) { link(newer: other.id, older: current.id) }
                    .help(String(localized: "Questa decisione, più recente, sostituisce quella aperta"))
                    .fixedSize()
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.08)))
    }

    private func link(newer: String, older: String) {
        model.perform { try model.archive.addSupersede(newer: newer, older: older) }
        model.reload()
        load()
    }

    private var chainList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(chain.enumerated()), id: \.element.id) { index, entry in
                    let isCurrent = entry.id == decisionID
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Image(systemName: DecisionRow.icon(entry.decision))
                                .foregroundStyle(DecisionRow.color(entry.decision))
                            if index < chain.count - 1 {
                                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 2).frame(minHeight: 18)
                            }
                        }
                        .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.decision.text).fontWeight(isCurrent ? .semibold : .regular)
                                .strikethrough(entry.decision.status != .active, color: .secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(
                                "\(entry.decision.decidedAt.formatted(date: .abbreviated, time: .omitted)) · \(DecisionRow.label(entry.decision))"
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 10)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6).padding(.top, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6).fill(isCurrent ? Color.accentColor.opacity(0.12) : .clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { if !isCurrent { model.selectedDecisionID = entry.id } }
                }
            }
        }
    }

    private func load() {
        summary = try? model.archive.decisionSummary(decisionID)
        guard let summary else { return }
        // Every entry linked to this one (ADR-0052).
        let ids = ((try? model.archive.decisionChain(of: summary.id)) ?? []).map(\.id)
        // Newest at the top.
        chain = ids.reversed().compactMap { try? model.archive.decisionSummary($0) }
        chainName = try? model.archive.chainName(of: decisionID)
        related = chain.count <= 1 ? ((try? model.archive.relatedDecisions(of: decisionID)) ?? []) : []
    }
}

/// A note in the detail pane: the whole text, what it belongs to, its attachments and actions.
struct NoteDetailView: View {
    let model: AppModel
    let noteID: String
    @State private var note: Note?
    @State private var deleting = false

    var body: some View {
        ScrollView {
            if let note {
                content(note).padding(20).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ContentUnavailableView(String(localized: "Nota non trovata"), systemImage: "note.text")
            }
        }
        .task(id: model.revision) { note = try? model.archive.note(noteID) }
        .confirmationDialog(String(localized: "Eliminare la nota?"), isPresented: $deleting) {
            Button(String(localized: "Elimina"), role: .destructive) {
                model.perform { try model.archive.deleteNote(noteID) }
                model.selectedNoteID = nil
            }
        }
    }

    @ViewBuilder
    private func content(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Label(
                    note.input == .voice ? String(localized: "Nota vocale") : String(localized: "Nota"),
                    systemImage: note.input == .voice ? "mic.circle.fill" : "note.text"
                )
                .font(.callout.weight(.semibold)).foregroundStyle(.orange)
                Text(note.notedAt.formatted(date: .long, time: .shortened)).foregroundStyle(.secondary)
                Spacer()
                PromoteNoteButton(model: model, note: note)
                Button(String(localized: "Modifica…")) { model.editingNote = NoteDraft(note) }
                Menu {
                    Button(String(localized: "Elimina…"), role: .destructive) { deleting = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
            ViaClaudeBadge(model: model, entity: .note, id: note.id)
            owner(note)
            MarkdownText(markdown: note.body).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            NoteAttachments(model: model, noteID: note.id)
        }
    }

    /// The item the note is about (it opens), or the project.
    @ViewBuilder
    private func owner(_ note: Note) -> some View {
        if let itemID = note.itemId, let item = model.item(itemID) {
            Button {
                model.selectedItemID = itemID
            } label: {
                Label(String(localized: "Su «\(item.title)»"), systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.link)
        } else if let projectID = note.projectId, let project = model.project(projectID) {
            Label(String(localized: "Nota del progetto «\(project.name)»"), systemImage: "folder")
                .foregroundStyle(.secondary)
        }
    }
}
