import IAGOStore
import SwiftUI

/// Hosts the playback bar in a titlebar accessory, under the recording bar: shown from the first play until
/// the X, in every section of the window.
struct PlaybackBarHost: View {
    let model: AppModel

    var body: some View {
        if model.player.isActive, let itemID = model.player.itemID {
            PlaybackBar(model: model, player: model.player, itemID: itemID)
        } else {
            Color.clear.frame(height: 0)
        }
    }
}

/// What is being listened to (Cliente › Progetto › Stream › Elemento, a click opens the item) and its
/// controls. The X stops the audio and closes the bar; a pause keeps it.
struct PlaybackBar: View {
    let model: AppModel
    @Bindable var player: AudioPlayerModel
    let itemID: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(full: true)
            row(full: false)
        }
        .controlSize(.small)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
        // Solid, like the recording bar.
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func row(full: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform").foregroundStyle(.purple)
                .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
            PlaybackPath(model: model, itemID: itemID, full: full)
                .frame(minWidth: full ? 280 : 80, alignment: .leading)
            Spacer(minLength: 4)
            Button(String(localized: "Indietro di 15 secondi"), systemImage: "gobackward.15") {
                player.skip(by: -15)
            }
            .labelStyle(.iconOnly).buttonStyle(.borderless)
            Button(
                player.isPlaying ? String(localized: "Pausa") : String(localized: "Riprendi"),
                systemImage: player.isPlaying ? "pause.fill" : "play.fill"
            ) { player.togglePlay() }
            .labelStyle(.iconOnly)
            .disabled(player.isLoading)
            Button(String(localized: "Avanti di 15 secondi"), systemImage: "goforward.15") { player.skip(by: 15) }
                .labelStyle(.iconOnly).buttonStyle(.borderless)
            if full {
                Slider(
                    value: Binding(get: { player.currentTime }, set: { player.seek(to: $0, play: false) }),
                    in: 0...max(player.duration, 1)
                )
                .frame(width: 140)
            }
            Text("\(Format.clock(player.currentTime)) / \(Format.clock(player.duration))").monospacedDigit()
                .foregroundStyle(.secondary).lineLimit(1).fixedSize()
            if full, let kind = player.asset?.kind {
                Text("· \(kind.trackName)").foregroundStyle(.secondary).lineLimit(1).fixedSize()
            }
            Button(String(localized: "Chiudi e ferma l'audio"), systemImage: "xmark") { player.close() }
                .labelStyle(.iconOnly).buttonStyle(.borderless)
                .help(String(localized: "Chiudi e ferma l'audio"))
        }
    }
}

/// Cliente › Progetto › Stream › Elemento. The compact form keeps the client (or the project) and the item.
private struct PlaybackPath: View {
    let model: AppModel
    let itemID: String
    let full: Bool

    var body: some View {
        let parts = Self.parts(model: model, itemID: itemID)
        let ancestors = full ? parts.ancestors : Array(parts.ancestors.prefix(1))
        Button {
            model.openItem?(itemID)
        } label: {
            HStack(spacing: 4) {
                ForEach(Array(ancestors.enumerated()), id: \.offset) { _, name in
                    Text(name).foregroundStyle(.secondary).lineLimit(1)
                    Text("›").foregroundStyle(.tertiary)
                }
                Text(parts.title).bold().lineLimit(1).layoutPriority(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Apri l'elemento"))
    }

    static func parts(model: AppModel, itemID: String) -> (ancestors: [String], title: String) {
        guard let item = model.item(itemID) else { return ([], "") }
        guard let project = model.project(item.projectId) else {
            return ([String(localized: "Da classificare")], item.title)
        }
        let client = model.client(project.clientId)?.name ?? String(localized: "Senza cliente")
        let streams = ((try? model.archive.streamIDs(itemID: itemID)) ?? []).compactMap { model.stream($0)?.name }
        let ancestors = [client, project.name] + (streams.isEmpty ? [] : [streams.sorted().joined(separator: ", ")])
        return (ancestors, item.title)
    }
}

extension Asset.Kind {
    /// The track names of the player (Mix, Solo microfono, Solo sistema).
    var trackName: String {
        switch self {
        case .audioMix: String(localized: "Mix")
        case .audioMic: String(localized: "Solo microfono")
        case .audioSystem: String(localized: "Solo sistema")
        case .audioImport: String(localized: "Audio importato")
        default: rawValue
        }
    }
}
