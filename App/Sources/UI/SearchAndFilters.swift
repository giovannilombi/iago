import IAGOStore
import SwiftUI

/// Filters and sorting under the view picker (FR-71, FR-72): uniform chips that show the current value,
/// each opening a popover (tags stay open so several can be ticked), and an always-visible "Azzera".
struct FilterBar: View {
    @Bindable var model: AppModel

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 8) {
            FilterChip(title: categoryTitle, systemImage: "folder", active: model.filter.categoryID != nil) {
                OptionList(
                    options: [(String?.none, String(localized: "Tutte"))]
                        + model.categories.map { (Optional($0.id), $0.name) },
                    selection: $model.filter.categoryID)
            }
            if !scopeStreams.isEmpty {
                FilterChip(
                    title: streamTitle, systemImage: "circle.grid.2x1", active: !model.filter.streamIDs.isEmpty
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(scopeStreams) { stream in
                            OptionCheckRow(label: stream.name, checked: model.filter.streamIDs.contains(stream.id)) {
                                if model.filter.streamIDs.contains(stream.id) {
                                    model.filter.streamIDs.remove(stream.id)
                                } else {
                                    model.filter.streamIDs.insert(stream.id)
                                }
                            }
                        }
                        Divider()
                        Text(String(localized: "Mostra gli elementi in almeno uno degli stream scelti"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            FilterChip(
                title: tagTitle, systemImage: "number", active: !model.filter.tags.isEmpty,
                asSheet: model.tags.count > TagPicker.popoverLimit
            ) {
                TagPicker(model: model)
            }
            FilterChip(
                title: typeTitle, systemImage: "square.stack",
                active: model.filter.type != nil || model.filter.status != .all
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    OptionList(
                        options: [
                            (Item.Kind?.none, String(localized: "Tutti i tipi")),
                            (Optional(Item.Kind.call), String(localized: "Call")),
                            (Optional(Item.Kind.document), String(localized: "Documenti")),
                            (Optional(Item.Kind.email), String(localized: "Email")),
                        ], selection: $model.filter.type)
                    Divider()
                    OptionList(
                        options: [
                            (AppModel.LibraryFilter.Status.all, String(localized: "Qualsiasi stato")),
                            (.audioOnly, String(localized: "Solo audio")),
                            (.transcribed, String(localized: "Trascritti")),
                        ], selection: $model.filter.status)
                }
            }
            FilterChip(
                title: periodTitle, systemImage: "calendar",
                active: model.filter.from != nil || model.filter.to != nil
            ) {
                DateRangeEditor(model: model)
            }
            FilterChip(title: sortTitle, systemImage: "arrow.up.arrow.down", active: false) {
                OptionList(
                    options: [
                        (AppModel.LibraryFilter.Sort.date, String(localized: "Data")),
                        (.title, String(localized: "Titolo")),
                        (.duration, String(localized: "Durata")),
                        (.project, String(localized: "Progetto")),
                    ], selection: $model.filter.sort)
            }
            .help(String(localized: "Ordina"))
            ChipButton(
                title: String(localized: "Azzera"), systemImage: "eraser", active: false, showsChevron: false,
                destructive: true
            ) {
                let sort = model.filter.sort
                model.filter = AppModel.LibraryFilter()
                model.filter.sort = sort
            }
            .disabled(!model.filter.isActive)
            .help(String(localized: "Togli tutti i filtri"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.top, 2).padding(.bottom, 10)
    }

    /// Streams of the project being viewed (none elsewhere: a stream scope already filters).
    private var scopeStreams: [ProjectStream] {
        if case .library(.project(let id)) = model.sidebar { return model.streams(of: id) }
        return []
    }

    private var streamTitle: String {
        let names = scopeStreams.filter { model.filter.streamIDs.contains($0.id) }.map(\.name)
        switch names.count {
        case 0: return String(localized: "Stream")
        case 1: return names[0]
        default: return String(localized: "Stream · \(names.count)")
        }
    }

    private var categoryTitle: String {
        model.categories.first { $0.id == model.filter.categoryID }?.name ?? String(localized: "Categoria")
    }

    private var tagTitle: String {
        let tags = model.filter.tags.sorted()
        switch tags.count {
        case 0: return String(localized: "Tag")
        case 1: return "#\(tags[0])"
        default: return String(localized: "Tag · \(tags.count)")
        }
    }

    private var typeTitle: String {
        var parts: [String] = []
        switch model.filter.type {
        case .call: parts.append(String(localized: "Call"))
        case .document: parts.append(String(localized: "Documenti"))
        case .email: parts.append(String(localized: "Email"))
        case nil: break
        }
        switch model.filter.status {
        case .audioOnly: parts.append(String(localized: "solo audio"))
        case .transcribed: parts.append(String(localized: "trascritti"))
        case .all: break
        }
        return parts.isEmpty ? String(localized: "Tipo") : parts.joined(separator: ", ")
    }

    private var periodTitle: String {
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        switch (model.filter.from, model.filter.to) {
        case (nil, nil): return String(localized: "Periodo")
        case (let from?, nil): return String(localized: "dal \(from.formatted(style))")
        case (nil, let to?): return String(localized: "fino al \(to.formatted(style))")
        case (let from?, let to?): return "\(from.formatted(style)) – \(to.formatted(style))"
        }
    }

    private var sortTitle: String {
        switch model.filter.sort {
        case .date: String(localized: "Data")
        case .title: String(localized: "Titolo")
        case .duration: String(localized: "Durata")
        case .project: String(localized: "Progetto")
        }
    }
}

/// One filter: icon + current value + chevron; opens a popover, or a sheet when the list is long.
struct FilterChip<Content: View>: View {
    let title: String
    let systemImage: String
    let active: Bool
    var asSheet = false
    @ViewBuilder let content: () -> Content
    @State private var open = false

    var body: some View {
        ChipButton(title: title, systemImage: systemImage, active: active) { open.toggle() }
            .popover(isPresented: asSheet ? .constant(false) : $open, arrowEdge: .bottom) {
                content().padding(12).frame(minWidth: 200, alignment: .leading)
            }
            .sheet(isPresented: asSheet ? $open : .constant(false)) {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                    HStack {
                        Spacer()
                        Button(String(localized: "Fatto")) { open = false }.keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
            }
    }
}

/// The shared chip box: same shape for every filter, sorting and "Azzera".
struct ChipButton: View {
    let title: String
    let systemImage: String
    let active: Bool
    var showsChevron = true
    var destructive = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.caption)
                Text(title).lineLimit(1).truncationMode(.tail).frame(maxWidth: 160, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                if showsChevron {
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).opacity(0.6)
                }
            }
            .font(.callout)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(
                Capsule().fill(active ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
            )
            .overlay(Capsule().stroke(border))
            .foregroundStyle(active ? Color.accentColor : Color.primary)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var border: Color {
        if destructive { return Color.red.opacity(isEnabled ? 0.8 : 0.4) }
        return active ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.25)
    }
}

/// Single choice as a checkmark list (stays consistent with the tag picker).
struct OptionList<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let (value, label) = options[index]
                OptionCheckRow(label: label, checked: selection == value) { selection = value }
            }
        }
    }
}

struct OptionCheckRow: View {
    let label: String
    let checked: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").font(.caption.weight(.semibold)).opacity(checked ? 1 : 0)
                    .frame(width: 12)
                Text(label).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? Color.secondary.opacity(0.15) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Several tags at once (all must be present). Up to `popoverLimit` tags: a checklist in a popover that
/// stays open while ticking; beyond that, a sheet with every tag laid out as toggle chips and a search field.
private struct TagPicker: View {
    static let popoverLimit = 8
    @Bindable var model: AppModel
    @State private var query = ""

    var body: some View {
        if model.tags.isEmpty {
            Text(String(localized: "Nessun tag")).foregroundStyle(.secondary)
        } else if model.tags.count <= Self.popoverLimit {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(model.tags) { tag in
                        OptionCheckRow(label: "#\(tag.name)", checked: isOn(tag)) { toggle(tag) }
                    }
                }
                footer
            }
            .frame(width: 240)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "Filtra per tag")).font(.title3).bold()
                TextField(String(localized: "Cerca tag"), text: $query).textFieldStyle(.roundedBorder)
                ScrollView {
                    FlowLayout(spacing: 6) {
                        ForEach(visible) { tag in
                            Button {
                                toggle(tag)
                            } label: {
                                Text("#\(tag.name)").padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(
                                            isOn(tag) ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.10))
                                    )
                                    .overlay(
                                        Capsule().stroke(
                                            isOn(tag) ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.25))
                                    )
                                    .foregroundStyle(isOn(tag) ? Color.accentColor : Color.primary)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 280)
                footer
            }
            .frame(width: 520)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text(String(localized: "Mostra elementi con tutti i tag scelti"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "Nessuno")) { model.filter.tags.removeAll() }
                    .buttonStyle(.link).font(.caption)
                    .disabled(model.filter.tags.isEmpty)
            }
        }
    }

    private func isOn(_ tag: Tag) -> Bool { model.filter.tags.contains(tag.name) }

    private func toggle(_ tag: Tag) {
        if isOn(tag) { model.filter.tags.remove(tag.name) } else { model.filter.tags.insert(tag.name) }
    }

    private var visible: [Tag] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? model.tags : model.tags.filter { $0.name.lowercased().contains(q) }
    }
}

private struct DateRangeEditor: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                String(localized: "Dal"),
                isOn: Binding(get: { model.filter.from != nil }, set: { model.filter.from = $0 ? Date() : nil }))
            if model.filter.from != nil {
                DatePicker(
                    "", selection: Binding(get: { model.filter.from ?? Date() }, set: { model.filter.from = $0 }),
                    displayedComponents: .date
                )
                .labelsHidden()
            }
            Toggle(
                String(localized: "Al"),
                isOn: Binding(get: { model.filter.to != nil }, set: { model.filter.to = $0 ? Date() : nil }))
            if model.filter.to != nil {
                DatePicker(
                    "", selection: Binding(get: { model.filter.to ?? Date() }, set: { model.filter.to = $0 }),
                    displayedComponents: .date
                )
                .labelsHidden()
            }
        }
        .frame(width: 200)
    }
}

/// Where and what the search looks in: the project it started from or the whole archive, and one kind of
/// content (transcripts, notes, documents, decisions) or all of them.
private struct SearchScopeBar: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon(model.searchScope))
                    .foregroundStyle(.secondary)
                Text(scopeTitle).font(.headline).lineLimit(1)
                Spacer(minLength: 4)
                Menu {
                    ForEach(scopes, id: \.self) { scope in
                        Button {
                            model.searchScope = scope
                        } label: {
                            Label(title(scope), systemImage: icon(scope))
                        }
                        .disabled(scope == model.searchScope)
                    }
                } label: {
                    Text(String(localized: "Cambia ambito"))
                }
                .menuStyle(.borderlessButton).fixedSize().font(.callout)
            }
            FlowLayout(spacing: 6) {
                sourceChip(nil, String(localized: "Tutto"), "square.grid.2x2")
                sourceChip(.transcript, String(localized: "Trascrizioni"), "text.bubble")
                sourceChip(.note, String(localized: "Note"), "note.text")
                sourceChip(.document, String(localized: "Documenti"), "doc.text")
                sourceChip(.summary, String(localized: "Sintesi"), "text.alignleft")
                sourceChip(.decision, String(localized: "Decisioni"), "checkmark.seal")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(resultCount).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var scopeTitle: String { title(model.searchScope) }

    /// The scope the search started from and the levels around it: stream → project → client → everything.
    private var scopes: [SearchScope] {
        var result: [SearchScope] = []
        var projectID: String?
        switch model.searchOriginScope {
        case .stream(let id):
            result.append(.stream(id))
            projectID = model.stream(id)?.projectId
        case .project(let id): projectID = id
        case .client(let id): result.append(.client(id))
        case .all, .projects: break
        }
        if let projectID {
            result.append(.project(projectID))
            if let client = model.project(projectID)?.clientId { result.append(.client(client)) }
        }
        result.append(.all)
        return result
    }

    private func title(_ scope: SearchScope) -> String {
        switch scope {
        case .all: return String(localized: "Ricerca in tutto l'archivio")
        case .client(let id): return String(localized: "Ricerca nel cliente «\(model.client(id)?.name ?? "")»")
        case .project(let id): return String(localized: "Ricerca nel progetto «\(projectName(id) ?? "")»")
        case .projects(let ids): return String(localized: "Ricerca in \(ids.count) progetti")
        case .stream(let id):
            let stream = model.stream(id)
            return String(
                localized:
                    "Ricerca nello stream «\(stream?.name ?? "")» di «\(projectName(stream?.projectId ?? "") ?? "")»")
        }
    }

    private func icon(_ scope: SearchScope) -> String {
        switch scope {
        case .all: "globe"
        case .client: "building.2"
        case .project, .projects: "folder"
        case .stream: "point.3.connected.trianglepath.dotted"
        }
    }

    private var resultCount: String {
        let count = model.searchHits.count
        return count == 1 ? String(localized: "1 risultato") : String(localized: "\(count) risultati")
    }

    private func projectName(_ id: String) -> String? { model.projects.first { $0.id == id }?.name }

    private func sourceChip(_ source: SearchHit.Source?, _ title: String, _ icon: String) -> some View {
        ChipButton(title: title, systemImage: icon, active: model.searchSource == source, showsChevron: false) {
            model.searchSource = source
        }
    }
}

/// Search results by passage (FR-71): grouped by item, each passage opens the item at that point.
struct SearchResultsView: View {
    @Bindable var model: AppModel

    var body: some View {
        let groups = Dictionary(grouping: model.searchHits.filter { $0.itemID != nil }) { $0.itemID! }
        let order = model.searchHits.compactMap(\.itemID).reduce(into: [String]()) {
            if !$0.contains($1) { $0.append($1) }
        }
        let decisionHits = model.searchHits.filter { $0.source == .decision }
        List(selection: Binding(get: { model.selectedItemID }, set: { model.selectedItemID = $0 })) {
            if !decisionHits.isEmpty {
                Section(String(localized: "Decisioni")) {
                    ForEach(decisionHits) { hit in
                        Button {
                            model.openHit(hit)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: icon(hit.source)).foregroundStyle(.green).frame(width: 16)
                                highlighted(hit.snippet).lineLimit(3)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            ForEach(order, id: \.self) { itemID in
                Section(model.item(itemID)?.title ?? "") {
                    ForEach(groups[itemID] ?? []) { hit in
                        Button {
                            model.openHit(hit)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: icon(hit.source)).foregroundStyle(.secondary).frame(width: 16)
                                if let at = hit.atSec {
                                    // Teams' minutes are not the audio's (ADR-0078).
                                    Text(Format.clock(at)).monospacedDigit()
                                        .foregroundStyle(
                                            hit.alternate == "teams" ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint)
                                        )
                                        .frame(width: 52, alignment: .leading)
                                }
                                highlighted(hit.snippet).lineLimit(3)
                                if let other = hit.alternate {
                                    Text(String(localized: "nella trascrizione \(ItemDetailView.sourceName(other))"))
                                        .font(.caption2).foregroundStyle(.blue)
                                        .help(
                                            String(
                                                localized:
                                                    "Trovato solo nell'altra trascrizione della call: aprendolo si apre quella scheda"
                                            ))
                                }
                                if hit.byMeaning {
                                    Text(String(localized: "per significato")).font(.caption2).foregroundStyle(.indigo)
                                        .help(
                                            String(
                                                localized: "Trovato per il senso della domanda, anche con altre parole")
                                        )
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                SearchScopeBar(model: model)
                if model.engine.embedder == nil {
                    HStack {
                        Text(
                            String(
                                localized:
                                    "Ricerca per parole. Con il modello di ricerca locale (0,35 GB) trovi anche i passaggi che dicono la stessa cosa con altre parole."
                            )
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(String(localized: "Scarica…")) {
                            model.settingsPane = .engine
                            model.openSettings?()
                        }
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 4)
                }
            }
            .iagoBar()
        }
        .overlay {
            if model.searchHits.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            }
        }
    }

    private func icon(_ source: SearchHit.Source) -> String {
        switch source {
        case .transcript: "text.bubble"
        case .note: "note.text"
        case .document: "doc.text"
        case .decision: "checkmark.seal"
        case .summary: "text.alignleft"
        }
    }

    /// `«match»` → bold.
    private func highlighted(_ snippet: String) -> Text {
        var result = Text("")
        var bold = false
        var current = ""
        for character in snippet {
            if character == "«" || character == "»" {
                result =
                    result
                    + (bold
                        ? Text(current).bold().foregroundColor(.primary) : Text(current).foregroundColor(.secondary))
                current = ""
                bold = character == "«"
            } else {
                current.append(character)
            }
        }
        return result + (bold ? Text(current).bold() : Text(current).foregroundColor(.secondary))
    }
}
