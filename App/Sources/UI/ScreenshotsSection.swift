import AppKit
import IAGOStore
import SwiftUI

/// "Schermate" in the card of a call (ADR-0072): the screenshots taken with «Segna momento con screenshot», in order
/// of time. A click opens the image with the text read on it; the minute plays the call from there.
struct ScreenshotsSection: View {
    let model: AppModel
    let itemID: String
    let listen: (Double) -> Void
    @State private var shots: [Asset] = []
    @State private var images: [String: NSImage] = [:]
    @State private var open: Asset?

    var body: some View {
        Group {
            if shots.isEmpty {
                SectionBox(
                    String(localized: "Schermate"), systemImage: "camera.viewfinder", tint: .teal,
                    collapseKey: "screenshots",
                    emptyText: String(
                        localized: "Nessuna schermata: durante la call usa «Segna momento con screenshot»")
                ) { EmptyView() }
            } else {
                SectionBox(
                    String(localized: "Schermate"), systemImage: "camera.viewfinder", tint: .teal,
                    collapseKey: "screenshots", detail: "\(shots.count)"
                ) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading) {
                        ForEach(shots) { shot in
                            VStack(alignment: .leading, spacing: 4) {
                                thumbnail(shot)
                                    .onTapGesture { open = shot }
                                    .help(shot.text ?? String(localized: "Nessun testo letto"))
                                Button(Format.clock(shot.atSec ?? 0)) { listen(shot.atSec ?? 0) }
                                    .buttonStyle(.link).monospacedDigit().font(.caption)
                                    .help(String(localized: "Ascolta da questo punto"))
                            }
                        }
                    }
                }
            }
        }
        .task(id: model.revision) { await load() }
        .sheet(item: $open) { shot in
            ScreenshotViewer(model: model, shot: shot, image: images[shot.id]) {
                listen(shot.atSec ?? 0)
                open = nil
            } onDelete: {
                model.perform { try model.archive.deleteScreenshot(shot.id) }
                open = nil
                Task { await load() }
            }
        }
    }

    private func thumbnail(_ shot: Asset) -> some View {
        Group {
            if let image = images[shot.id] {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Rectangle().fill(.quaternary).overlay(ProgressView().controlSize(.small))
            }
        }
        .frame(width: 150, height: 94)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
    }

    private func load() async {
        let archive = model.archive
        let itemID = itemID
        shots = (try? archive.screenshots(itemID: itemID)) ?? []
        for shot in shots where images[shot.id] == nil {
            // Decrypted in memory only, never written to disk.
            let data = await Task.detached { try? archive.readAssetData(shot) }.value
            if let data, let image = NSImage(data: data) { images[shot.id] = image }
        }
    }
}

private struct ScreenshotViewer: View {
    let model: AppModel
    let shot: Asset
    let image: NSImage?
    let listen: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Schermata a \(Format.clock(shot.atSec ?? 0))")).font(.headline)
                Spacer()
                Button(String(localized: "Ascolta da qui"), systemImage: "play.fill", action: listen)
                Button(String(localized: "Elimina…"), systemImage: "trash", role: .destructive) { confirmDelete = true }
                Button(String(localized: "Chiudi")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if let image {
                Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: 900, maxHeight: 560)
            }
            if let text = shot.text {
                GroupBox(String(localized: "Testo letto")) {
                    ScrollView {
                        Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 140)
                }
            } else {
                Text(String(localized: "Nessun testo letto su questa schermata.")).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 640)
        .confirmationDialog(
            String(localized: "Eliminare la schermata?"), isPresented: $confirmDelete, titleVisibility: .visible
        ) {
            Button(String(localized: "Elimina"), role: .destructive, action: onDelete)
        } message: {
            Text(String(localized: "L'immagine e il suo testo spariscono dalla call e dalla ricerca."))
        }
    }
}
