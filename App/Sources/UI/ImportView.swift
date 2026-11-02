import AppKit
import SwiftUI

/// "Importa" in the sidebar: every way to bring material in. Files dropped anywhere on the window are imported
/// as well (FR-30).
struct ImportView: View {
    @Bindable var model: AppModel
    @State private var clipboard: AppModel.ClipboardContent?
    @State private var writingText = false
    @State private var text = ""
    @State private var title = ""
    @State private var saving = false
    @FocusState private var textFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label(String(localized: "Importa"), systemImage: "square.and.arrow.down").font(.title2).bold()
                Text(
                    String(
                        localized:
                            "Puoi anche trascinare file, cartelle ed email da Outlook o Mail in qualsiasi punto della finestra."
                    )
                )
                .foregroundStyle(.secondary)
                option(
                    "doc", String(localized: "Da file…"),
                    String(
                        localized:
                            "Audio e video da trascrivere, documenti, immagini, PDF, trascrizioni Teams, email .eml, cartelle."
                    )
                ) { model.chooseFilesToImport() }
                option(
                    "doc.on.clipboard", String(localized: "Dagli appunti"),
                    String(
                        localized:
                            "Quello che hai appena copiato: file, un'immagine o uno screenshot (letta con l'OCR), oppure del testo. Prima di importare ti mostro cosa ho trovato."
                    ),
                    selected: clipboard != nil
                ) { clipboard = clipboard == nil ? model.clipboardContent() : nil }
                if let clipboard { clipboardPanel(clipboard) }
                option(
                    "text.alignleft", String(localized: "Da testo"),
                    String(localized: "Incolla o scrivi un testo: diventa un documento da classificare."),
                    selected: writingText
                ) { writingText ? (writingText = false) : startText("") }
                if writingText { textPanel }
                option(
                    "envelope", String(localized: "Email .eml…"),
                    String(
                        localized:
                            "Email salvate da Outlook o Mail. Puoi anche trascinarle direttamente da Outlook, anche più di una."
                    )
                ) { model.chooseFilesToImport(emailsOnly: true) }
                option(
                    "envelope.badge", String(localized: "Email senza file"),
                    String(
                        localized:
                            "Quando non puoi trascinarla: incolla il testo e scrivi mittente, destinatari e oggetto, oppure fai leggere uno screenshot della mail."
                    )
                ) {
                    model.composingEmailProject = nil
                    model.composingEmail = true
                }
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    /// What the clipboard holds, with the matching action: nothing is imported before the user confirms.
    @ViewBuilder
    private func clipboardPanel(_ content: AppModel.ClipboardContent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            switch content {
            case .files(let urls):
                Label(
                    String(localized: "Negli appunti: \(urls.count) file"), systemImage: "doc.on.doc"
                ).font(.headline)
                Text(urls.prefix(6).map(\.lastPathComponent).joined(separator: "\n") + (urls.count > 6 ? "\n…" : ""))
                    .font(.callout).foregroundStyle(.secondary)
                clipboardButtons(String(localized: "Importa i file")) { model.importFiles(urls) }
            case .image(let png, let size):
                Label(
                    String(localized: "Negli appunti: un'immagine \(Int(size.width))×\(Int(size.height))"),
                    systemImage: "photo"
                ).font(.headline)
                if let image = NSImage(data: png) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(String(localized: "Diventa un documento: il testo che contiene viene letto con l'OCR."))
                    .font(.callout).foregroundStyle(.secondary)
                clipboardButtons(String(localized: "Importa l'immagine")) { model.importClipboardImage(png) }
            case .text(let copied):
                Label(
                    String(localized: "Negli appunti: un testo di \(copied.count.formatted()) caratteri"),
                    systemImage: "text.alignleft"
                ).font(.headline)
                Text(copied.prefix(400) + (copied.count > 400 ? "…" : "")).font(.callout).foregroundStyle(.secondary)
                    .lineLimit(6)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                HStack {
                    Spacer()
                    Button(String(localized: "Annulla"), role: .cancel) { clipboard = nil }
                    Button(String(localized: "Modifica prima…")) {
                        clipboard = nil
                        startText(copied)
                    }
                    Button(String(localized: "Importa il testo")) {
                        clipboard = nil
                        Task { _ = await model.importText(copied, title: "") }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            case .empty:
                Label(String(localized: "Gli appunti sono vuoti"), systemImage: "doc.on.clipboard").font(.headline)
                Text(String(localized: "Copia un testo, un'immagine o dei file, poi riprova."))
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button(String(localized: "Riprova")) { clipboard = model.clipboardContent() }
                }
            }
        }
        .padding(.leading, 38)
    }

    private func clipboardButtons(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(String(localized: "Annulla"), role: .cancel) { clipboard = nil }
            Button(title) {
                clipboard = nil
                action()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func option(
        _ icon: String, _ title: String, _ detail: String, selected: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).font(.title3).foregroundStyle(.tint).frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "chevron.down" : "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(
                    selected ? Color.accentColor.opacity(0.08) : IAGOColor.card)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var textPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(String(localized: "Titolo (facoltativo: altrimenti la prima riga)"), text: $title)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $text)
                .font(.body)
                .focused($textFocused)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 280)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(String(localized: "Incolla qui il testo (⌘V)…")).foregroundStyle(.tertiary)
                            .padding(.horizontal, 11).padding(.vertical, 6).allowsHitTesting(false)
                    }
                }
            HStack {
                Text(String(localized: "\(text.count.formatted()) caratteri")).font(.caption).foregroundStyle(
                    .secondary
                ).monospacedDigit()
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { closeText() }
                Button(String(localized: "Importa il testo")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
            }
        }
        .padding(.leading, 38)
    }

    private func startText(_ initial: String) {
        clipboard = nil
        text = initial
        title = ""
        writingText = true
        textFocused = true
    }

    private func closeText() {
        writingText = false
        text = ""
        title = ""
    }

    private func save() {
        saving = true
        Task {
            if await model.importText(text, title: title) { closeText() }
            saving = false
        }
    }
}
