import AppKit
import IAGOExport
import IAGOStore
import SwiftUI

/// «Condividi…» on an item (ADR-0080): the user ticks what to send, IAGO decrypts it into a temporary folder and
/// hands the files to the macOS Share menu (Mail, Messages, AirDrop…) or copies them to a folder. Nothing goes on
/// the network from IAGO; every share is in the access log. Voice prints are never among the parts.
struct ShareItemSheet: View {
    let model: AppModel
    let item: Item
    @Environment(\.dismiss) private var dismiss
    @State private var available: [ItemShare.Part] = []
    @State private var sizes: [ItemShare.Part: Int64] = [:]
    @State private var chosen: Set<ItemShare.Part> = [.card, .transcript]
    @AppStorage("share.zip") private var zip = false
    @State private var preparing = false
    @State private var failure: String?
    @State private var anchor = ShareAnchor()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Condividi «\(item.title)»")).font(.title3.bold())
            Text(String(localized: "Scegli cosa mandare."))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(available, id: \.self) { part in
                    Toggle(isOn: binding(part)) {
                        HStack(spacing: 6) {
                            Text(name(part))
                            if let size = sizes[part], size > 0 {
                                Text(Format.bytes(size)).foregroundStyle(.secondary)
                            }
                        }
                        Text(detail(part)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            Toggle(String(localized: "Un solo file .zip"), isOn: $zip)
            Label(
                String(
                    localized:
                        "I file condivisi non sono cifrati: chi li riceve può leggerli e ascoltarli. Le impronte delle voci non escono mai. La condivisione viene annotata nel registro di IAGO."
                ),
                systemImage: "lock.open"
            )
            .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            if let failure {
                Text(failure).font(.caption).foregroundStyle(.red)
            }
            HStack {
                if preparing { ProgressView().controlSize(.small) }
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Salva in una cartella…")) { saveToFolder() }
                    .disabled(chosen.isEmpty || preparing)
                Button(String(localized: "Condividi…")) { share() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(chosen.isEmpty || preparing)
                    .background(ShareAnchorView(anchor: anchor))
            }
        }
        .padding(20)
        .frame(width: 480)
        .task { load() }
    }

    // MARK: Parts

    private func binding(_ part: ItemShare.Part) -> Binding<Bool> {
        Binding(
            get: { chosen.contains(part) },
            set: { on in
                if on { chosen.insert(part) } else { chosen.remove(part) }
            })
    }

    private func name(_ part: ItemShare.Part) -> String {
        switch part {
        case .card: String(localized: "Scheda (Markdown)")
        case .transcript:
            item.type == .call ? String(localized: "Trascrizione") : String(localized: "Testo (Markdown)")
        case .otherTranscript: String(localized: "Altra trascrizione")
        case .audio: String(localized: "Audio")
        case .tracks: String(localized: "Tracce separate")
        case .original:
            switch item.type {
            case .email: String(localized: "Email originale (.eml)")
            case .document: String(localized: "Documento originale")
            case .call: String(localized: "Trascrizione Teams originale")
            }
        case .screenshots: String(localized: "Schermate")
        }
    }

    private func detail(_ part: ItemShare.Part) -> String {
        switch part {
        case .card: String(localized: "Data, progetto, sintesi, punti chiave e note")
        case .transcript:
            item.type == .call
                ? String(localized: "La trascrizione principale, con i nomi degli speaker")
                : String(localized: "Il testo estratto")
        case .otherTranscript: String(localized: "La seconda trascrizione della call (IAGO o Teams)")
        case .audio: String(localized: "Un file .m4a da ascoltare")
        case .tracks: String(localized: "Microfono e audio del Mac, in due file")
        case .original: String(localized: "Il file così come è arrivato")
        case .screenshots: String(localized: "Le schermate catturate durante la call, con il loro minuto")
        }
    }

    private func load() {
        let archive = model.archive
        available = (try? ItemShare.available(item.id, archive: archive)) ?? [.card]
        chosen = chosen.intersection(available)
        for part in available {
            let assets = (try? ItemShare.assets(part, itemID: item.id, archive: archive)) ?? []
            sizes[part] = assets.compactMap(\.sizeBytes).reduce(0, +)
        }
    }

    // MARK: Actions

    /// Decrypts the chosen parts into a fresh temporary folder: `IAGO-Condividi/<uuid>/<date title>/`. The previous
    /// share's folder goes first.
    private func prepare() async throws -> [URL] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("IAGO-Condividi")
        try? FileManager.default.removeItem(at: root)
        let folder = root.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(ItemShare.folderName(item))
        let archive = model.archive
        let parts = chosen
        let itemID = item.id
        let zip = self.zip
        let work = model.activity.begin(.share, item.title)
        defer { model.activity.end(work) }
        let files = try await Task.detached(priority: .userInitiated) {
            let files = try ItemShare.write(parts, itemID: itemID, archive: archive, to: folder)
            return zip ? [try ItemShare.zip(folder)] : files
        }.value
        try? archive.audit(
            .export, action: "share",
            detail: "item \(itemID), \(parts.map(\.rawValue).sorted().joined(separator: ",")), \(files.count) files")
        return files
    }

    private func share() {
        failure = nil
        preparing = true
        Task {
            defer { preparing = false }
            do {
                let files = try await prepare()
                anchor.show(files)
            } catch {
                failure = error.localizedDescription
            }
        }
    }

    private func saveToFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Salva qui")
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        failure = nil
        preparing = true
        Task {
            defer { preparing = false }
            do {
                for file in try await prepare() {
                    var target = destination.appendingPathComponent(file.lastPathComponent)
                    var copy = 2
                    while FileManager.default.fileExists(atPath: target.path) {
                        target = destination.appendingPathComponent(
                            "\(file.deletingPathExtension().lastPathComponent) (\(copy)).\(file.pathExtension)")
                        copy += 1
                    }
                    try FileManager.default.copyItem(at: file, to: target)
                }
                NSWorkspace.shared.activateFileViewerSelecting([destination])
                dismiss()
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

/// The view the Share menu opens from.
@MainActor final class ShareAnchor {
    weak var view: NSView?

    func show(_ files: [URL]) {
        guard let view else { return }
        NSSharingServicePicker(items: files).show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}

private struct ShareAnchorView: NSViewRepresentable {
    let anchor: ShareAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { anchor.view = nsView }
}
