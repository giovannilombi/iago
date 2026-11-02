import AppKit
import IAGOStore
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let iagoBackup = UTType(filenameExtension: Backup.fileExtension, conformingTo: .data) ?? .data
}

/// Settings › Backup: encrypted backup, restore (also to move to a new Mac), all the audio.
struct BackupPane: View {
    let model: AppModel
    @State private var creating = false
    @State private var restoring = false
    @State private var exportingAudio = false
    @State private var replaced: [BackupService.ReplacedArchive] = []
    @State private var deleting: BackupService.ReplacedArchive?
    @State private var step = 0
    @State private var typed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            group(
                String(localized: "Backup cifrato"),
                String(
                    localized:
                        "Un unico file con tutto l'archivio (audio, trascrizioni, note, progetti, decisioni, email, impostazioni) cifrato con una password che scegli tu. Serve per un disco esterno o per passare a un nuovo Mac."
                )
            ) {
                Text(lastBackup).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button(String(localized: "Esporta backup cifrato…")) { creating = true }
                    Button(String(localized: "Ripristina da backup…")) { restoring = true }
                }
            }
            group(
                String(localized: "Audio"),
                String(
                    localized:
                        "Copie normali (.m4a, non cifrate) di tutti gli audio, per condividerli o conservarli altrove. Per un progetto solo: usa \"Esporta\" nella sua vista."
                )
            ) {
                Button(String(localized: "Esporta tutti gli audio…")) { exportingAudio = true }
            }
            if !replaced.isEmpty {
                group(
                    String(localized: "Archivi sostituiti"),
                    String(
                        localized:
                            "Gli archivi messi da parte dai ripristini, ciascuno con la sua chiave nel portachiavi. Eliminarli libera spazio: non si potranno più recuperare."
                    )
                ) {
                    ForEach(replaced) { archive in
                        HStack(spacing: 8) {
                            Image(systemName: "archivebox").foregroundStyle(.secondary)
                            Text(
                                archive.date?.formatted(date: .long, time: .shortened) ?? archive.stamp)
                            Text(ByteCountFormatter.string(fromByteCount: archive.bytes, countStyle: .file))
                                .foregroundStyle(.secondary).monospacedDigit()
                            Spacer()
                            Button(String(localized: "Mostra nel Finder")) {
                                NSWorkspace.shared.activateFileViewerSelecting([archive.folder])
                            }
                            .buttonStyle(.link)
                            Button(String(localized: "Elimina…"), role: .destructive) { startDelete(archive) }
                                .buttonStyle(.link)
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
        // Step 1: what is lost.
        .alert(
            String(localized: "Eliminare l'archivio sostituito?"),
            isPresented: Binding(get: { step == 1 }, set: { if !$0 && step == 1 { cancel() } })
        ) {
            Button(String(localized: "Continua"), role: .destructive) { step = 2 }
            Button(String(localized: "Annulla"), role: .cancel) { cancel() }
        } message: {
            Text(
                String(
                    localized:
                        "L'archivio messo da parte il \(deletingName) (\(deletingSize)) verrà distrutto insieme alla sua chiave. Non si potrà recuperare, nemmeno ripristinando un backup successivo."
                ))
        }
        // Step 2: type DELETE.
        .sheet(isPresented: Binding(get: { step == 2 }, set: { if !$0 && step == 2 { cancel() } })) {
            VStack(alignment: .leading, spacing: 12) {
                Label(String(localized: "Conferma l'eliminazione"), systemImage: "exclamationmark.triangle.fill")
                    .font(.title3).bold().foregroundStyle(.red)
                Text(
                    String(
                        localized:
                            "Per eliminare l'archivio sostituito del \(deletingName) scrivi DELETE qui sotto."
                    ))
                TextField("DELETE", text: $typed).textFieldStyle(.roundedBorder).font(.title2.monospaced()).frame(
                    width: 220)
                HStack {
                    Spacer()
                    Button(String(localized: "Annulla"), role: .cancel) { cancel() }.keyboardShortcut(.cancelAction)
                    Button(String(localized: "OK")) { step = 3 }.disabled(typed != "DELETE")
                }
            }
            .padding(20).frame(width: 420)
        }
        // Step 3: final warning.
        .alert(
            String(localized: "Ultima conferma"),
            isPresented: Binding(get: { step == 3 }, set: { if !$0 && step == 3 { cancel() } })
        ) {
            Button(String(localized: "Elimina definitivamente"), role: .destructive) { delete() }
            Button(String(localized: "Annulla"), role: .cancel) { cancel() }
        } message: {
            Text(
                String(
                    localized:
                        "L'archivio sostituito del \(deletingName) e la sua chiave verranno distrutti. L'operazione non si può annullare."
                ))
        }
        .sheet(isPresented: $creating) { CreateBackupSheet(model: model) }
        .sheet(isPresented: $restoring) { RestoreBackupSheet(model: model) }
        .sheet(isPresented: $exportingAudio) {
            AudioExportSheet(
                model: model,
                scope: ExportScope(
                    title: String(localized: "Tutto l'archivio"),
                    itemIDs: ((try? model.archive.items()) ?? []).map(\.id), projectNoteIDs: [], decisionScope: nil,
                    filtersDescription: "nessuno"))
        }
    }

    private var deletingName: String {
        deleting.map { $0.date?.formatted(date: .long, time: .shortened) ?? $0.stamp } ?? ""
    }

    private var deletingSize: String {
        ByteCountFormatter.string(fromByteCount: deleting?.bytes ?? 0, countStyle: .file)
    }

    private func reload() {
        replaced = BackupService.replacedArchives(paths: model.archiveService.paths)
    }

    private func startDelete(_ archive: BackupService.ReplacedArchive) {
        deleting = archive
        typed = ""
        step = 1
    }

    private func cancel() {
        step = 0
        deleting = nil
        typed = ""
    }

    private func delete() {
        guard let archive = deleting else { return }
        model.perform { try BackupService.deleteReplacedArchive(archive, archive: model.archive) }
        cancel()
        reload()
    }

    private var lastBackup: String {
        guard let value = try? model.archive.setting(BackupService.lastBackupKey),
            let date = ISO8601DateFormatter().date(from: value)
        else { return String(localized: "Nessun backup ancora.") }
        return String(localized: "Ultimo backup: \(date.formatted(date: .long, time: .shortened))")
    }

    private func group<Content: View>(_ title: String, _ footnote: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(IAGOColor.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
            Text(footnote).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct CreateBackupSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirm = ""
    @State private var working = false
    @State private var done: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Esporta backup cifrato"), systemImage: "lock.doc").font(.title3).bold()
            SecureField(
                String(localized: "Password (almeno \(Backup.minimumPasswordLength) caratteri)"), text: $password
            )
            .textFieldStyle(.roundedBorder)
            SecureField(String(localized: "Ripeti la password"), text: $confirm).textFieldStyle(.roundedBorder)
            Label(
                String(
                    localized:
                        "Senza questa password il backup non si può aprire: IAGO non la conserva e nessuno può recuperarla. Scrivila in un posto sicuro."
                ),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption).foregroundStyle(.orange)
            if working {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "Creazione del backup…")).foregroundStyle(.secondary)
                }
            }
            if let done {
                HStack {
                    Label(String(localized: "Backup creato"), systemImage: "checkmark.circle.fill").foregroundStyle(
                        .green)
                    Button(String(localized: "Mostra nel Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([done])
                    }
                    .buttonStyle(.link)
                }
            }
            HStack {
                Spacer()
                Button(done == nil ? String(localized: "Annulla") : String(localized: "Chiudi"), role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction).disabled(working)
                if done == nil {
                    Button(String(localized: "Scegli dove salvarlo…")) { create() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(password.count < Backup.minimumPasswordLength || password != confirm || working)
                }
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func create() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.iagoBackup]
        panel.nameFieldStringValue = "IAGO \(BackupService.stamp()).\(Backup.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        working = true
        Task {
            do {
                _ = try await model.activity.track(.backup, url.lastPathComponent) { _ in
                    try await BackupService.create(
                        archive: model.archive, paths: model.archiveService.paths, password: password, to: url)
                }
                done = url
            } catch {
                model.lastError = ErrorText.describe(error)
            }
            working = false
        }
    }
}

/// Restore (also during onboarding on a new Mac): checks the file now, swaps the archive at relaunch. The
/// current archive is never deleted: it is moved to "Archivi sostituiti" with its key kept in the keychain.
struct RestoreBackupSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var file: URL?
    @State private var password = ""
    @State private var working = false
    @State private var ready: Backup.Manifest?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "Ripristina da backup"), systemImage: "arrow.counterclockwise.circle")
                .font(.title3).bold()
            HStack {
                Button(String(localized: "Scegli il file…")) { choose() }
                Text(file?.lastPathComponent ?? String(localized: "nessun file scelto")).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            SecureField(String(localized: "Password del backup"), text: $password).textFieldStyle(.roundedBorder)
                .onSubmit(check)
            let items = (try? model.archive.items().count) ?? 0
            if items > 0 {
                Label(
                    String(
                        localized:
                            "L'archivio attuale (\(items) elementi) verrà sostituito. Non viene cancellato: resta da parte nella cartella \"Archivi sostituiti\" di IAGO, con la sua chiave."
                    ),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption).foregroundStyle(.orange)
            }
            if working {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "Verifica del backup…")).foregroundStyle(.secondary)
                }
            }
            if let ready {
                Label(
                    String(
                        localized:
                            "Backup del \(ready.createdAt.formatted(date: .long, time: .shortened)) con \(ready.items) elementi: pronto. IAGO si riavvia per completare il ripristino."
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
            }
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) {
                    if ready != nil {
                        try? FileManager.default.removeItem(at: model.archiveService.paths.restorePending)
                    }
                    dismiss()
                }
                .keyboardShortcut(.cancelAction).disabled(working)
                if ready == nil {
                    Button(String(localized: "Verifica")) { check() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(file == nil || password.count < Backup.minimumPasswordLength || working)
                } else {
                    Button(String(localized: "Riavvia e ripristina")) { BackupService.relaunch() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.iagoBackup]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        file = url
        ready = nil
    }

    private func check() {
        guard let file else { return }
        working = true
        Task {
            do {
                ready = try await model.activity.track(.restore, file.lastPathComponent) { _ in
                    try await BackupService.prepareRestore(
                        file, password: password, paths: model.archiveService.paths)
                }
            } catch {
                model.lastError = ErrorText.describe(error)
            }
            working = false
        }
    }
}
