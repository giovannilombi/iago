import AppKit
import IAGOStore
import SwiftUI

/// The introduction (D3 in `docs/stato.md`): after the first-launch setup and at every launch until «Non mostrare più»
/// or until the first steps are done; always from Aiuto. Each step shows the real app with the guide's screenshots
/// (`Guide/img`, retaken by the demo tour in both languages), and «Prova adesso» takes the user there. «Primi passi»
/// tick themselves from the archive (`Archive.firstSteps`).
struct IntroView: View {
    let model: AppModel
    let onClose: (_ dontShowAgain: Bool) -> Void
    @State private var page = 0
    @State private var tab = 0
    @State private var dontShowAgain = false
    @State private var steps = FirstSteps()

    struct Step {
        let title: String
        let text: String
        /// Screenshots of the guide (`img/<name>.png`), with a tab label when there are several.
        let images: [(label: String, name: String)]
        let actions: [Action]
    }

    enum Action {
        case example, inbox, keyPoints, importer, ask, claude, privacy, guide, lastCall

        var title: String {
            switch self {
            case .example: String(localized: "Apri il progetto di esempio")
            case .inbox: String(localized: "Apri l'Inbox")
            case .keyPoints: String(localized: "Apri Punti chiave")
            case .importer: String(localized: "Apri Importa")
            case .ask: String(localized: "Chiedi a IAGO (⌘K)")
            case .claude: String(localized: "Collega Claude…")
            case .privacy: String(localized: "Apri Impostazioni › Privacy")
            case .guide: String(localized: "Apri la guida")
            case .lastCall: String(localized: "Apri l'ultima call")
            }
        }
    }

    static let pages: [Step] = [
        Step(
            title: String(localized: "La memoria del tuo lavoro"),
            text: String(
                localized:
                    "Call, email, documenti e note di ogni progetto, in un posto e interrogabili. Clienti e progetti a sinistra, quello che è successo al centro, la scheda a destra."
            ),
            images: [("", "finestra")], actions: [.example]),
        Step(
            title: String(localized: "Sempre sulla tua spalla, riunione dopo riunione"),
            text: String(
                localized:
                    "IAGO si accorge quando inizia una riunione su Teams o Zoom, o una del calendario con il link di Meet o Webex, e ti propone di registrarla con il suo titolo. Mentre parli segni i momenti (⌃⌥M) e catturi le slide (⌃⌥S). Dopo lo Stop sistemi progetto, categoria e presenti. Vale anche per una riunione in presenza: avvia la registrazione dall'icona in alto a destra o con ⌃⌥R."
            ),
            images: [
                (String(localized: "Riconosce la riunione"), "proposta"),
                (String(localized: "Dopo lo Stop"), "dopo-stop"),
            ], actions: [.guide]),
        Step(
            title: String(localized: "Porta dentro tutto il resto"),
            text: String(
                localized:
                    "Email, PDF, documenti Word, immagini (il testo viene letto), audio e trascrizioni di Teams. Trascinali nella finestra, mandali da qualsiasi app con «Aggiungi a IAGO», o lascia che IAGO li prenda da una cartella, anche quella dove Outlook salva le email."
            ),
            images: [("", "importa")], actions: [.importer]),
        Step(
            title: String(localized: "Trascrizione, nomi e sintesi"),
            text: String(
                localized:
                    "Dopo lo Stop IAGO trascrive sul Mac e distingue chi parla, anche più persone nella stessa stanza. Dai un nome agli speaker: la sintesi prende la forma della categoria della call (1to1, SAL, kickoff…), con il minuto di ogni punto."
            ),
            images: [("", "sintesi")], actions: [.lastCall]),
        Step(
            title: String(localized: "Ogni progetto, come ti serve"),
            text: String(
                localized:
                    "Il Riepilogo dice a che punto è il progetto. La Timeline mette in fila call, email, decisioni e note. La Kanban sposta il lavoro aperto tra le colonne. Il Grafo mostra chi e cosa è collegato a cosa."
            ),
            images: [
                (String(localized: "Riepilogo"), "riepilogo"), (String(localized: "Timeline"), "finestra"),
                (String(localized: "Kanban"), "kanban"), (String(localized: "Grafo"), "grafo"),
            ], actions: [.example]),
        Step(
            title: String(localized: "L'Inbox: cosa fare adesso"),
            text: String(
                localized:
                    "Il bollino rosso conta ciò che chiede un'azione: in ritardo, oggi, senza responsabile. Il giallo conta le proposte da confermare. Il lavoro aperto di tutti i progetti, in un posto."
            ),
            images: [("", "inbox")], actions: [.inbox]),
        Step(
            title: String(localized: "Decisioni e attività con la loro fonte"),
            text: String(
                localized:
                    "Ogni decisione, attività o rischio ricorda la frase e il minuto da cui viene. Quando una decisione cambia, IAGO tiene la storia di come ci si è arrivati."
            ),
            images: [("", "punti-chiave")], actions: [.keyPoints]),
        Step(
            title: String(localized: "Chiedi a IAGO"),
            text: String(
                localized:
                    "«Cosa abbiamo deciso sul rilascio?» IAGO risponde solo con i tuoi contenuti e cita le fonti. Cerca anche per significato, non solo per parole."
            ),
            images: [("", "chiedi")], actions: [.ask]),
        Step(
            title: String(localized: "Claude, sui progetti che scegli"),
            text: String(
                localized:
                    "Se usi Claude, collegalo a IAGO: abiliti i progetti uno per uno e scegli se Claude può solo leggere o anche scrivere. Claude cerca nella memoria, apre call ed email, segue decisioni e attività, prepara sintesi, proposte e note. Quello che scrive arriva in IAGO da confermare, e il registro accessi dice cosa ha letto."
            ),
            images: [("", "claude")], actions: [.claude]),
        Step(
            title: String(localized: "I tuoi dati, le tue scelte"),
            text: String(
                localized:
                    "Archivio cifrato e motore sul Mac: niente esce se non lo decidi tu. Claude, Condividi e le esportazioni partono solo da una tua scelta."
            ),
            images: [("", "motore")], actions: [.privacy, .guide]),
    ]

    var body: some View {
        let current = Self.pages[page]
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                if page == 0 {
                    HStack(spacing: 12) {
                        Image("Logo").resizable().scaledToFit().frame(width: 40, height: 40)
                        Text(String(localized: "IAGO, sempre sulla tua spalla. Riunione dopo riunione."))
                            .font(.headline)
                    }
                }
                progress
                if current.images.count > 1 {
                    Picker("", selection: $tab) {
                        ForEach(current.images.indices, id: \.self) { index in
                            Text(current.images[index].label).tag(index)
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
                screenshot(current.images[min(tab, current.images.count - 1)].name)
                Text(current.title).font(.title2.bold())
                Text(current.text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ForEach(current.actions.indices, id: \.self) { index in
                        let action = current.actions[index]
                        Button(action.title) { perform(action) }
                            .buttonStyle(.bordered)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Toggle(String(localized: "Non mostrare più"), isOn: $dontShowAgain).toggleStyle(.checkbox)
                    Spacer()
                    if page > 0 {
                        Button(String(localized: "Indietro")) { go(page - 1) }
                    }
                    Button(page == Self.pages.count - 1 ? String(localized: "Inizia") : String(localized: "Avanti")) {
                        if page == Self.pages.count - 1 { onClose(dontShowAgain) } else { go(page + 1) }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            firstStepsList.frame(width: 240)
        }
        .frame(width: 960, height: 700)
        .task(id: model.revision) { steps = (try? model.archive.firstSteps()) ?? FirstSteps() }
    }

    private var progress: some View {
        HStack(spacing: 5) {
            ForEach(Self.pages.indices, id: \.self) { index in
                Capsule().fill(index == page ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == page ? 18 : 6, height: 6)
                    .onTapGesture { go(index) }
            }
            Spacer()
            Text(String(localized: "\(page + 1) di \(Self.pages.count)")).font(.caption).foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func screenshot(_ name: String) -> some View {
        let url = GuideChapter.folder?.appendingPathComponent("img/\(name).png")
        return Group {
            if let url, let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Color.secondary.opacity(0.1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 360)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
    }

    private var firstStepsList: some View {
        let rows: [(Bool, String, String)] = [
            (
                steps.recorded, String(localized: "Registra una call"),
                String(localized: "O lascia che IAGO te la proponga quando inizia")
            ),
            (
                steps.imported, String(localized: "Importa un'email o un documento"),
                String(localized: "Trascinalo nella finestra")
            ),
            (
                steps.namedSpeaker, String(localized: "Dai un nome a uno speaker"),
                String(localized: "Nella trascrizione, poi Invio")
            ),
            (
                steps.filed, String(localized: "Metti un elemento in un progetto"),
                String(localized: "Dalla scheda o dagli Elementi da classificare")
            ),
            (
                steps.confirmedProposal, String(localized: "Conferma una proposta"),
                String(localized: "Nell'Inbox o nella scheda")
            ),
            (steps.asked, String(localized: "Fai una domanda a IAGO"), String(localized: "⌘K da qualsiasi punto")),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Primi passi")).font(.headline)
            Text(String(localized: "\(steps.done) di \(FirstSteps.total) fatti")).font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(steps.done), total: Double(FirstSteps.total)).tint(.green)
            ForEach(rows.indices, id: \.self) { index in
                let (done, title, detail) = rows[index]
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done ? Color.green : Color.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).strikethrough(done).foregroundStyle(done ? .secondary : .primary)
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text(String(localized: "Si spuntano da soli quando li fai davvero. Collegare Claude è facoltativo."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.secondary.opacity(0.06))
    }

    private func go(_ index: Int) {
        withAnimation { page = index }
        tab = 0
    }

    // MARK: Prova adesso

    private func perform(_ action: Action) {
        switch action {
        case .example:
            // The example projects (ADR-0066); without them, the first project.
            let example = ((try? model.archive.exampleMainProjectID()) ?? nil) ?? model.projects.first?.id
            if let example { model.select(.library(.project(example))) }
            // On the «Ogni progetto» step the tab shown is the view that opens.
            if Self.pages[page].images.count == 4 {
                model.viewMode = [.overview, .timeline, .board, .map][min(tab, 3)]
            }
        case .inbox: model.select(.inbox)
        case .keyPoints: model.select(.decisions)
        case .importer: model.select(.importer)
        case .ask: model.showsChat = true
        case .claude:
            model.settingsPane = .claude
            model.openSettings?()
        case .privacy:
            model.settingsPane = .privacy
            model.openSettings?()
        case .guide: model.openHelp?()
        case .lastCall:
            let calls = ((try? model.archive.items()) ?? []).filter { $0.type == .call }
            if let call = calls.max(by: { $0.occurredAt < $1.occurredAt }) { model.openItem?(call.id) }
        }
        NSApp.activate()
    }
}
