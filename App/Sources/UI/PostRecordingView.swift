import IAGOStore
import SwiftUI

/// Panel shown after Stop (FR-20, FR-21): classify and choose what to do. Closing it without a choice
/// leaves the item "Da classificare" with no transcription; everything can be changed later.
struct PostRecordingView: View {
    let model: AppModel
    let itemID: String
    let close: () -> Void
    @State private var roomMode = false
    @State private var markers: [Marker] = []
    @State private var decision: DecisionDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let item = model.item(itemID) {
                Text(String(localized: "Registrazione salvata")).font(.caption).foregroundStyle(.secondary)
                MetadataEditor(model: model, item: item, compact: true)
                if !markers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Segnalibri")).font(.headline)
                        ForEach(markers) { marker in
                            HStack {
                                Text(
                                    "\(Format.clock(marker.atSec))  \(marker.note ?? String(localized: "Momento segnato"))"
                                )
                                .font(.callout)
                                Spacer()
                                if marker.status == .open {
                                    Button(String(localized: "Diventa decisione…")) {
                                        var draft = DecisionDraft(
                                            item: item, atSec: marker.atSec, text: marker.note ?? "", origin: .marker)
                                        draft.markerID = marker.id
                                        decision = draft
                                    }
                                    .buttonStyle(.link)
                                } else if marker.status == .converted {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
                Divider()
                if item.source == .recording {
                    Toggle(String(localized: "Più persone nella stanza"), isOn: $roomMode)
                        .help(String(localized: "Distingue le voci anche nel microfono del Mac"))
                }
                ActionGrid {
                    ActionLink(title: String(localized: "Trascrivi e conserva l'audio"), isPrimary: true) {
                        transcribe(deleteAudio: false)
                    }
                    .keyboardShortcut(.defaultAction)
                    ActionLink(
                        title: String(localized: "Trascrivi ed elimina l'audio"),
                        detail: String(localized: "L'audio si elimina dopo la verifica della trascrizione")
                    ) { transcribe(deleteAudio: true) }
                    ActionLink(title: String(localized: "Conserva solo l'audio")) { close() }
                    ActionLink(
                        title: String(localized: "Scarta"),
                        detail: String(localized: "Resta 1 ora in \"Scartate temporanee\""),
                        role: .destructive
                    ) {
                        model.discardItem(itemID)
                        close()
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 520)
        .sheet(item: $decision) { draft in DecisionEditor(model: model, draft: draft) }
        .task(id: model.revision) { markers = (try? model.archive.markers(itemID: itemID)) ?? [] }
    }

    private func transcribe(deleteAudio: Bool) {
        model.transcribe(itemID, deleteAudio: deleteAudio, roomMode: roomMode)
        close()
        // Visible feedback: the item opens with its progress bar.
        model.openItem?(itemID)
    }
}
