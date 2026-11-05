import IAGOStore
import SwiftUI

/// The context chosen in «Chiedi a IAGO» (ADR-0091), kept until the user changes it, also across launches. The demo
/// tour neither reads nor writes it.
enum ChatContextStore {
    static let key = "chat.context"

    static func load() -> SearchScope? {
        guard !DemoMode.isActive, let value = UserDefaults.standard.string(forKey: key) else { return nil }
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        let id = parts.count > 1 ? parts[1] : ""
        switch parts.first {
        case "all": return .all
        case "project": return .project(id)
        case "projects": return .chosen(id.split(separator: ",").map(String.init))
        case "client": return .client(id)
        case "stream": return .stream(id)
        default: return nil
        }
    }

    static func save(_ scope: SearchScope?) {
        guard !DemoMode.isActive else { return }
        let value: String? =
            switch scope {
            case nil: nil
            case .all: "all"
            case .project(let id): "project:\(id)"
            case .projects(let ids): "projects:\(ids.joined(separator: ","))"
            case .client(let id): "client:\(id)"
            case .stream(let id): "stream:\(id)"
            }
        UserDefaults.standard.set(value, forKey: key)
    }
}

/// «Aggiungi progetti» and «Restringi contesto»: every project with a checkbox, grouped by client, with a search.
struct ContextPicker: View {
    enum Mode: String, Identifiable {
        case add, narrow
        var id: String { rawValue }
    }

    let model: AppModel
    let mode: Mode
    let apply: ([String]) -> Void
    let cancel: () -> Void
    @State private var draft: Set<String>
    @State private var query = ""

    init(
        model: AppModel, mode: Mode, start: [String], apply: @escaping ([String]) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.model = model
        self.mode = mode
        self.apply = apply
        self.cancel = cancel
        // Narrowing the whole memory starts from every project.
        _draft = State(initialValue: Set(mode == .narrow && start.isEmpty ? model.projects.map(\.id) : start))
    }

    private struct Group: Identifiable {
        let id: String
        let name: String
        let color: String?
        let projects: [Project]
    }

    private var groups: [Group] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        var result = model.clients.map { client in
            Group(
                id: client.id, name: client.name, color: client.color,
                projects: model.projects.filter { $0.clientId == client.id })
        }
        result.append(
            Group(
                id: "", name: String(localized: "Senza cliente"), color: nil,
                projects: model.projects.filter { model.client($0.clientId) == nil }))
        return result.compactMap { group in
            let matches =
                needle.isEmpty || group.name.localizedCaseInsensitiveContains(needle)
                ? group.projects : group.projects.filter { $0.name.localizedCaseInsensitiveContains(needle) }
            return matches.isEmpty ? nil : Group(id: group.id, name: group.name, color: group.color, projects: matches)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(mode == .narrow ? String(localized: "Restringi contesto") : String(localized: "Aggiungi progetti"))
                    .font(.headline)
                Text(
                    mode == .narrow
                        ? String(
                            localized: "Togli la spunta ai progetti da escludere. La scelta resta finché non la cambi.")
                        : String(
                            localized:
                                "Spunta i progetti da aggiungere a quelli di adesso. La scelta resta finché non la cambi."
                        )
                )
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                TextField(String(localized: "Cerca progetti o clienti"), text: $query).textFieldStyle(.roundedBorder)
            }
            .padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(groups) { group in
                        let ids = Set(group.projects.map(\.id))
                        Toggle(isOn: groupBinding(ids)) {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2).fill(Color.iago(group.color)).frame(
                                    width: 8, height: 8)
                                Text(group.name.uppercased()).font(.caption.weight(.semibold)).tracking(0.5)
                                Text("\(ids.intersection(draft).count)/\(ids.count)").font(.caption).monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)
                        ForEach(group.projects) { project in
                            Toggle(project.name, isOn: projectBinding(project.id)).padding(.leading, 20)
                        }
                    }
                    if groups.isEmpty {
                        Text(String(localized: "Nessun progetto con «\(query)»")).font(.callout)
                            .foregroundStyle(.secondary).padding(.top, 8)
                    }
                }
                .toggleStyle(.checkbox)
                .padding(.horizontal, 12).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 300)
            Divider()
            HStack {
                Text(
                    draft.isEmpty
                        ? String(localized: "Nessun progetto")
                        : draft.count == 1
                            ? String(localized: "1 progetto") : String(localized: "\(draft.count) progetti")
                )
                .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "Annulla"), action: cancel).keyboardShortcut(.cancelAction)
                Button(mode == .narrow ? String(localized: "Restringi") : String(localized: "Applica")) {
                    apply(draft.filter { model.project($0) != nil }.sorted())
                }
                .keyboardShortcut(.defaultAction).disabled(draft.isEmpty)
            }
            .padding(12)
        }
        .frame(width: 320)
    }

    private func projectBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { draft.contains(id) },
            set: { on in if on { draft.insert(id) } else { draft.remove(id) } })
    }

    /// The client's box: all its projects on, or off.
    private func groupBinding(_ ids: Set<String>) -> Binding<Bool> {
        Binding(
            get: { !ids.isEmpty && ids.isSubset(of: draft) },
            set: { on in if on { draft.formUnion(ids) } else { draft.subtract(ids) } })
    }
}

/// What «Chiedi a IAGO» is doing: the open conversation, its turns, the question being written and the chosen context.
/// It lives in the model, so the conversation stays when the pane goes to the whole window and back, or closes.
@MainActor @Observable
final class ChatState {
    var question = ""
    var conversation: Conversation?
    var turns: [ChatPanel.Turn] = []
    var task: Task<Void, Never>?
    var showsList = false
    /// Items of the scope added or changed after the last answer that concern it.
    var newMaterial = 0
    /// The context chosen with «Cambia contesto», kept across sections and launches (ADR-0091); nil follows the
    /// open section.
    var chosenScope: SearchScope? = ChatContextStore.load() {
        didSet { ChatContextStore.save(chosenScope) }
    }
}
