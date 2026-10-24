import IAGOStore
import SwiftUI

/// Editable metadata of an item (FR-40): title, date and time, project, category, tags. Used by the
/// item view and by the post-recording panel. Changes are saved as they are made.
struct MetadataEditor: View {
    let model: AppModel
    let item: Item
    var compact = false

    @State private var title = ""
    @State private var date = Date()
    @State private var askingProjectName = false
    @State private var streamIDs: [String] = []
    /// A move to another project that would remove the item's streams, waiting for confirmation.
    @State private var pendingProject: String??

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(String(localized: "Titolo"), text: $title)
                .font(compact ? .title3 : .title).textFieldStyle(.plain)
                .onSubmit(saveTitle)
                .onChange(of: title) { scheduleTitleSave() }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text(String(localized: "Data")).foregroundStyle(.secondary)
                    DatePicker("", selection: $date).labelsHidden()
                        .onChange(of: date) { _, value in
                            guard abs(value.timeIntervalSince(item.occurredAt)) > 1 else { return }
                            model.update(item.id) { $0.occurredAt = value }
                        }
                }
                GridRow {
                    Text(String(localized: "Progetto")).foregroundStyle(.secondary)
                    Picker("", selection: projectBinding) {
                        Text(String(localized: "Non definito")).tag(String?.none)
                        ForEach(model.projects) { Text($0.name).tag(Optional($0.id)) }
                        Divider()
                        Text(
                            model.projects.isEmpty
                                ? String(localized: "Crea progetto…") : String(localized: "Nuovo progetto…")
                        )
                        .tag(Optional(Self.newProjectTag))
                    }
                    .labelsHidden().frame(maxWidth: 260)
                }
                if let projectID = item.projectId {
                    GridRow(alignment: .top) {
                        Text(String(localized: "Stream")).foregroundStyle(.secondary)
                        StreamChooser(
                            model: model, projectID: projectID,
                            selection: Binding(
                                get: { streamIDs },
                                set: { ids in
                                    streamIDs = ids
                                    model.setStreams(ids, for: item.id)
                                }))
                    }
                }
                GridRow {
                    Text(String(localized: "Categoria")).foregroundStyle(.secondary)
                    CategoryPicker(model: model, selection: item.categoryId) { categoryBinding.wrappedValue = $0 }
                }
                GridRow(alignment: .top) {
                    Text(String(localized: "Tag")).foregroundStyle(.secondary)
                    TagEditor(model: model, itemID: item.id)
                }
            }
        }
        .onAppear(perform: sync)
        .onChange(of: item) { sync() }
        .task(id: model.revision) { streamIDs = (try? model.archive.streamIDs(itemID: item.id)) ?? [] }
        .alert(
            String(localized: "Spostare in un altro progetto?"),
            isPresented: Binding(get: { pendingProject != nil }, set: { if !$0 { pendingProject = nil } })
        ) {
            Button(String(localized: "Sposta")) {
                if let target = pendingProject { model.update(item.id) { $0.projectId = target } }
                pendingProject = nil
            }
            Button(String(localized: "Annulla"), role: .cancel) { pendingProject = nil }
        } message: {
            Text(
                String(
                    localized:
                        "L'elemento perderà gli stream del progetto attuale: \(streamIDs.compactMap { model.stream($0)?.name }.joined(separator: ", "))."
                ))
        }
        .sheet(isPresented: $askingProjectName) {
            NewProjectSheet(model: model) { project in model.update(item.id) { $0.projectId = project.id } }
        }
    }

    private static let newProjectTag = "__new__"

    private var projectBinding: Binding<String?> {
        Binding(
            get: { item.projectId },
            set: { value in
                if value == Self.newProjectTag {
                    askingProjectName = true
                } else if value != item.projectId, !streamIDs.isEmpty {
                    pendingProject = .some(value)
                } else {
                    model.update(item.id) { $0.projectId = value }
                }
            })
    }

    private var categoryBinding: Binding<String?> {
        Binding(get: { item.categoryId }, set: { value in model.update(item.id) { $0.categoryId = value } })
    }

    private func sync() {
        if title != item.title { title = item.title }
        if abs(date.timeIntervalSince(item.occurredAt)) > 1 { date = item.occurredAt }
    }

    @State private var titleSave: Task<Void, Never>?

    private func scheduleTitleSave() {
        titleSave?.cancel()
        titleSave = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            saveTitle()
        }
    }

    private func saveTitle() {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != item.title else { return }
        model.update(item.id) { $0.title = value }
    }
}

/// Tags with textual autocomplete (FR-101): prefix matches first, then near matches ("rodmap" →
/// "roadmap"), so duplicates are avoided.
struct TagEditor: View {
    let model: AppModel
    let itemID: String
    @State private var input = ""
    @State private var current: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 6) {
                ForEach(current, id: \.self) { tag in
                    HStack(spacing: 3) {
                        Button {
                            // A click on the tag opens every item with it, in every project.
                            if let found = model.tags.first(where: {
                                $0.name.caseInsensitiveCompare(tag) == .orderedSame
                            }) {
                                model.select(.library(.tag(found.id)))
                            }
                        } label: {
                            Text("#\(tag)")
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "Mostra tutti gli elementi con #\(tag)"))
                        Button {
                            setTags(current.filter { $0 != tag })
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                }
                TextField(String(localized: "Aggiungi tag"), text: $input)
                    .textFieldStyle(.roundedBorder).frame(width: 160)
                    .onSubmit { add(input) }
            }
            let suggestions =
                (try? model.archive.tagSuggestions(for: input, limit: 6))?.map(\.name)
                .filter { name in !current.contains { TagNormalizer.normalize($0) == TagNormalizer.normalize(name) } }
                ?? []
            if !input.isEmpty, !suggestions.isEmpty {
                HStack(spacing: 6) {
                    Text(String(localized: "Esistenti:")).font(.caption).foregroundStyle(.secondary)
                    ForEach(suggestions, id: \.self) { name in
                        Button("#\(name)") { add(name) }.buttonStyle(.link).font(.caption)
                    }
                }
            }
        }
        .task(id: model.revision) {
            current = (try? model.archive.tags(for: itemID).map(\.name)) ?? []
        }
    }

    private func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        input = ""
        guard !trimmed.isEmpty else { return }
        setTags(current + [trimmed])
    }

    private func setTags(_ names: [String]) {
        current = names
        model.setTags(names, for: itemID)
    }
}

/// Wraps its children on several lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    /// Space between wrapped lines; the same as `spacing` unless given.
    var lineSpacing: CGFloat?

    /// Without a proposed width (minimum/ideal size queries) the layout reports the widest child, not the
    /// sum of all children: otherwise its minimum width grows with every tag and the split view keeps
    /// re-laying out the window (AppKit aborts on that loop).
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return arrange(subviews, width: width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, origin) in arrange(subviews, width: bounds.width).origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + (lineSpacing ?? spacing)
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return (origins, CGSize(width: maxX, height: y + lineHeight))
    }
}
