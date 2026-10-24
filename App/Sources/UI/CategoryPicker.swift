import IAGOStore
import SwiftUI

/// The category of an item (ADR-0054): main categories first, then each family that has categories switched on,
/// as a submenu. Families switched off stay out of the way (Settings › Categorie).
struct CategoryPicker: View {
    let model: AppModel
    let selection: String?
    var noneLabel = String(localized: "Nessuna")
    let choose: (String?) -> Void

    var body: some View {
        let categories = model.categories
        let main = categories.filter { $0.family == nil }
        Menu {
            Button {
                choose(nil)
            } label: {
                if selection == nil { Label(noneLabel, systemImage: "checkmark") } else { Text(noneLabel) }
            }
            Divider()
            ForEach(main) { option($0) }
            let families =
                Category.families.filter { family in categories.contains { $0.family == family } }
                + Set(categories.compactMap(\.family)).subtracting(Category.families).sorted()
            if !families.isEmpty { Divider() }
            ForEach(families, id: \.self) { family in
                Menu(family) {
                    ForEach(categories.filter { $0.family == family }) { option($0) }
                }
            }
        } label: {
            Text(selection.flatMap { id in categories.first { $0.id == id }?.name } ?? noneLabel)
        }
        .fixedSize()
    }

    private func option(_ category: IAGOStore.Category) -> some View {
        Button {
            choose(category.id)
        } label: {
            if category.id == selection {
                Label(category.name, systemImage: "checkmark")
            } else {
                Text(category.name)
            }
        }
    }
}
