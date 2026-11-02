import IAGOStore
import SwiftUI

// Item detail navigation (ADR-0084): tiles under the title, the sticky bar on scroll, «torna su», sections open or
// closed per item, the moments on the player.

/// Which sections are open in one item. Each item remembers its own choices; a section never touched there starts
/// as chosen in Settings › Generale › Dettaglio elemento (`section.collapsed.<key>`, the old global choice).
@MainActor
@Observable
final class SectionMemory {
    let itemID: String
    private var collapsed: [String: Bool]

    init(itemID: String) {
        self.itemID = itemID
        collapsed = UserDefaults.standard.dictionary(forKey: Self.storageKey(itemID)) as? [String: Bool] ?? [:]
    }

    func isCollapsed(_ key: String) -> Bool { collapsed[key] ?? Self.defaultCollapsed(key) }

    func setCollapsed(_ key: String, _ value: Bool) {
        collapsed[key] = value
        // A demo archive shares the user's preferences: its items are not remembered there.
        guard !DemoMode.isActive else { return }
        UserDefaults.standard.set(collapsed, forKey: Self.storageKey(itemID))
    }

    static func defaultKey(_ key: String) -> String { "section.collapsed.\(key)" }
    static func defaultCollapsed(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: defaultKey(key)) }
    private static let prefix = "section.item."
    private static func storageKey(_ itemID: String) -> String { prefix + itemID }

    /// «Riapplica a tutti gli elementi…»: every item goes back to the defaults.
    static func forgetAll() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

extension EnvironmentValues {
    /// Set by the item view: its sections open and close for that item only.
    @Entry var sectionMemory: SectionMemory?
}

/// Where each section of the item view starts, in the scrolling content (`ItemDetailView.space`).
struct SectionTopsKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Settings for the moments (ADR-0084).
enum DetailMoments {
    static let inTranscriptKey = "detail.momentsInTranscript"
    static let onPlayerKey = "detail.momentsOnPlayer"
}

// MARK: - Tiles

/// One tile: a section and a single value. `key` is the section's collapse key, also its scroll anchor.
struct DetailTile: Identifiable {
    let key: String
    let title: String
    let value: String
    let tint: Color
    var isEmpty = false

    var id: String { key }
}

/// The small tiles under the title: low and wide, wrapping on their own. A click opens the section and goes there.
struct DetailTiles: View {
    let tiles: [DetailTile]
    let open: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(tiles) { tile in
                Button {
                    open(tile.key)
                } label: {
                    HStack(spacing: 10) {
                        Text(tile.title).fontWeight(.semibold).foregroundStyle(tile.isEmpty ? .secondary : tile.tint)
                        Spacer(minLength: 0)
                        Text(tile.value).fontWeight(.semibold).monospacedDigit()
                            .foregroundStyle(tile.isEmpty ? Color.secondary : tile.value == "✓" ? tile.tint : .primary)
                    }
                    .font(.callout)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .frame(minWidth: 118)
                    .background(TileShape(isEmpty: tile.isEmpty, radius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(String(localized: "Vai a \(tile.title)"))
            }
        }
    }
}

/// White with a thin border; dashed and grey when the section is empty.
struct TileShape: View {
    let isEmpty: Bool
    var radius: CGFloat = 8
    var highlighted = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        shape.fill(
            highlighted
                ? Color.accentColor.opacity(0.12)
                : isEmpty ? Color.secondary.opacity(0.06) : Color(nsColor: .controlBackgroundColor)
        )
        .overlay(
            shape.strokeBorder(
                highlighted ? Color.accentColor : Color.secondary.opacity(isEmpty ? 0.35 : 0.22),
                style: StrokeStyle(lineWidth: 1, dash: isEmpty && !highlighted ? [3, 2] : []))
        )
    }
}

/// After scrolling past the tiles: title, client › project · date · duration on the next line, the tiles in
/// miniature with the current section highlighted.
struct DetailStickyBar: View {
    let title: String
    let subtitle: String
    let tiles: [DetailTile]
    let active: String?
    let open: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.semibold)).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            FlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(tiles) { tile in
                    Button {
                        open(tile.key)
                    } label: {
                        HStack(spacing: 6) {
                            Text(tile.title).fontWeight(.semibold)
                                .foregroundStyle(tile.isEmpty ? .secondary : tile.tint)
                            Text(tile.value).fontWeight(.semibold).monospacedDigit()
                                .foregroundStyle(
                                    tile.isEmpty ? Color.secondary : tile.value == "✓" ? tile.tint : .primary)
                        }
                        .font(.caption)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(TileShape(isEmpty: tile.isEmpty, radius: 6, highlighted: tile.key == active))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

/// «Torna su», bottom right above «Chiedi a IAGO» (ADR-0084): only while the sticky bar is shown.
struct BackToTopButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up").font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(Circle().fill(.regularMaterial))
        .overlay(Circle().strokeBorder(Color.secondary.opacity(0.2)))
        .shadow(color: .black.opacity(hovering ? 0.25 : 0.15), radius: hovering ? 12 : 8, y: 3)
        .onHover { hovering = $0 }
        .help(String(localized: "Torna su"))
        .accessibilityLabel(String(localized: "Torna su"))
    }
}

// MARK: - Moments

/// A bookmark or a screenshot of a call, on the player and in the transcript.
struct DetailMoment: Identifiable, Equatable {
    enum Kind { case bookmark, screenshot }
    let id: String
    let kind: Kind
    let atSec: Double
    let title: String
    /// The screenshot, to show its thumbnail.
    var asset: Asset?

    var color: Color { kind == .bookmark ? .orange : .teal }

    static func from(markers: [Marker], shots: [Asset]) -> [DetailMoment] {
        let bookmarks = markers.filter { $0.status != .dismissed }.map {
            DetailMoment(
                id: "m\($0.id)", kind: .bookmark, atSec: $0.atSec,
                title: $0.note ?? String(localized: "Momento segnato"))
        }
        let screenshots = shots.map { shot in
            DetailMoment(
                id: "p\(shot.id)", kind: .screenshot, atSec: shot.atSec ?? 0,
                title: shot.text?.split(separator: "\n").first.map(String.init) ?? String(localized: "Schermata"),
                asset: shot)
        }
        return (bookmarks + screenshots).sorted { $0.atSec < $1.atSec }
    }
}

/// Ticks over the player's bar: where the moments are. Drawn under the knob's travel, not clickable (the bar is).
struct MomentTicks: View {
    let moments: [DetailMoment]
    let duration: Double
    let selected: String?

    var body: some View {
        GeometryReader { geometry in
            // The knob's centre never reaches the ends of the bar: the ticks follow the same travel.
            let inset: CGFloat = 9
            let width = max(geometry.size.width - inset * 2, 1)
            ForEach(moments) { moment in
                Capsule()
                    .fill(moment.color)
                    .frame(width: 3, height: moment.id == selected ? 16 : 12)
                    .overlay(
                        Capsule().stroke(Color.primary.opacity(moment.id == selected ? 0.7 : 0), lineWidth: 1)
                    )
                    .position(
                        x: inset + width * CGFloat(min(max(moment.atSec / max(duration, 1), 0), 1)),
                        y: geometry.size.height / 2)
            }
        }
        .allowsHitTesting(false)
    }
}

/// One moment at a time under the player (ADR-0084): ‹ ›, «N di M», the minute plays from there. Without a choice it
/// shows the next moment from where the audio is, and follows the audio while it plays. Fixed height, never empty.
struct MomentCard: View {
    let model: AppModel
    let moments: [DetailMoment]
    let currentTime: Double
    let listen: (Double) -> Void
    @Binding var chosen: String?
    @State private var images: [String: NSImage] = [:]

    private var automatic: Int {
        moments.firstIndex { $0.atSec >= currentTime - 0.5 } ?? moments.count - 1
    }

    private var index: Int {
        chosen.flatMap { id in moments.firstIndex { $0.id == id } } ?? automatic
    }

    var body: some View {
        let moment = moments[index]
        HStack(spacing: 12) {
            Button {
                chosen = moments[(index + moments.count - 1) % moments.count].id
            } label: {
                Image(systemName: "chevron.left").frame(width: 14)
            }
            .help(String(localized: "Momento precedente"))
            thumbnail(moment)
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    "\(moment.kind == .bookmark ? String(localized: "Segnalibro") : String(localized: "Schermata")) · \(String(localized: "\(index + 1) di \(moments.count)"))"
                )
                .font(.caption.weight(.semibold)).foregroundStyle(moment.color)
                Text(moment.title).font(.callout.weight(.semibold)).lineLimit(2)
                HStack(spacing: 4) {
                    Button(Format.clock(moment.atSec)) { listen(moment.atSec) }
                        .buttonStyle(.link).monospacedDigit()
                        .help(String(localized: "Ascolta da questo punto"))
                    Text(String(localized: "· un clic fa partire l'audio da lì")).foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                chosen = moments[(index + 1) % moments.count].id
            } label: {
                Image(systemName: "chevron.right").frame(width: 14)
            }
            .help(String(localized: "Momento successivo"))
        }
        .frame(height: 68)
        .padding(.top, 10)
        .overlay(alignment: .top) { Divider() }
        .task(id: moment.id) { await loadImage(moment) }
    }

    @ViewBuilder
    private func thumbnail(_ moment: DetailMoment) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        Group {
            if let image = images[moment.id] {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: moment.kind == .bookmark ? "bookmark.fill" : "camera.viewfinder")
                    .font(.title3).foregroundStyle(moment.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(moment.color.opacity(0.12))
            }
        }
        .frame(width: 104, height: 64)
        .clipShape(shape)
        .overlay(shape.stroke(moment.color.opacity(0.4)))
    }

    private func loadImage(_ moment: DetailMoment) async {
        guard let asset = moment.asset, images[moment.id] == nil else { return }
        let archive = model.archive
        // Decrypted in memory only, never written to disk.
        let data = await Task.detached { try? archive.readAssetData(asset) }.value
        if let data, let image = NSImage(data: data) { images[moment.id] = image }
    }
}

// MARK: - Settings

/// Settings › Generale › Dettaglio elemento (ADR-0084): how sections start in an item not touched yet, the moments.
struct ItemDetailSettings: View {
    @AppStorage(DetailMoments.inTranscriptKey) private var inTranscript = true
    @AppStorage(DetailMoments.onPlayerKey) private var onPlayer = true
    @State private var confirmReset = false
    /// The defaults as shown: `UserDefaults` is not observed.
    @State private var closed: [String: Bool] = [:]

    /// Rows of the defaults: a label and the sections it sets.
    private static let rows: [(String, [String])] = [
        (String(localized: "Sintesi"), ["summary"]),
        (String(localized: "Punti chiave"), ["decisions"]),
        (String(localized: "Proposte"), ["suggestions"]),
        (String(localized: "Note"), ["notes"]),
        (String(localized: "Trascrizione e contenuto"), ["transcript", "content", "email"]),
        (String(localized: "Segnalibri"), ["markers"]),
        (String(localized: "Schermate"), ["screenshots"]),
        (String(localized: "Collegamenti"), ["links"]),
    ]

    var body: some View {
        SettingsGroup(
            title: String(localized: "Dettaglio elemento"),
            footnote: String(
                localized:
                    "Come si aprono le sezioni in un elemento che non hai ancora toccato. Ogni elemento poi ricorda cosa apri e chiudi lì dentro."
            )
        ) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(Self.rows, id: \.0) { row in
                    GridRow {
                        Text(row.0)
                        Picker("", selection: binding(row.1)) {
                            Text(String(localized: "Aperta")).tag(false)
                            Text(String(localized: "Chiusa")).tag(true)
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                }
                GridRow {
                    Text(String(localized: "File"))
                    Text(String(localized: "Sempre aperta")).foregroundStyle(.secondary)
                }
            }
            Divider()
            Toggle(
                String(localized: "Segnalibri e schermate anche nella trascrizione, nel loro momento"),
                isOn: $inTranscript)
            Toggle(String(localized: "Momenti sul player audio"), isOn: $onPlayer)
            HStack(spacing: 8) {
                Button(String(localized: "Riapplica a tutti gli elementi…")) { confirmReset = true }
                Text(String(localized: "Dimentica le scelte fatte nei singoli elementi.")).font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog(
            String(localized: "Riapplicare queste scelte a tutti gli elementi?"), isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Riapplica")) { SectionMemory.forgetAll() }
            Button(String(localized: "Annulla"), role: .cancel) {}
        } message: {
            Text(
                String(
                    localized:
                        "Le sezioni aperte e chiuse nei singoli elementi tornano come indicato qui. Non si può annullare."
                ))
        }
    }

    private func binding(_ keys: [String]) -> Binding<Bool> {
        Binding(
            get: { closed[keys[0]] ?? SectionMemory.defaultCollapsed(keys[0]) },
            set: { value in
                for key in keys {
                    closed[key] = value
                    UserDefaults.standard.set(value, forKey: SectionMemory.defaultKey(key))
                }
            })
    }
}
