import IAGOStore
import SwiftUI

/// Trash (ADR-0030): restore, delete for good, empty; days left before the automatic deletion.
struct TrashView: View {
    @Bindable var model: AppModel
    @State private var confirmEmpty = false

    var body: some View {
        List {
            if !model.discardedItems.isEmpty {
                Section {
                    ForEach(model.discardedItems) { item in
                        TrashRow(
                            title: item.title,
                            subtitle: item.occurredAt.formatted(date: .abbreviated, time: .shortened),
                            remaining: String(
                                localized:
                                    "eliminata tra \(model.minutesLeft(discardedAt: item.trashedAt ?? Date())) min"),
                            restore: { model.perform { try model.archive.restoreItem(item.id) } },
                            purge: { model.deleteItem(item.id, .permanent) })
                    }
                } header: {
                    Text(String(localized: "Scartate temporanee"))
                } footer: {
                    Text(String(localized: "Registrazioni scartate durante la registrazione: restano 1 ora."))
                }
            }
            if !model.trashedItems.isEmpty {
                Section(String(localized: "Elementi")) {
                    ForEach(model.trashedItems) { item in
                        TrashRow(
                            title: item.title,
                            subtitle: item.occurredAt.formatted(date: .abbreviated, time: .shortened),
                            remaining: String(
                                localized: "eliminato tra \(model.daysLeft(trashedAt: item.trashedAt ?? Date())) giorni"
                            ),
                            restore: { model.perform { try model.archive.restoreItem(item.id) } },
                            purge: { model.deleteItem(item.id, .permanent) })
                    }
                }
            }
            if !model.trashedAssets.isEmpty {
                Section(String(localized: "File")) {
                    ForEach(model.trashedAssets) { asset in
                        TrashRow(
                            title: Self.assetName(asset.kind), subtitle: model.item(asset.itemId)?.title ?? "",
                            remaining: String(
                                localized:
                                    "eliminato tra \(model.daysLeft(trashedAt: asset.trashedAt ?? Date())) giorni"),
                            restore: { model.perform { try model.archive.restoreAsset(asset.id) } },
                            purge: { model.deleteAsset(asset, .permanent) })
                    }
                }
            }
        }
        .overlay {
            if model.trashedItems.isEmpty && model.trashedAssets.isEmpty && model.discardedItems.isEmpty {
                ContentUnavailableView(
                    String(localized: "Il cestino è vuoto"), systemImage: "trash",
                    description: Text(
                        String(localized: "Ciò che sposti nel cestino viene eliminato definitivamente dopo 30 giorni."))
                )
            }
        }
        .toolbar {
            Button(String(localized: "Svuota cestino"), role: .destructive) { confirmEmpty = true }
                .disabled(model.trashedItems.isEmpty && model.trashedAssets.isEmpty && model.discardedItems.isEmpty)
        }
        .confirmationDialog(
            String(localized: "Svuotare il cestino?"), isPresented: $confirmEmpty, titleVisibility: .visible
        ) {
            Button(String(localized: "Elimina definitivamente tutto"), role: .destructive) {
                model.perform { try model.archive.emptyTrash() }
            }
        } message: {
            Text(String(localized: "L'operazione non si può annullare."))
        }
    }

    static func assetName(_ kind: Asset.Kind) -> String {
        switch kind {
        case .audioMix: String(localized: "Audio (mix)")
        case .audioMic: String(localized: "Traccia microfono")
        case .audioSystem: String(localized: "Traccia sistema")
        case .audioImport: String(localized: "Audio importato")
        case .transcriptJSON, .transcriptTXT, .transcriptMD: String(localized: "Trascrizione")
        case .originalDocument, .originalImage, .contentMD: String(localized: "Documento")
        case .originalTranscript: String(localized: "Trascrizione originale")
        case .noteAttachment: String(localized: "Allegato")
        case .originalEmail: String(localized: "Email originale (.eml)")
        case .contentMDAuto: String(localized: "Testo automatico")
        }
    }
}

private struct TrashRow: View {
    let title: String
    let subtitle: String
    let remaining: String
    let restore: () -> Void
    let purge: () -> Void
    @State private var confirming = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).lineLimit(1)
                Text("\(subtitle) · \(remaining)").font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(String(localized: "Ripristina"), action: restore).buttonStyle(.link)
            Button(String(localized: "Elimina"), role: .destructive) { confirming = true }.buttonStyle(.link)
        }
        .confirmationDialog(String(localized: "Eliminare definitivamente?"), isPresented: $confirming) {
            Button(String(localized: "Elimina definitivamente"), role: .destructive, action: purge)
        }
    }
}
