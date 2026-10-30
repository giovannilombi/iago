import IAGOStore
import SwiftUI

/// «Presenti» (ADR-0031): who was at the meeting, written by the user when they want, during or after. The names are
/// offered for the speakers; a name written like a known one takes its spelling.
struct AttendeesRow: View {
    let model: AppModel
    let itemID: String
    @State private var names: [String] = []
    @State private var typing = ""

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            Label(String(localized: "Presenti:"), systemImage: "person.2").foregroundStyle(.secondary)
            ForEach(names, id: \.self) { name in
                HStack(spacing: 3) {
                    Text(name)
                    Button {
                        save(names.filter { $0 != name })
                    } label: {
                        Image(systemName: "xmark").font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Togli «\(name)»"))
                }
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(Color.teal.opacity(0.12)))
            }
            TextField(String(localized: "Aggiungi chi c'era"), text: $typing)
                .textFieldStyle(.roundedBorder).frame(width: 170)
                .onSubmit { add() }
                .help(String(localized: "Un nome, poi Invio. Diventano i nomi proposti per gli speaker."))
        }
        .task(id: model.revision) { names = (try? model.archive.attendees(itemID: itemID)) ?? [] }
    }

    /// Several names at once, separated by commas, are fine too.
    private func add() {
        let typed = typing.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        typing = ""
        guard !typed.isEmpty else { return }
        save(names + typed)
    }

    private func save(_ list: [String]) {
        model.perform { try model.archive.setAttendees(list, itemID: itemID) }
        names = (try? model.archive.attendees(itemID: itemID)) ?? list
        model.reload()
    }
}
