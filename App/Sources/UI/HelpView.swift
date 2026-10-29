import SwiftUI

/// "Guida di IAGO": the full user guide, full page, from Markdown chapters in the bundle (`Guide/NN-*.md`, images in
/// `Guide/img`). Updated with every change to the app (CLAUDE.md). Search looks through every chapter.
struct HelpView: View {
    let model: AppModel
    let showTour: () -> Void
    @State private var chapter: String? = GuideChapter.all.first?.id
    @State private var query = ""

    var body: some View {
        let chapters = GuideChapter.all.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
        NavigationSplitView {
            List(chapters, selection: $chapter) { chapter in
                Label(chapter.title, systemImage: chapter.symbol).tag(chapter.id)
            }
            .listStyle(.sidebar)
            .searchable(text: $query, placement: .sidebar, prompt: Text(String(localized: "Cerca nella guida")))
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let current = GuideChapter.all.first(where: { $0.id == chapter }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        MarkdownText(markdown: current.text, baseURL: GuideChapter.folder)
                        if current.id.hasPrefix("01") {
                            Button(String(localized: "Rivedi il tour di benvenuto"), action: showTour)
                                .buttonStyle(.borderedProminent)
                        }
                        navigation(current)
                    }
                    .padding(.horizontal, 48).padding(.top, 64).padding(.bottom, 32)
                    .frame(maxWidth: 860, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .id(current.id)
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    /// "← Precedente · Successivo →" at the end of a chapter.
    private func navigation(_ current: GuideChapter) -> some View {
        let all = GuideChapter.all
        let index = all.firstIndex { $0.id == current.id } ?? 0
        return HStack {
            if index > 0 {
                Button("← \(all[index - 1].title)") { chapter = all[index - 1].id }.buttonStyle(.link)
            }
            Spacer()
            if index + 1 < all.count {
                Button("\(all[index + 1].title) →") { chapter = all[index + 1].id }.buttonStyle(.link)
            }
        }
        .padding(.top, 24)
    }
}

/// A chapter of the guide: `NN-name.md`, first line `# Title`, optionally `<!-- icona: sf.symbol -->`.
struct GuideChapter: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let text: String

    /// The guide in the app's language (ADR-0077): `Guide` in Italian, `Guide/en` in English.
    static let folder: URL? = {
        let italian = Bundle.main.url(forResource: "Guide", withExtension: nil)
        guard AppLanguage.current == .en, let english = italian?.appendingPathComponent("en"),
            FileManager.default.fileExists(atPath: english.path)
        else { return italian }
        return english
    }()

    static let all: [GuideChapter] = {
        guard let folder,
            let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return [] }
        return files.filter { $0.pathExtension == "md" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let lines = text.components(separatedBy: "\n")
                let title = lines.first { $0.hasPrefix("# ") }.map { String($0.dropFirst(2)) } ?? url.lastPathComponent
                let symbol =
                    lines.lazy.compactMap { $0.firstMatch(of: /<!--\s*icona:\s*([\w.]+)\s*-->/) }.first
                    .map { String($0.1) } ?? "doc.text"
                let body = lines.filter { !$0.hasPrefix("<!--") }.joined(separator: "\n")
                return GuideChapter(
                    id: url.deletingPathExtension().lastPathComponent, title: title, symbol: symbol, text: body)
            }
    }()
}

/// The welcome tour at launch, until "Non mostrare più" (then from Aiuto › Primi passi).
struct WelcomeTour: View {
    let onClose: (_ dontShowAgain: Bool) -> Void
    let openHelp: () -> Void
    @State private var page = 0
    @State private var dontShowAgain = false

    struct Page {
        let symbol: String
        let title: String
        let text: String
    }

    /// `symbol` "iago": IAGO's own menu bar icon, as the user will find it at the top of the screen.
    static let pages: [Page] = [
        .init(
            symbol: "brain.head.profile", title: String(localized: "La memoria del tuo lavoro"),
            text: String(
                localized:
                    "IAGO raccoglie call, email, documenti e note di ogni progetto e li rende interrogabili: chiedi cosa si è deciso, chi deve fare cosa, com'è cambiata una scelta, e torni subito alla fonte."
            )
        ),
        .init(
            symbol: "iago", title: String(localized: "Registra le call"),
            text: String(
                localized:
                    "Clicca l'icona di IAGO nella barra dei menu, in alto a destra (il nostro pappagallo con la memoria di ferro), e scegli Avvia registrazione: la call è registrata e trascritta. Quando inizia una riunione IAGO te lo propone, con il titolo dal calendario."
            )
        ),
        .init(
            symbol: "tray.and.arrow.down", title: String(localized: "Porta dentro tutto il resto"),
            text: String(
                localized:
                    "Email, PDF, documenti, immagini, audio e trascrizioni di Teams: trascinali nella finestra, mandali da qualsiasi app con «Aggiungi a IAGO», o lascia che IAGO li prenda da una cartella."
            )
        ),
        .init(
            symbol: "checkmark.seal", title: String(localized: "Decisioni, attività e momenti"),
            text: String(
                localized:
                    "Segna i momenti importanti mentre parli. Decisioni, attività e tappe restano collegate alla fonte e al minuto, e quando una decisione cambia IAGO tiene la storia di come ci si è arrivati."
            )
        ),
        .init(
            symbol: "text.alignleft", title: String(localized: "Sintesi per ogni tipo di riunione"),
            text: String(
                localized:
                    "Un 1to1, un SAL o un kickoff hanno la sintesi nella loro forma, con il minuto da cui viene ogni punto. Il motore locale propone anche decisioni e attività da confermare."
            )
        ),
        .init(
            symbol: "bubble.left.and.text.bubble.right", title: String(localized: "Chiedi a IAGO"),
            text: String(
                localized:
                    "Cerca per parole o per significato, oppure chiedi (⌘K): IAGO risponde solo con i tuoi contenuti e cita le fonti, su un progetto, un cliente o tutta la memoria."
            )
        ),
        .init(
            symbol: "lock.shield", title: String(localized: "I tuoi dati, le tue scelte"),
            text: String(
                localized:
                    "Niente lascia il tuo Mac se non lo decidi tu: archivio cifrato e motore locale. Se vuoi di più colleghi Claude ai progetti che scegli; per lavorare in gruppo potrai condividere in spazi che controlli tu o la tua azienda, come OneDrive o Google Drive."
            )
        ),
    ]

    var body: some View {
        let current = Self.pages[page]
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(Self.pages.indices, id: \.self) { index in
                    Capsule().fill(index == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: index == page ? 18 : 6, height: 6)
                }
            }
            Group {
                if current.symbol == "iago", let icon = MenuBarIcon.image(.none, accessibility: "IAGO") {
                    Image(nsImage: icon).resizable().renderingMode(.template).scaledToFit().frame(width: 52)
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: current.symbol).font(.system(size: 46)).foregroundStyle(.tint)
                }
            }
            .frame(height: 70)
            Text(current.title).font(.title2.bold())
            Text(current.text).font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 420)
            Spacer(minLength: 0)
            HStack {
                Toggle(String(localized: "Non mostrare più"), isOn: $dontShowAgain).toggleStyle(.checkbox)
                Spacer()
                Button(String(localized: "Apri l'Aiuto")) {
                    onClose(dontShowAgain)
                    openHelp()
                }
                .buttonStyle(.link)
                if page > 0 {
                    Button(String(localized: "Indietro")) { withAnimation { page -= 1 } }
                }
                Button(page == Self.pages.count - 1 ? String(localized: "Inizia") : String(localized: "Avanti")) {
                    if page == Self.pages.count - 1 { onClose(dontShowAgain) } else { withAnimation { page += 1 } }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 580, height: 420)
    }
}
