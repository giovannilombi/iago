import IAGOStore
import SwiftUI

/// "Categorie e tag": the way across projects. Categories as tiles (main ones, then the families switched on),
/// tags as chips with how many items they have. A click opens the list of every item with it; the context menu pins
/// it in "In evidenza" at the top of the sidebar.
struct LabelsBrowser: View {
    let model: AppModel
    @State private var counts: (categories: [String: Int], tags: [String: Int]) = ([:], [:])
    @State private var query = ""
    @AppStorage("labels.tagOrder") private var byUse = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Categorie e tag")).font(.title2.bold())
                    Text(
                        String(
                            localized:
                                "Apri una categoria o un tag per vedere tutti i suoi elementi, in ogni progetto. Con il tasto destro lo fissi in evidenza nella barra laterale."
                        )
                    )
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                categoriesSection
                tagsSection
            }
            .padding(20)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: model.revision) { counts = (try? model.archive.labelCounts()) ?? ([:], [:]) }
    }

    // MARK: Categories

    private var categoriesSection: some View {
        let categories = model.categories
        let main = categories.filter { $0.family == nil }
        let families = IAGOStore.Category.families.filter { family in categories.contains { $0.family == family } }
        return VStack(alignment: .leading, spacing: 10) {
            header(String(localized: "Categorie"))
            tiles(main)
            ForEach(families, id: \.self) { family in
                Text(CategoryFamilyName.display(family)).font(.subheadline.weight(.semibold)).foregroundStyle(
                    .secondary
                ).padding(.top, 4)
                tiles(categories.filter { $0.family == family })
            }
        }
    }

    private func tiles(_ categories: [IAGOStore.Category]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(categories) { category in
                let key = "category:\(category.id)"
                Button {
                    model.select(.library(.category(category.id)))
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(category.color.flatMap(Color.init(hex:)) ?? Color.secondary.opacity(0.5))
                            .frame(width: 10, height: 10)
                        Text(category.name).lineLimit(1)
                        Spacer(minLength: 4)
                        if model.isPinnedLabel(key) {
                            Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        Text("\(counts.categories[category.id] ?? 0)").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    // An empty category is dashed, like an empty tile (style A).
                    .background(TileShape(isEmpty: (counts.categories[category.id] ?? 0) == 0, radius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { pinButton(key) }
            }
        }
    }

    // MARK: Tags

    private var tagsSection: some View {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let tags = model.tags
            .filter { needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) }
            .sorted {
                byUse
                    ? (counts.tags[$0.id] ?? 0, $1.name) > (counts.tags[$1.id] ?? 0, $0.name)
                    : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                header(String(localized: "Tag"))
                Spacer()
                Picker("", selection: $byUse) {
                    Text(String(localized: "Più usati")).tag(true)
                    Text(String(localized: "A-Z")).tag(false)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            }
            if model.tags.count > 12 {
                TextField(String(localized: "Cerca un tag"), text: $query).textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
            }
            if tags.isEmpty {
                Text(
                    model.tags.isEmpty
                        ? String(localized: "Nessun tag: li aggiungi dalla scheda di un elemento.")
                        : String(localized: "Nessun tag con «\(needle)»")
                )
                .font(.callout).foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 8) {
                ForEach(tags) { tag in
                    let key = "tag:\(tag.id)"
                    Button {
                        model.select(.library(.tag(tag.id)))
                    } label: {
                        HStack(spacing: 5) {
                            Text("#\(tag.name)")
                            Text("\(counts.tags[tag.id] ?? 0)").font(.caption).monospacedDigit()
                                .foregroundStyle(.secondary)
                            if model.isPinnedLabel(key) {
                                Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .contextMenu { pinButton(key) }
                }
            }
        }
    }

    // MARK: Helpers

    private func header(_ title: String) -> some View {
        Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func pinButton(_ key: String) -> some View {
        Button(
            model.isPinnedLabel(key)
                ? String(localized: "Togli da «In evidenza»") : String(localized: "Fissa in «In evidenza»")
        ) {
            model.togglePinnedLabel(key)
        }
    }
}
