import AppKit
import SwiftUI

/// «Importa file ed elementi…», the last entry of a project's «Aggiungi» (ADR-0076): the ways of «Importa», with the
/// project already chosen. What comes in goes into that project, not into «Elementi da classificare».
struct ImportSheet: View {
    let model: AppModel
    @State private var target: AppModel.ImportTarget
    @State private var isDropTargeted = false
    @State private var clipboard: AppModel.ClipboardContent?
    @State private var writingText = false
    @State private var text = ""
    @State private var title = ""
    @State private var saving = false
    @FocusState private var textFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, target: AppModel.ImportTarget) {
        self.model = model
        _target = State(initialValue: target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                String(localized: "Importa in \(model.project(target.projectID)?.name ?? "")"),
                systemImage: "square.and.arrow.down"
            )
            .font(.title2).bold()
            dropArea
            HStack(spacing: 8) {
                way(String(localized: "Dagli appunti"), "doc.on.clipboard", selected: clipboard != nil) {
                    writingText = false
                    clipboard = clipboard == nil ? model.clipboardContent() : nil
                }
                way(String(localized: "Da testo"), "text.alignleft", selected: writingText) {
                    clipboard = nil
                    writingText.toggle()
                    if writingText { textFocused = true }
                }
                way(String(localized: "Email senza file"), "envelope.badge", selected: false) {
                    let projectID = target.projectID
                    dismiss()
                    DispatchQueue.main.async {
                        model.composingEmailProject = projectID
                        model.composingEmail = true
                    }
                }
            }
            if let clipboard { clipboardPanel(clipboard) }
            if writingText { textPanel }
            destination
            HStack {
                Spacer()
                Button(String(localized: "Annulla"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 580)
    }

    /// The area to drop files on; small while the text is being written, so a file can still be dropped.
    private var dropArea: some View {
        let compact = writingText || clipboard != nil
        return Group {
            if compact {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down").foregroundStyle(.tint)
                    Text(String(localized: "Trascina qui un file, oppure"))
                    Button(String(localized: "scegli dal Mac…")) { choose() }.buttonStyle(.link)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down").font(.system(size: 28)).foregroundStyle(.tint)
                    Text(String(localized: "Trascina qui file, cartelle o email")).font(.headline)
                    Text(
                        String(
                            localized:
                                "Audio e video da trascrivere, PDF, Word, immagini, trascrizioni Teams, email da Outlook o Mail"
                        )
                    )
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button(String(localized: "Scegli dal Mac…")) { choose() }.padding(.top, 4)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24).padding(.horizontal, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10).fill(isDropTargeted ? Color.accentColor.opacity(0.08) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(
                isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .onDrop(of: [.item], isTargeted: $isDropTargeted) { providers in
            let scratch = model.archiveService.paths.scratch
            let target = self.target
            Task {
                let urls = await MainView.fileURLs(providers, scratch: scratch)
                model.importFiles(urls, into: target)
            }
            dismiss()
            return true
        }
    }

    private func way(_ title: String, _ icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered).tint(selected ? .accentColor : nil)
    }

    /// «Vanno in»: the project, and its streams if it has any.
    private var destination: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                Text(String(localized: "Vanno in")).foregroundStyle(.secondary)
                Picker("", selection: $target.projectID) {
                    ForEach(model.projects) { Text($0.name).tag($0.id) }
                }
                .labelsHidden().fixedSize()
                .onChange(of: target.projectID) { _, _ in target.streamIDs = [] }
            }
            if !model.streams(of: target.projectID).isEmpty {
                GridRow(alignment: .top) {
                    Text(String(localized: "Stream")).foregroundStyle(.secondary)
                    StreamChooser(model: model, projectID: target.projectID, selection: $target.streamIDs)
                }
            }
        }
    }

    private func choose() {
        let target = self.target
        dismiss()
        DispatchQueue.main.async { model.chooseFilesToImport(into: target) }
    }

    // MARK: Clipboard and text

    @ViewBuilder
    private func clipboardPanel(_ content: AppModel.ClipboardContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch content {
            case .files(let urls):
                Label(String(localized: "Negli appunti: \(urls.count) file"), systemImage: "doc.on.doc")
                    .font(.headline)
                Text(urls.prefix(6).map(\.lastPathComponent).joined(separator: "\n") + (urls.count > 6 ? "\n…" : ""))
                    .font(.callout).foregroundStyle(.secondary)
                confirm(String(localized: "Importa i file")) { model.importFiles(urls, into: target) }
            case .image(let png, let size):
                Label(
                    String(localized: "Negli appunti: un'immagine \(Int(size.width))×\(Int(size.height))"),
                    systemImage: "photo"
                )
                .font(.headline)
                if let image = NSImage(data: png) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                confirm(String(localized: "Importa l'immagine")) { model.importClipboardImage(png, into: target) }
            case .text(let copied):
                Label(
                    String(localized: "Negli appunti: un testo di \(copied.count.formatted()) caratteri"),
                    systemImage: "text.alignleft"
                )
                .font(.headline)
                Text(copied.prefix(300) + (copied.count > 300 ? "…" : "")).font(.callout).foregroundStyle(.secondary)
                    .lineLimit(5)
                HStack {
                    Spacer()
                    Button(String(localized: "Modifica prima…")) {
                        clipboard = nil
                        text = copied
                        writingText = true
                    }
                    Button(String(localized: "Importa il testo")) {
                        let target = self.target
                        Task { _ = await model.importText(copied, title: "", into: target) }
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            case .empty:
                Label(String(localized: "Gli appunti sono vuoti"), systemImage: "doc.on.clipboard").font(.headline)
                Text(String(localized: "Copia un testo, un'immagine o dei file, poi riprova."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func confirm(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(title) {
                action()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var textPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(String(localized: "Titolo (facoltativo: altrimenti la prima riga)"), text: $title)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $text)
                .font(.body)
                .focused($textFocused)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 200)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(String(localized: "Incolla qui il testo (⌘V)…")).foregroundStyle(.tertiary)
                            .padding(.horizontal, 11).padding(.vertical, 6).allowsHitTesting(false)
                    }
                }
            HStack {
                Text(String(localized: "\(text.count.formatted()) caratteri")).font(.caption)
                    .foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button(String(localized: "Importa il testo")) { saveText() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
            }
        }
    }

    private func saveText() {
        saving = true
        let target = self.target
        Task {
            if await model.importText(text, title: title, into: target) { dismiss() }
            saving = false
        }
    }
}
