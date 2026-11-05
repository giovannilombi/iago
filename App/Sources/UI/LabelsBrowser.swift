import IAGOStore
import SwiftUI

/// "Categorie e tag" (ADR-0090): one page in three columns. On the left the categories and the tags in two folding
/// boxes (tags by use, with a search that picks one or more); in the middle the items with the chosen category and all
/// the chosen tags, in every project; on the right the item's card. The widths are the user's, for this section only.
struct LabelsBrowser: View {
    @Bindable var model: AppModel
    @State private var counts: (categories: [String: Int], tags: [String: Int]) = ([:], [:])
    @State private var categoryID: String?
    /// In the order they were chosen.
    @State private var tagIDs: [String] = []
    @State private var query = ""
    @State private var summaries: [ItemSummary] = []
    @State private var categoriesOpen = LabelsLayout.flag("labels.categoriesOpen")
    @State private var tagsOpen = LabelsLayout.flag("labels.tagsOpen")
    @State private var labelsWidth = LabelsLayout.number("labels.width.labels")
    @State private var listShare = LabelsLayout.number("labels.width.list")
    @State private var dragStart: Double?
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let labels = LabelsLayout.labels(labelsWidth, total: geometry.size.width)
            let rest = geometry.size.width - labels
            let list = LabelsLayout.list(listShare, rest: rest)
            HStack(spacing: 0) {
                labelsColumn.frame(width: labels)
                handle {
                    labelsWidth = LabelsLayout.clampLabels(($0 ?? labels), total: geometry.size.width)
                    LabelsLayout.save(labelsWidth, "labels.width.labels")
                } current: {
                    labels
                }
                itemList.frame(width: list)
                handle {
                    listShare = LabelsLayout.clampList(($0 ?? list), rest: rest) / rest
                    LabelsLayout.save(listShare, "labels.width.list")
                } current: {
                    list
                }
                detail.frame(maxWidth: .infinity)
            }
        }
        .background(IAGOColor.page)
        .task(id: model.revision) {
            counts = (try? model.archive.labelCounts()) ?? ([:], [:])
            reloadItems()
        }
        .onChange(of: categoryID) { reloadItems() }
        .onChange(of: tagIDs) { reloadItems() }
    }

    private func reloadItems() {
        summaries = (try? model.archive.summaries(categoryID: categoryID, tagIDs: Set(tagIDs))) ?? []
        if let selected = model.selectedItemID, !summaries.contains(where: { $0.id == selected }) {
            model.selectedItemID = nil
        }
    }

    // MARK: Labels

    private var labelsColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Categorie e tag")).font(.title3.bold()).padding(.horizontal, 4)
            categoriesBox
            tagsBox
            if !tagsOpen { Spacer(minLength: 0) }
        }
        .padding(12)
    }

    private var categoriesBox: some View {
        VStack(alignment: .leading, spacing: 2) {
            boxHeader(String(localized: "Categorie"), detail: "\(model.categories.count)", open: $categoriesOpen) {
                LabelsLayout.save(categoriesOpen, "labels.categoriesOpen")
            }
            if categoriesOpen {
                Divider().padding(.vertical, 4)
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(orderedCategories) { category in
                            let on = categoryID == category.id
                            let count = counts.categories[category.id] ?? 0
                            labelRow(on: on, empty: count == 0, count: count, pinKey: "category:\(category.id)") {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(category.color.flatMap(Color.init(hex:)) ?? Color.secondary.opacity(0.5))
                                    .frame(width: 9, height: 9)
                                Text(category.name).lineLimit(1)
                            } action: {
                                categoryID = on ? nil : category.id
                            }
                        }
                    }
                }
                .frame(maxHeight: 260).fixedSize(horizontal: false, vertical: true)
            }
        }
        .modifier(LabelsBox())
    }

    /// Main categories first, then the families switched on.
    private var orderedCategories: [IAGOStore.Category] {
        let categories = model.categories
        let families = IAGOStore.Category.families.filter { family in categories.contains { $0.family == family } }
        return categories.filter { $0.family == nil }
            + families.flatMap { family in categories.filter { $0.family == family } }
    }

    private var tagsBox: some View {
        let needle = query.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let tags = model.tags
            .filter { !tagIDs.contains($0.id) }
            .filter { needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) }
            .sorted { (counts.tags[$0.id] ?? 0, $1.name) > (counts.tags[$1.id] ?? 0, $0.name) }
        return VStack(alignment: .leading, spacing: 2) {
            boxHeader(
                String(localized: "Tag"), detail: String(localized: "per utilizzo · \(model.tags.count)"),
                open: $tagsOpen
            ) {
                LabelsLayout.save(tagsOpen, "labels.tagsOpen")
            }
            if tagsOpen {
                Divider().padding(.vertical, 4)
                TextField(String(localized: "Cerca uno o più tag"), text: $query)
                    .textFieldStyle(.roundedBorder).focused($searchFocused)
                    .onSubmit {
                        if let first = tags.first { add(first.id) }
                        searchFocused = true
                    }
                if !tagIDs.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(tagIDs, id: \.self) { id in chosenTile(id) }
                        Button(String(localized: "Azzera")) { tagIDs = [] }
                            .buttonStyle(.link).font(.caption).padding(.vertical, 3)
                    }
                    .padding(.top, 6)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(tags) { tag in
                            let count = counts.tags[tag.id] ?? 0
                            labelRow(on: false, empty: count == 0, count: count, pinKey: "tag:\(tag.id)") {
                                Text("#\(tag.name)").lineLimit(1)
                            } action: {
                                add(tag.id)
                            }
                        }
                        if tags.isEmpty {
                            Text(
                                model.tags.isEmpty
                                    ? String(localized: "Nessun tag: li aggiungi dalla scheda di un elemento.")
                                    : String(localized: "Nessun tag con «\(needle)»")
                            )
                            .font(.callout).foregroundStyle(.secondary).padding(6)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .modifier(LabelsBox())
        .frame(maxHeight: tagsOpen ? .infinity : nil, alignment: .top)
    }

    private func add(_ tagID: String) {
        if !tagIDs.contains(tagID) { tagIDs.append(tagID) }
        query = ""
    }

    private func chosenTile(_ id: String) -> some View {
        let name = model.tags.first { $0.id == id }?.name ?? ""
        return HStack(spacing: 4) {
            Text("#\(name)").lineLimit(1)
            Button {
                tagIDs.removeAll { $0 == id }
            } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).frame(width: 12, height: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(String(localized: "Togli #\(name)"))
        }
        .font(.callout).foregroundStyle(.white)
        .padding(.leading, 8).padding(.trailing, 5).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor))
    }

    private func boxHeader(
        _ title: String, detail: String, open: Binding<Bool>, changed: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { open.wrappedValue.toggle() }
            changed()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                    .rotationEffect(.degrees(open.wrappedValue ? 90 : 0))
                Text(title).font(.headline)
                Spacer(minLength: 4)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func labelRow<Label: View>(
        on: Bool, empty: Bool, count: Int, pinKey: String, @ViewBuilder label: () -> Label,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                label()
                Spacer(minLength: 4)
                if model.isPinnedLabel(pinKey) {
                    Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(on ? .white : .secondary)
                }
                Text("\(count)").font(.caption).monospacedDigit().foregroundStyle(on ? Color.white : .secondary)
            }
            .font(.callout)
            .foregroundStyle(on ? Color.white : empty ? Color.secondary : Color.primary)
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(on ? Color.accentColor : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(
                model.isPinnedLabel(pinKey)
                    ? String(localized: "Togli da «In evidenza»") : String(localized: "Fissa in «In evidenza»")
            ) {
                model.togglePinnedLabel(pinKey)
            }
        }
    }

    // MARK: Items

    private var title: String {
        let parts =
            [categoryID.flatMap { id in model.categories.first { $0.id == id }?.name }]
            + tagIDs.map { id in model.tags.first { $0.id == id }.map { "#\($0.name)" } }
        let names = parts.compactMap { $0 }
        return names.isEmpty
            ? String(localized: "Tutti gli elementi con una categoria o un tag") : names.joined(separator: " · ")
    }

    private var hint: String {
        tagIDs.count > 1
            ? String(localized: "Elementi che hanno tutti questi tag, in tutti i progetti.")
            : String(localized: "Un clic su una categoria la sceglie, un altro la toglie; i tag cercati si sommano.")
    }

    private var itemList: some View {
        List(summaries, selection: $model.selectedItemID) { summary in
            ItemRow(summary: summary, suggestions: model.pendingSuggestions[summary.id] ?? 0).tag(summary.id)
                .contextMenu { ItemContextMenu(model: model, summary: summary) }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).lineLimit(2)
                Text(
                    summaries.count == 1
                        ? String(localized: "1 elemento · in tutti i progetti")
                        : String(localized: "\(summaries.count) elementi · in tutti i progetti")
                )
                .font(.caption).foregroundStyle(.secondary)
                Text(hint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .iagoBar()
        }
        .overlay {
            if summaries.isEmpty {
                ContentUnavailableView(
                    String(localized: "Nessun elemento con queste etichette insieme"), systemImage: "tag")
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = model.selectedItemID, model.item(id) != nil {
            ItemDetailView(model: model, itemID: id).id(id)
        } else {
            ContentUnavailableView(
                String(localized: "Nessun elemento selezionato"), systemImage: "doc.text",
                description: Text(String(localized: "Scegli un elemento dall'elenco")))
        }
    }

    // MARK: Widths

    /// A divider to drag; a double click goes back to the base widths.
    private func handle(_ set: @escaping (Double?) -> Void, current: @escaping () -> CGFloat) -> some View {
        Rectangle().fill(Color.secondary.opacity(dragStart != nil ? 0.5 : 0.2)).frame(width: 1)
            .overlay {
                Color.clear.frame(width: 9).contentShape(Rectangle())
                    .pointerStyle(.columnResize)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let start = dragStart ?? Double(current())
                                dragStart = start
                                set(start + value.translation.width)
                            }
                            .onEnded { _ in dragStart = nil }
                    )
                    .onTapGesture(count: 2) {
                        labelsWidth = 0
                        listShare = 0
                        LabelsLayout.save(0.0, "labels.width.labels")
                        LabelsLayout.save(0.0, "labels.width.list")
                    }
                    .help(String(localized: "Trascina per cambiare la larghezza · doppio clic: misure di base"))
            }
    }
}

/// The box of the categories and of the tags.
private struct LabelsBox: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.16)))
    }
}

/// Widths of «Categorie e tag», remembered for this section only (0 = the base): the labels as narrow as their text
/// allows, then 30% of the rest to the list and 70% to the card. The demo tour neither reads nor writes them.
enum LabelsLayout {
    static let baseLabels: Double = 232
    static let baseList = 0.3

    static func labels(_ stored: Double, total: CGFloat) -> CGFloat {
        clampLabels(stored > 0 ? stored : baseLabels, total: total)
    }

    static func clampLabels(_ value: Double, total: CGFloat) -> CGFloat {
        CGFloat(min(max(value, 200), max(200, min(420, Double(total) - 600))))
    }

    static func list(_ share: Double, rest: CGFloat) -> CGFloat {
        clampList(Double(rest) * (share > 0 ? share : baseList), rest: rest)
    }

    static func clampList(_ value: Double, rest: CGFloat) -> CGFloat {
        CGFloat(min(max(value, 240), max(240, Double(rest) - 360)))
    }

    static func number(_ key: String) -> Double {
        DemoMode.isActive ? 0 : UserDefaults.standard.double(forKey: key)
    }

    /// Open unless the user closed it.
    static func flag(_ key: String) -> Bool {
        DemoMode.isActive ? true : (UserDefaults.standard.object(forKey: key) as? Bool ?? true)
    }

    static func save(_ value: Double, _ key: String) {
        if !DemoMode.isActive { UserDefaults.standard.set(value, forKey: key) }
    }

    static func save(_ value: Bool, _ key: String) {
        if !DemoMode.isActive { UserDefaults.standard.set(value, forKey: key) }
    }
}
