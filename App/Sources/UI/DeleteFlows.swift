import IAGOStore
import SwiftUI

// Deleting projects, clients and streams (ADR-0099), the same from the sidebar and from Settings.

extension View {
    /// Deleting a project: what it holds and the streams that go with it, then the trash for 30 days or deletion for
    /// good (typing DELETE, then a last warning).
    func projectDeletion(model: AppModel, project: Binding<Project?>, onDone: @escaping () -> Void = {}) -> some View {
        modifier(ProjectDeletion(model: model, project: project, onDone: onDone))
    }

    /// Deleting a client: lists its projects, with their streams, which stay and go to «Senza cliente».
    func clientDeletion(model: AppModel, client: Binding<Client?>, onDone: @escaping () -> Void = {}) -> some View {
        modifier(ClientDeletion(model: model, client: client, onDone: onDone))
    }

    /// Deleting a stream: says how many items, key points and notes lose the label.
    func streamDeletion(model: AppModel, stream: Binding<ProjectStream?>, onDone: @escaping () -> Void = {})
        -> some View
    {
        modifier(StreamDeletion(model: model, stream: stream, onDone: onDone))
    }
}

private struct ProjectDeletion: ViewModifier {
    enum Step { case choice, typing, lastWarning }

    let model: AppModel
    @Binding var project: Project?
    let onDone: () -> Void
    @State private var step: Step?
    @State private var toTrash = true
    @State private var stats: Archive.ProjectStats?
    @State private var streams: [ProjectStream] = []
    @State private var typed = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: project?.id, initial: true) { _, id in
                guard let id else { return }
                stats = try? model.archive.projectStats(id)
                streams = (try? model.archive.streams(projectID: id, includeArchived: true)) ?? []
                toTrash = true
                typed = ""
                step = .choice
            }
            // One sheet for both steps: closing one and opening another at once can fail.
            .sheet(
                isPresented: Binding(
                    get: { step == .choice || step == .typing },
                    set: { if !$0 && (step == .choice || step == .typing) { cancel() } })
            ) {
                if step == .typing { typing } else { choice }
            }
            .alert(String(localized: "Ultima conferma"), isPresented: binding(.lastWarning)) {
                Button(String(localized: "Elimina definitivamente"), role: .destructive) { deleteForGood() }
                Button(String(localized: "Annulla"), role: .cancel) { cancel() }
            } message: {
                Text(
                    String(
                        localized:
                            "Il progetto «\(name)» e tutto il suo contenuto verranno distrutti. L'operazione non si può annullare."
                    ))
            }
    }

    private var name: String { project?.name ?? "" }

    private var choice: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Eliminare il progetto «\(name)»?")).font(.title3).bold()
            Text(
                String(
                    localized:
                        "Contiene \(stats?.items ?? 0) elementi con audio e documenti, \(stats?.transcripts ?? 0) trascrizioni e \(stats?.notes ?? 0) note, con i suoi punti chiave e le sue checklist."
                )
            )
            .fixedSize(horizontal: false, vertical: true)
            if !streams.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Insieme al progetto se ne vanno anche i suoi stream:"))
                    ForEach(streams) { stream in
                        HStack(spacing: 6) {
                            Circle().fill(Color.iago(stream.color)).frame(width: 7, height: 7)
                            Text(stream.name)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
            Divider()
            DeletionOption(
                selected: toTrash, title: String(localized: "Sposta nel Cestino"),
                detail: String(
                    localized:
                        "Il progetto sparisce dalla barra laterale, dalle ricerche, dall'Inbox e da Claude, ma resta sul Mac. Per 30 giorni puoi ripristinarlo dal Cestino così com'era; poi viene eliminato per sempre."
                )
            ) { toTrash = true }
            DeletionOption(
                selected: !toTrash, title: String(localized: "Elimina definitivamente"),
                detail: String(
                    localized:
                        "Tutto il contenuto viene distrutto subito e non si potrà recuperare, nemmeno dal Cestino. Ti verrà chiesto di scrivere DELETE."
                )
            ) { toTrash = false }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { cancel() }.keyboardShortcut(.cancelAction)
                if toTrash {
                    Button(String(localized: "Sposta nel Cestino"), action: trash).keyboardShortcut(.defaultAction)
                } else {
                    Button(String(localized: "Continua"), role: .destructive) { step = .typing }
                }
            }
        }
        .padding(20).frame(width: 460)
    }

    private var typing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Conferma l'eliminazione"), systemImage: "exclamationmark.triangle.fill")
                .font(.title3).bold().foregroundStyle(.red)
            Text(String(localized: "Per eliminare «\(name)» e tutto il suo contenuto scrivi DELETE qui sotto."))
            TextField("DELETE", text: $typed).textFieldStyle(.roundedBorder).font(.title2.monospaced())
                .frame(width: 220)
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { cancel() }.keyboardShortcut(.cancelAction)
                Button(String(localized: "OK")) { step = .lastWarning }.disabled(typed != "DELETE")
            }
        }
        .padding(20).frame(width: 420)
    }

    private func binding(_ value: Step) -> Binding<Bool> {
        Binding(get: { step == value }, set: { if !$0 && step == value { cancel() } })
    }

    private func trash() {
        guard let project else { return }
        model.perform { try model.archive.trashProject(project.id) }
        finish(project)
    }

    private func deleteForGood() {
        guard let project else { return }
        model.perform { try model.archive.deleteProject(project.id) }
        finish(project)
    }

    private func finish(_ removed: Project) {
        let streams = self.streams
        step = nil
        project = nil
        model.leaveRemovedProject(removed.id, streams: streams)
        onDone()
    }

    private func cancel() {
        step = nil
        project = nil
        typed = ""
    }
}

/// A radio choice with its explanation underneath.
private struct DeletionOption: View {
    let selected: Bool
    let title: String
    let detail: String
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).bold()
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ClientDeletion: ViewModifier {
    let model: AppModel
    @Binding var client: Client?
    let onDone: () -> Void
    @State private var projects: [Project] = []

    func body(content: Content) -> some View {
        content
            .onChange(of: client?.id, initial: true) { _, id in
                guard let id else { return }
                projects = ((try? model.archive.projects(includeArchived: true)) ?? []).filter { $0.clientId == id }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            .sheet(isPresented: Binding(get: { client != nil }, set: { if !$0 { client = nil } })) { sheet }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Eliminare il cliente «\(client?.name ?? "")»?")).font(.title3).bold()
            if projects.isEmpty {
                Text(String(localized: "Il cliente non ha progetti: nessun elemento viene eliminato."))
            } else {
                Text(
                    String(
                        localized:
                            "Questi progetti restano, con tutto il loro contenuto, e passano in «Senza cliente»:"))
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(projects) { project in
                            let streams =
                                (try? model.archive.streams(projectID: project.id, includeArchived: true)) ?? []
                            VStack(alignment: .leading, spacing: 1) {
                                Label(project.name, systemImage: project.archived ? "archivebox" : "folder")
                                if !streams.isEmpty {
                                    Text(
                                        String(
                                            localized:
                                                "Stream: \(streams.map(\.name).joined(separator: ", "))")
                                    )
                                    .font(.caption).foregroundStyle(.secondary).padding(.leading, 24)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                Text(
                    String(
                        localized:
                            "Nessun elemento viene eliminato. Per rimetterli in un cliente trascinali sul cliente, oppure tasto destro › Sposta nel cliente."
                    )
                )
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { client = nil }.keyboardShortcut(.cancelAction)
                Button(String(localized: "Elimina cliente"), role: .destructive, action: delete)
            }
        }
        .padding(20).frame(width: 440)
    }

    private func delete() {
        guard let removed = client else { return }
        model.perform { try model.archive.deleteClient(removed.id) }
        client = nil
        if model.sidebar == .library(.client(removed.id)) { model.select(.library(.unclassified)) }
        model.reload()
        onDone()
    }
}

private struct StreamDeletion: ViewModifier {
    let model: AppModel
    @Binding var stream: ProjectStream?
    let onDone: () -> Void
    @State private var stats: Archive.StreamStats?

    func body(content: Content) -> some View {
        content
            .onChange(of: stream?.id, initial: true) { _, id in
                guard let id else { return }
                stats = try? model.archive.streamStats(id)
            }
            .confirmationDialog(
                String(localized: "Eliminare lo stream «\(stream?.name ?? "")»?"),
                isPresented: Binding(get: { stream != nil }, set: { if !$0 { stream = nil } }),
                titleVisibility: .visible
            ) {
                Button(String(localized: "Elimina stream"), role: .destructive, action: delete)
            } message: {
                Text(
                    String(
                        localized:
                            "\(stats?.items ?? 0) elementi, \(stats?.decisions ?? 0) punti chiave e \(stats?.notes ?? 0) note restano nel progetto: perdono solo l'etichetta dello stream."
                    ))
            }
    }

    private func delete() {
        guard let removed = stream else { return }
        model.perform { try model.archive.deleteStream(removed.id) }
        stream = nil
        if model.isPinnedLabel("stream:\(removed.id)") { model.togglePinnedLabel("stream:\(removed.id)") }
        if model.sidebar == .library(.stream(removed.id)) { model.select(.library(.project(removed.projectId))) }
        model.reload()
        onDone()
    }
}
