import IAGOCapture
import IAGOStore
import SwiftUI

/// New project with a duplicate check: if similar projects exist, the user picks one of them or
/// explicitly confirms "Crea comunque".
struct NewProjectSheet: View {
    let model: AppModel
    /// Called with the created or chosen project.
    let onDone: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    /// ADR-0038: the client of the new project (preset when created from a client).
    @State private var clientID: String?
    /// Created from a client: the client is shown, not chosen.
    let locksClient: Bool

    init(model: AppModel, clientID: String? = nil, locksClient: Bool = false, onDone: @escaping (Project) -> Void) {
        self.model = model
        self.onDone = onDone
        self.locksClient = locksClient && clientID != nil
        _clientID = State(initialValue: clientID)
    }

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let similar = trimmed.isEmpty ? [] : model.similarProjects(to: trimmed)
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Nuovo progetto")).font(.title3).bold()
            TextField(String(localized: "Nome del progetto"), text: $name)
                .textFieldStyle(.roundedBorder).frame(width: 380)
                .onSubmit { if similar.isEmpty { create(trimmed) } }
            if locksClient, let client = model.client(clientID) {
                LabeledContent(String(localized: "Cliente")) {
                    HStack(spacing: 5) {
                        ClientMark(color: client.color)
                        Text(client.name)
                    }
                }
                .frame(width: 380, alignment: .leading)
            } else if !model.clients.isEmpty {
                Picker(String(localized: "Cliente"), selection: $clientID) {
                    Text(String(localized: "Nessun cliente")).tag(String?.none)
                    ForEach(model.clients) { Text($0.name).tag(Optional($0.id)) }
                }
                .frame(width: 380)
            }
            if !similar.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        String(localized: "Esistono già progetti simili:"), systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    ForEach(similar) { project in
                        HStack {
                            Image(systemName: "folder")
                            Text(project.name).bold()
                            Spacer()
                            Button(String(localized: "Usa questo")) {
                                onDone(project)
                                dismiss()
                            }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                if similar.isEmpty {
                    Button(String(localized: "Crea")) { create(trimmed) }
                        .keyboardShortcut(.defaultAction).disabled(trimmed.isEmpty)
                } else {
                    Button(String(localized: "Crea comunque \"\(trimmed)\"")) { create(trimmed) }
                }
            }
        }
        .padding(20)
    }

    private func create(_ name: String) {
        guard let project = model.createProject(named: name, clientID: clientID) else { return }
        onDone(project)
        dismiss()
    }
}

/// New tag with the same duplicate check as projects ("Design System" / "design-system" / "Desing system").
struct NewTagSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let similar = trimmed.isEmpty ? [] : model.tags.filter { ProjectNameMatcher.isSimilar(trimmed, $0.name) }
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Nuovo tag")).font(.title3).bold()
            TextField(String(localized: "Nome del tag"), text: $name)
                .textFieldStyle(.roundedBorder).frame(width: 340)
                .onSubmit { if similar.isEmpty { create(trimmed) } }
            if !similar.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "Esistono già tag simili:"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    ForEach(similar) { tag in
                        HStack {
                            Text("#\(tag.name)").bold()
                            Spacer()
                            Button(String(localized: "Usa questo")) { dismiss() }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                if similar.isEmpty {
                    Button(String(localized: "Crea")) { create(trimmed) }.keyboardShortcut(.defaultAction).disabled(
                        trimmed.isEmpty)
                } else {
                    Button(String(localized: "Crea comunque \"\(trimmed)\"")) { create(trimmed) }
                }
            }
        }
        .padding(20)
    }

    private func create(_ name: String) {
        guard !name.isEmpty else { return }
        model.perform { try model.archive.createTag(name: name) }
        model.reload()
        dismiss()
    }
}

/// Hosts the recording bar in a titlebar accessory: the window content moves down instead of being
/// covered.
struct RecordingBarHost: View {
    let model: AppModel

    var body: some View {
        if let snapshot = model.recording, snapshot.state != .idle {
            RecordingBar(model: model, snapshot: snapshot)
        } else {
            Color.clear.frame(height: 0)
        }
    }
}

/// Discreet bar shown in the window while recording: state, duration, microphone, controls.
struct RecordingBar: View {
    let model: AppModel
    let snapshot: RecordingController.Snapshot

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(snapshot.state == .recording ? Color.red : Color.orange).frame(width: 9, height: 9)
                .opacity(snapshot.state == .recording ? 1 : 0.8)
            Text(
                snapshot.state == .recording
                    ? String(localized: "Registrazione in corso") : String(localized: "In pausa")
            )
            .bold()
            Text(Format.clock(snapshot.elapsed)).monospacedDigit()
            if let mic = snapshot.micName {
                Label(mic, systemImage: "mic").foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                    .layoutPriority(-1)
            }
            if snapshot.micAbsent {
                Label(String(localized: "Nessun audio dal microfono"), systemImage: "mic.slash.fill")
                    .foregroundStyle(.yellow)
            } else if let silent = snapshot.silentTrack {
                Label(
                    silent == .mic
                        ? String(localized: "Microfono muto da oltre 30 s")
                        : String(localized: "Audio di sistema muto da oltre 30 s"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            }
            Spacer()
            Button(String(localized: "Segna momento"), systemImage: "bookmark") { model.addBookmark() }
                .disabled(snapshot.state != .recording)
            Button(
                snapshot.state == .paused ? String(localized: "Riprendi") : String(localized: "Pausa"),
                systemImage: snapshot.state == .paused ? "play.fill" : "pause.fill"
            ) { model.togglePause() }
            Button(String(localized: "Scarta"), systemImage: "trash", role: .destructive) { model.discardRecording() }
                .help(String(localized: "Ferma e scarta: resta 1 ora in \"Scartate temporanee\""))
            Button(String(localized: "Stop"), systemImage: "stop.fill") { model.stopRecording() }
                .buttonStyle(.borderedProminent).tint(.red)
        }
        .controlSize(.small)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
        // Solid: the cards of the item view must not show through.
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }
}
