import IAGOCapture
import IAGOIntelligence
import IAGOStore
import IAGOTranscription
import ServiceManagement
import SwiftUI

/// Settings (spec 14): general, audio, transcription, categories, privacy, space, about. The logo sits on
/// top of the sidebar; author and license at the bottom (ADR-0034).
struct SettingsView: View {
    let model: AppModel

    enum Pane: String, CaseIterable, Identifiable {
        case general, permissions, audio, transcription, voices, engine, projects, email, categories, claude, obsidian,
            privacy,
            backup,
            space, help, about
        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: String(localized: "Generale")
            case .permissions: String(localized: "Permessi")
            case .audio: String(localized: "Audio")
            case .transcription: String(localized: "Trascrizione")
            case .voices: String(localized: "Voci")
            case .engine: String(localized: "Motore")
            case .projects: String(localized: "Progetti")
            case .email: String(localized: "Email e persone")
            case .categories: String(localized: "Categorie")
            case .claude: String(localized: "Claude")
            case .privacy: String(localized: "Privacy")
            case .backup: String(localized: "Backup e trasferimento")
            case .obsidian: String(localized: "Obsidian")
            case .space: String(localized: "Spazio")
            case .help: String(localized: "Aiuto")
            case .about: String(localized: "Informazioni")
            }
        }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .permissions: "checklist"
            case .audio: "mic"
            case .transcription: "text.bubble"
            case .voices: "person.wave.2"
            case .engine: "cpu"
            case .projects: "folder"
            case .email: "envelope"
            case .categories: "square.grid.2x2"
            case .claude: "sparkle"
            case .privacy: "lock.shield"
            case .backup: "externaldrive.badge.timemachine"
            case .obsidian: "point.3.filled.connected.trianglepath.dotted"
            case .space: "internaldrive"
            case .help: "questionmark.circle"
            case .about: "info.circle"
            }
        }
    }

    @State private var pane: Pane = .general

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Image("Logo").resizable().scaledToFit().frame(width: 56, height: 56)
                    Text("IAGO").font(.headline)
                }
                .padding(.top, 22).padding(.bottom, 14)
                List(Pane.allCases, selection: $pane) { pane in
                    Label(pane.title, systemImage: pane.icon).tag(pane)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                Text("Giovanni Lombi · CC BY-NC-SA 4.0")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.bottom, 10)
            }
            .frame(width: 200)
            .background(.regularMaterial)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(pane.title).font(.title2).bold()
                    switch pane {
                    case .general: GeneralPane(model: model)
                    case .permissions: PermissionsPane(model: model)
                    case .audio: AudioPane(model: model)
                    case .transcription: TranscriptionPane(model: model)
                    case .voices: VoicesPane(model: model)
                    case .engine: EnginePane(model: model)
                    case .projects:
                        ClientsPane(model: model)
                        ProjectsPane(model: model)
                    case .email: EmailPane(model: model)
                    case .categories: CategoriesPane(model: model)
                    case .claude: ClaudePane(model: model)
                    case .privacy: PrivacyPane(model: model)
                    case .backup: BackupPane(model: model)
                    case .obsidian: ObsidianPane(model: model)
                    case .space: SpacePane(model: model)
                    case .help: HelpPane(model: model)
                    case .about: AboutPane()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 760, height: 540)
        .onAppear(perform: showRequestedPane)
        .onChange(of: model.settingsPane) { showRequestedPane() }
    }

    private func showRequestedPane() {
        guard let requested = model.settingsPane else { return }
        pane = requested
        model.settingsPane = nil
    }
}

/// A grouped block of settings with a short explanation.
struct SettingsGroup<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 10) { content }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(IAGOColor.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
            if let footnote { Text(footnote).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

// MARK: - Panes

private struct GeneralPane: View {
    let model: AppModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        LanguageGroup()
        if let updates = model.updates { UpdatesGroup(updates: updates) }
        MyNameGroup(model: model)
        WorkViewsSettings(model: model)
        ItemDetailSettings()
        SettingsGroup(title: String(localized: "Avvio")) {
            Toggle(String(localized: "Apri IAGO all'avvio del Mac"), isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        model.lastError = String(
                            localized: "Impossibile cambiare l'avvio automatico: \(ErrorText.describe(error))")
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        if let shortcuts = model.shortcuts { ShortcutSettings(model: model, shortcuts: shortcuts) }
    }

}

/// «Lingua» (ADR-0077): Italian or English. macOS applies the language at launch, so IAGO restarts; what it writes
/// from then on (summaries, proposals) is in the new language too.
private struct LanguageGroup: View {
    @State private var selection = AppLanguage.current
    @State private var asking = false

    var body: some View {
        SettingsGroup(
            title: String(localized: "Lingua"),
            footnote: String(
                localized:
                    "La lingua dell'app, della guida e di ciò che IAGO scrive per te (sintesi, proposte, risposte). Per cambiarla IAGO si riavvia."
            )
        ) {
            Picker(String(localized: "Lingua"), selection: $selection) {
                ForEach(AppLanguage.allCases) { Text(verbatim: $0.name).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .onChange(of: selection) { _, language in
                guard language != AppLanguage.current else { return }
                language.choose()
                asking = true
            }
        }
        .alert(String(localized: "Riavviare IAGO?"), isPresented: $asking) {
            Button(String(localized: "Riavvia ora")) { AppLanguage.relaunch() }
            Button(String(localized: "Più tardi"), role: .cancel) {}
        } message: {
            Text(String(localized: "La nuova lingua si vede dal prossimo avvio di IAGO."))
        }
    }
}

/// Names, signs and explanations of «Modalità Traccia» and «Modalità Gestisci» (ADR-0074, ADR-0076), chosen per
/// project: in the project's header, on its first-visit sheet and in Impostazioni › Progetti.
enum WorkModeText {
    static func title(_ mode: WorkMode) -> String {
        switch mode {
        case .collect: String(localized: "Raccogli")
        case .track: String(localized: "Traccia")
        case .manage: String(localized: "Gestisci")
        }
    }

    static func fullTitle(_ mode: WorkMode) -> String {
        switch mode {
        case .collect: String(localized: "Modalità Raccogli")
        case .track: String(localized: "Modalità Traccia")
        case .manage: String(localized: "Modalità Gestisci")
        }
    }

    /// From the simplest to the complete one.
    static func level(_ mode: WorkMode) -> String {
        switch mode {
        case .collect: String(localized: "solo i contenuti")
        case .track: String(localized: "semplice e veloce")
        case .manage: String(localized: "completa")
        }
    }

    static func explanation(_ mode: WorkMode) -> String {
        switch mode {
        case .collect:
            String(
                localized:
                    "Un archivio da cercare e interrogare: elementi, trascrizioni, segnalibri e sintesi, senza punti chiave."
            )
        case .track:
            String(localized: "Tieni il filo del progetto: elementi, decisioni e attività da spuntare.")
        case .manage:
            String(
                localized:
                    "Tutti gli strumenti per guidarlo: stati, priorità, scadenze, dipendenze, Kanban e Riepilogo completo."
            )
        }
    }

    /// An archive box for «Raccogli», a notebook for «Traccia», the columns of a kanban for «Gestisci».
    static func icon(_ mode: WorkMode) -> String {
        switch mode {
        case .collect: "archivebox"
        case .track: "book.closed"
        case .manage: "rectangle.split.3x1"
        }
    }

    static func color(_ mode: WorkMode) -> Color {
        switch mode {
        case .collect: .orange
        case .track: .green
        case .manage: .blue
        }
    }
}

private struct AudioPane: View {
    let model: AppModel
    @State private var selection = "auto"
    private let devices = CaptureEngine.availableInputDevices()

    var body: some View {
        SettingsGroup(
            title: String(localized: "Microfono"),
            footnote: String(
                localized:
                    "In automatico IAGO registra il microfono che sta usando l'app della call (Teams, Zoom, Meet…) e lo segue se cambia. Puoi anche sceglierne uno fisso; vale anche dal menu dell'icona."
            )
        ) {
            Picker(String(localized: "Microfono"), selection: $selection) {
                Text(String(localized: "Automatico (segue l'app di call)")).tag("auto")
                ForEach(devices, id: \.uid) { Text($0.name).tag($0.uid) }
            }
            .frame(maxWidth: 420)
            .onChange(of: selection) { _, value in model.setMicOverride?(value == "auto" ? nil : value) }
        }
        .onAppear {
            selection = (try? model.archive.setting(StatusItemController.micKey)) ?? "auto"
        }
        CallSettings(model: model)
    }
}

private struct TranscriptionPane: View {
    let model: AppModel
    @State private var engine = ModelSpec.Engine.whisper
    @State private var glossary = ""
    @State private var language = "it"
    @State private var action = "ask"
    @State private var onlyOnPower = false

    private func saveGlossary() {
        let value = glossary.trimmingCharacters(in: .whitespacesAndNewlines)
        model.perform { try model.archive.setSetting(TranscriptionService.glossaryKey, value.isEmpty ? nil : value) }
    }

    var body: some View {
        SettingsGroup(
            title: String(localized: "Motore"),
            footnote: String(
                localized:
                    "Whisper è più preciso sull'italiano; Parakeet è circa 4 volte più veloce. Entrambi lavorano solo su questo Mac."
            )
        ) {
            Picker("", selection: $engine) {
                Text(String(localized: "Whisper (consigliato)")).tag(ModelSpec.Engine.whisper)
                Text(String(localized: "Parakeet (veloce)")).tag(ModelSpec.Engine.parakeet)
            }
            .pickerStyle(.radioGroup).labelsHidden()
            .onChange(of: engine) { _, value in
                model.perform { try model.archive.setSetting(TranscriptionService.engineKey, value.rawValue) }
            }
            let missing = model.transcription.models.missing(ModelSpec.required(for: engine))
            if !missing.isEmpty {
                Label(
                    String(localized: "Da scaricare: \(missing.map(\.displayName).joined(separator: ", "))"),
                    systemImage: "arrow.down.circle"
                )
                .foregroundStyle(.orange)
                Text(String(localized: "Puoi scaricarli da Spazio.")).font(.caption).foregroundStyle(.secondary)
            }
        }
        SettingsGroup(title: String(localized: "Lingua")) {
            Picker("", selection: $language) {
                Text(String(localized: "Italiano")).tag("it")
                Text(String(localized: "Riconoscimento automatico")).tag("auto")
            }
            .labelsHidden().frame(maxWidth: 260)
            .onChange(of: language) { _, value in
                model.perform { try model.archive.setSetting(TranscriptionService.languageKey, value) }
            }
        }
        SettingsGroup(
            title: String(localized: "Glossario"),
            footnote: String(
                localized:
                    "Nomi e termini che la trascrizione deve scrivere giusti (aziende, prodotti, sigle), separati da virgole. Per ogni call IAGO aggiunge da solo progetto, cliente, stream e contatti del progetto. Vale per Whisper."
            )
        ) {
            TextField(String(localized: "Es. Acme, SAP, Rossi Srl"), text: $glossary, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...4).frame(maxWidth: 460)
                .onSubmit(saveGlossary)
            Button(String(localized: "Salva"), action: saveGlossary).controlSize(.small)
        }
        SettingsGroup(
            title: String(localized: "Dopo lo Stop"),
            footnote: String(
                localized:
                    "Con \"Chiedi ogni volta\" compare il pannello per classificare la registrazione e scegliere cosa fare."
            )
        ) {
            Picker("", selection: $action) {
                Text(String(localized: "Chiedi ogni volta")).tag("ask")
                Text(String(localized: "Conserva solo l'audio")).tag("audio")
                Text(String(localized: "Trascrivi e conserva l'audio")).tag("transcribe")
                Text(String(localized: "Trascrivi ed elimina l'audio")).tag("transcribe_delete")
            }
            .labelsHidden().frame(maxWidth: 300)
            .onChange(of: action) { _, value in
                model.perform {
                    try model.archive.setSetting(TranscriptionService.defaultActionKey, value == "ask" ? nil : value)
                }
            }
            Toggle(String(localized: "Trascrivi solo quando il Mac è collegato all'alimentazione"), isOn: $onlyOnPower)
                .onChange(of: onlyOnPower) { _, value in
                    model.perform {
                        try model.archive.setSetting(TranscriptionService.onlyOnPowerKey, value ? "1" : nil)
                    }
                }
        }
        .onAppear {
            glossary = ((try? model.archive.setting(TranscriptionService.glossaryKey)) ?? nil) ?? ""
            engine = model.transcription.engine
            language = (try? model.archive.setting(TranscriptionService.languageKey)) ?? "it"
            action = (try? model.archive.setting(TranscriptionService.defaultActionKey)) ?? "ask"
            onlyOnPower = (try? model.archive.setting(TranscriptionService.onlyOnPowerKey)) == "1"
        }
    }
}

/// Projects (rename, archive, delete). Deleting asks three times: warning with what is lost, typing
/// DELETE, final warning.
private struct ProjectsPane: View {
    let model: AppModel
    @State private var hasExample = false
    @State private var removingExample = false
    @State private var projects: [Project] = []
    @State private var names: [String: String] = [:]
    @State private var deleting: Project?
    @State private var stats: Archive.ProjectStats?
    @State private var step = 0
    @State private var typed = ""

    var body: some View {
        if hasExample {
            SettingsGroup(
                title: String(localized: "Progetti di esempio"),
                footnote: String(
                    localized:
                        "Poldo S.p.A., Sanna TheBest s.r.l. e Atoms sono clienti inventati, con call, email, documenti e punti chiave di prova. Rimuovendoli se ne vanno con tutto il loro contenuto; quello che hai spostato in altri progetti resta."
                )
            ) {
                Button(String(localized: "Rimuovi l'esempio…"), role: .destructive) { removingExample = true }
            }
            .confirmationDialog(
                String(localized: "Rimuovere i progetti di esempio?"), isPresented: $removingExample,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Rimuovi l'esempio"), role: .destructive) {
                    model.perform { try model.archive.removeExample() }
                    model.reload()
                    reload()
                }
            } message: {
                Text(
                    String(
                        localized: "Clienti, progetti e contenuti di esempio vengono eliminati. Non si può annullare."))
            }
        }
        SettingsGroup(
            title: String(localized: "Progetti"),
            footnote: String(
                localized:
                    "Rinominare non sposta né perde nulla. Un progetto archiviato sparisce dalla barra laterale ma resta qui, con tutto il suo contenuto. \"Non definito\" raccoglie gli elementi classificati senza progetto e non si può modificare."
            )
        ) {
            HStack {
                Image(systemName: "questionmark.folder").foregroundStyle(.secondary)
                Text(String(localized: "Non definito")).foregroundStyle(.secondary)
                Spacer()
                Text(String(localized: "sempre presente")).font(.caption).foregroundStyle(.tertiary)
            }
            ForEach(projects) { project in
                HStack(spacing: 8) {
                    Image(systemName: project.archived ? "archivebox" : "folder").foregroundStyle(.secondary)
                    TextField("", text: nameBinding(project)).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                        .onSubmit { rename(project) }
                    Picker("", selection: clientBinding(project)) {
                        Text(String(localized: "Nessun cliente")).tag(String?.none)
                        ForEach(model.clients) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .labelsHidden().frame(width: 150)
                    .help(String(localized: "Cliente del progetto"))
                    Spacer()
                    Button(project.archived ? String(localized: "Ripristina") : String(localized: "Archivia")) {
                        model.perform { try model.archive.setProjectArchived(project.id, !project.archived) }
                        reload()
                    }
                    .buttonStyle(.link)
                    Button(String(localized: "Elimina…"), role: .destructive) { startDelete(project) }.buttonStyle(
                        .link)
                }
                // ADR-0074, ADR-0076: each project in «Gestisci» (the default) or kept simple in «Traccia».
                Picker(
                    String(localized: "Modalità"),
                    selection: Binding(
                        get: { project.workMode ?? .manage },
                        set: { mode in
                            model.chooseProjectWorkMode(project.id, mode)
                            reload()
                        })
                ) {
                    ForEach(WorkMode.allCases, id: \.self) {
                        Label(WorkModeText.fullTitle($0), systemImage: WorkModeText.icon($0)).tag($0)
                    }
                }
                .pickerStyle(.segmented).fixedSize().controlSize(.small).padding(.leading, 26)
                .help(WorkModeText.explanation(project.workMode ?? .manage))
                ProjectStreamsEditor(model: model, project: project).padding(.leading, 26)
            }
            if projects.isEmpty { Text(String(localized: "Nessun progetto creato.")).foregroundStyle(.secondary) }
        }
        .onAppear(perform: reload)
        // Step 1: what is lost.
        .alert(
            String(localized: "Eliminare il progetto \"\(deleting?.name ?? "")\"?"),
            isPresented: Binding(get: { step == 1 }, set: { if !$0 && step == 1 { cancel() } })
        ) {
            Button(String(localized: "Continua"), role: .destructive) { step = 2 }
            Button(String(localized: "Annulla"), role: .cancel) { cancel() }
        } message: {
            Text(
                String(
                    localized:
                        "Perderai tutto il materiale del progetto: \(stats?.items ?? 0) elementi con audio e documenti, \(stats?.transcripts ?? 0) trascrizioni e \(stats?.notes ?? 0) note. Non si potrà recuperare, nemmeno dal cestino."
                ))
        }
        // Step 2: type DELETE.
        .sheet(isPresented: Binding(get: { step == 2 }, set: { if !$0 && step == 2 { cancel() } })) {
            VStack(alignment: .leading, spacing: 12) {
                Label(String(localized: "Conferma l'eliminazione"), systemImage: "exclamationmark.triangle.fill")
                    .font(.title3).bold().foregroundStyle(.red)
                Text(
                    String(
                        localized:
                            "Per eliminare \"\(deleting?.name ?? "")\" e tutto il suo contenuto scrivi DELETE qui sotto."
                    ))
                TextField("DELETE", text: $typed).textFieldStyle(.roundedBorder).font(.title2.monospaced()).frame(
                    width: 220)
                HStack {
                    Spacer()
                    Button(String(localized: "Annulla"), role: .cancel) { cancel() }.keyboardShortcut(.cancelAction)
                    Button(String(localized: "OK")) { step = 3 }.disabled(typed != "DELETE")
                }
            }
            .padding(20).frame(width: 420)
        }
        // Step 3: final warning.
        .alert(
            String(localized: "Ultima conferma"),
            isPresented: Binding(get: { step == 3 }, set: { if !$0 && step == 3 { cancel() } })
        ) {
            Button(String(localized: "Elimina definitivamente"), role: .destructive) { delete() }
            Button(String(localized: "Annulla"), role: .cancel) { cancel() }
        } message: {
            Text(
                String(
                    localized:
                        "Il progetto \"\(deleting?.name ?? "")\" e tutto il suo contenuto verranno distrutti. L'operazione non si può annullare."
                ))
        }
    }

    private func reload() {
        projects = (try? model.archive.projects(includeArchived: true)) ?? []
        hasExample = (try? model.archive.hasExample()) ?? false
        names = [:]
        model.reload()
    }

    private func clientBinding(_ project: Project) -> Binding<String?> {
        Binding(
            get: { project.clientId },
            set: { id in
                model.setProjectClient(project.id, id)
                reload()
            })
    }

    private func nameBinding(_ project: Project) -> Binding<String> {
        Binding(get: { names[project.id] ?? project.name }, set: { names[project.id] = $0 })
    }

    private func rename(_ project: Project) {
        guard let name = names[project.id], name != project.name else { return }
        model.perform { try model.archive.renameProject(project.id, to: name) }
        reload()
    }

    private func startDelete(_ project: Project) {
        deleting = project
        stats = try? model.archive.projectStats(project.id)
        typed = ""
        step = 1
    }

    private func cancel() {
        step = 0
        deleting = nil
        typed = ""
    }

    private func delete() {
        guard let project = deleting else { return }
        model.perform { try model.archive.deleteProject(project.id) }
        if case .library(.project(project.id)) = model.sidebar { model.select(.library(.recent)) }
        cancel()
        reload()
    }
}

/// Settings › Generale › Aggiornamenti (ADR-0056).
private struct UpdatesGroup: View {
    @Bindable var updates: UpdateService
    @State private var automatic = true

    var body: some View {
        SettingsGroup(
            title: String(localized: "Aggiornamenti"),
            footnote: String(
                localized:
                    "IAGO controlla una volta al giorno le versioni pubblicate su GitHub. Le versioni minori sono proposte; una nuova versione maggiore è obbligatoria prima di registrare di nuovo. Gli aggiornamenti sono firmati e il controllo compare nel registro accessi."
            )
        ) {
            Text(String(localized: "Versione installata: \(UpdateService.currentVersion)")).font(.callout)
            if !UpdateService.isDistributed {
                Label(
                    String(
                        localized:
                            "Questa copia è compilata dal codice sorgente: si aggiorna con git e una nuova build, non da qui. Gli aggiornamenti automatici sono per chi installa IAGO dal DMG."
                    ), systemImage: "hammer"
                )
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if let mandatory = updates.mandatoryVersion {
                Label(
                    String(localized: "Aggiornamento obbligatorio disponibile: \(mandatory)"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            } else if let available = updates.availableVersion {
                Label(String(localized: "Disponibile la versione \(available)"), systemImage: "arrow.down.circle")
            }
            if UpdateService.isDistributed { automaticControls }
        }
        .onAppear { automatic = updates.automaticChecks }
    }

    @ViewBuilder
    private var automaticControls: some View {
        Toggle(
            String(localized: "Controlla automaticamente"),
            isOn: Binding(
                get: { automatic },
                set: { value in
                    automatic = value
                    updates.automaticChecks = value
                }))
        HStack {
            Button(String(localized: "Controlla ora")) { updates.checkNow() }
            if let last = updates.lastCheck {
                Text(String(localized: "Ultimo controllo: \(last.formatted(date: .abbreviated, time: .shortened))"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// "Aiuto": the guide, the welcome tour, how to install IAGO on another Mac.
private struct HelpPane: View {
    let model: AppModel
    @State private var tourAtLaunch = true

    var body: some View {
        SettingsGroup(
            title: String(localized: "Guida"),
            footnote: String(
                localized:
                    "Tutto su come si usa IAGO, capitolo per capitolo, con le immagini. Si apre a tutta pagina; la trovi anche con il pulsante «Guida» in alto a sinistra nella finestra e nel menu dell'icona di IAGO."
            )
        ) {
            Button(String(localized: "Apri la guida")) { model.openHelp?() }.buttonStyle(.borderedProminent)
        }
        SettingsGroup(
            title: String(localized: "Introduzione"),
            footnote: String(localized: "Dieci passi con le schermate dell'app, e i primi passi da fare.")
        ) {
            Button(String(localized: "Rivedi l'introduzione")) { model.openTour?() }
            Toggle(
                String(localized: "Mostra l'introduzione all'avvio"),
                isOn: Binding(
                    get: { tourAtLaunch },
                    set: { value in
                        tourAtLaunch = value
                        model.perform { try model.archive.setSetting(WindowManager.tourHiddenKey, value ? nil : "1") }
                    }))
        }
        .onAppear { tourAtLaunch = (try? model.archive.setting(WindowManager.tourHiddenKey)) != "1" }
    }
}

private struct CategoriesPane: View {
    let model: AppModel
    @State private var categories: [IAGOStore.Category] = []
    @State private var newName = ""
    @State private var editingTemplate: IAGOStore.Category?

    private var main: [IAGOStore.Category] { categories.filter { $0.family == nil } }

    var body: some View {
        SettingsGroup(
            title: String(localized: "Categorie principali"),
            footnote: String(
                localized:
                    "Ogni elemento ha al più una categoria, che decide anche la forma della sintesi. Le categorie archiviate non compaiono più nelle scelte. I modelli di sintesi sono adattati da Meetily e Hyprnote (licenza MIT)."
            )
        ) {
            ForEach(Array(main.enumerated()), id: \.element.id) { index, category in
                HStack(spacing: 8) {
                    ColorPicker("", selection: colorBinding(category), supportsOpacity: false).labelsHidden().frame(
                        width: 30)
                    TextField("", text: nameBinding(category)).textFieldStyle(.roundedBorder).frame(maxWidth: 180)
                    Button {
                        move(category, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless).disabled(index == 0)
                    Button {
                        move(category, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless).disabled(index == main.count - 1)
                    templateMenu(category)
                    levelMenu(category)
                    Toggle(String(localized: "Archiviata"), isOn: archivedBinding(category)).toggleStyle(.checkbox)
                }
            }
            HStack {
                TextField(String(localized: "Nuova categoria"), text: $newName).textFieldStyle(.roundedBorder).frame(
                    maxWidth: 220
                )
                .onSubmit(add)
                Button(String(localized: "Aggiungi"), action: add).disabled(
                    newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: load)
        .sheet(item: $editingTemplate) { category in
            TemplateEditor(model: model, category: category) { load() }
        }
        SettingsGroup(
            title: String(localized: "Altre categorie, per famiglia"),
            footnote: String(
                localized:
                    "Restano spente finché non ti servono. Accese, compaiono nella scelta della categoria come sottomenu della loro famiglia."
            )
        ) {
            ForEach(families, id: \.self) { family in
                let members = categories.filter { $0.family == family }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(CategoryFamilyName.display(family)).font(.headline)
                        Spacer()
                        Button(
                            members.allSatisfy(\.archived)
                                ? String(localized: "Attiva tutte") : String(localized: "Spegni tutte")
                        ) {
                            let on = members.allSatisfy(\.archived)
                            for member in members {
                                model.perform { try model.archive.setCategoryActive(member.id, on) }
                            }
                            load()
                        }
                        .buttonStyle(.link)
                    }
                    ForEach(members) { category in
                        HStack(spacing: 8) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { !category.archived },
                                    set: { value in
                                        model.perform { try model.archive.setCategoryActive(category.id, value) }
                                        load()
                                    })
                            )
                            .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                            TextField("", text: nameBinding(category)).textFieldStyle(.roundedBorder).frame(
                                maxWidth: 180)
                            templateMenu(category)
                            levelMenu(category)
                        }
                        .opacity(category.archived ? 0.6 : 1)
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }

    private var families: [String] {
        let present = Set(categories.compactMap(\.family))
        return IAGOStore.Category.families.filter(present.contains)
            + present.subtracting(IAGOStore.Category.families).sorted()
    }

    /// The summary template: one of the library, the user's version, or none.
    private func templateMenu(_ category: IAGOStore.Category) -> some View {
        let current = IntelligenceService.template(for: category)
        return Menu {
            Button(String(localized: "Nessuna sintesi")) { setTemplate(category, nil) }
            Divider()
            ForEach(SummaryLibrary.all) { template in
                Button {
                    setTemplate(category, template.id)
                } label: {
                    if template.id == category.templateId, category.templateJson == nil {
                        Label(template.name, systemImage: "checkmark")
                    } else {
                        Text(template.name)
                    }
                }
            }
            Divider()
            Button(String(localized: "Modifica il modello…")) { editingTemplate = category }
                .disabled(current == nil)
        } label: {
            Label(
                current.map { $0.name + (category.templateJson != nil ? String(localized: " (modificato)") : "") }
                    ?? String(localized: "Nessuna sintesi"), systemImage: "text.alignleft")
        }
        .menuStyle(.borderlessButton).fixedSize()
        .help(String(localized: "Il modello di sintesi di questa categoria"))
    }

    /// Main category or member of a family.
    private func levelMenu(_ category: IAGOStore.Category) -> some View {
        Menu {
            Button(String(localized: "Principale")) { update(category) { $0.family = nil } }
                .disabled(category.family == nil)
            Divider()
            ForEach(IAGOStore.Category.families, id: \.self) { family in
                Button(CategoryFamilyName.display(family)) { update(category) { $0.family = family } }.disabled(
                    category.family == family)
            }
        } label: {
            Image(systemName: "square.stack.3d.up")
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help(String(localized: "Principale o in una famiglia"))
    }

    private func setTemplate(_ category: IAGOStore.Category, _ templateID: String?) {
        model.perform { try model.archive.setCategoryTemplate(category.id, templateID: templateID, customJSON: nil) }
        load()
    }

    private func load() { categories = (try? model.archive.categories(includeArchived: true)) ?? [] }

    private func update(
        _ category: IAGOStore.Category, _ change: @escaping @Sendable (inout IAGOStore.Category) -> Void
    ) {
        model.perform { try model.archive.updateCategory(category.id, change) }
        load()
    }

    private func nameBinding(_ category: IAGOStore.Category) -> Binding<String> {
        Binding(
            get: { categories.first { $0.id == category.id }?.name ?? "" },
            set: { value in
                guard !value.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                update(category) { $0.name = value }
            })
    }

    private func archivedBinding(_ category: IAGOStore.Category) -> Binding<Bool> {
        Binding(get: { category.archived }, set: { value in update(category) { $0.archived = value } })
    }

    private func colorBinding(_ category: IAGOStore.Category) -> Binding<Color> {
        Binding(
            get: { category.color.flatMap(Color.init(hex:)) ?? .accentColor },
            set: { color in
                let hex = color.hexString
                update(category) { $0.color = hex }
            })
    }

    private func move(_ category: IAGOStore.Category, by offset: Int) {
        var order = categories
        let mainOrder = main
        guard let position = mainOrder.firstIndex(of: category), mainOrder.indices.contains(position + offset),
            let from = order.firstIndex(of: category), let to = order.firstIndex(of: mainOrder[position + offset])
        else { return }
        order.swapAt(from, to)
        for (position, category) in order.enumerated() where category.sortOrder != position {
            model.perform { try model.archive.updateCategory(category.id) { $0.sortOrder = position } }
        }
        load()
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        model.perform {
            let category = try model.archive.createCategory(name: name)
            // A template from the name when one fits ("Retro" → Retrospective), otherwise the standard one.
            let guess = SummaryLibrary.all.first {
                $0.name.localizedCaseInsensitiveContains(name) || name.localizedCaseInsensitiveContains($0.name)
            }
            try model.archive.setCategoryTemplate(category.id, templateID: guess?.id ?? "standard", customJSON: nil)
        }
        newName = ""
        load()
    }
}

private struct PrivacyPane: View {
    let model: AppModel
    @State private var includeInBackup = false
    @State private var entries: [AuditEntry] = []

    var body: some View {
        SettingsGroup(title: String(localized: "I tuoi dati restano tuoi")) {
            PrivacySummary()
            Divider()
            HStack(spacing: 4) {
                Text(String(localized: "Vuoi verificarlo da solo? Usa"))
                Link("LuLu", destination: URL(string: "https://objective-see.org/products/lulu.html")!)
                Text(String(localized: "(gratuito): ti avvisa a ogni connessione di qualsiasi app."))
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        SettingsGroup(
            title: String(localized: "Time Machine"),
            footnote: String(
                localized:
                    "Di default IAGO è escluso dai backup: l'archivio contiene i testi delle trascrizioni. I file nel backup restano cifrati, ma il database con i testi no."
            )
        ) {
            Toggle(String(localized: "Includi IAGO nei backup di Time Machine"), isOn: $includeInBackup)
                .onChange(of: includeInBackup) { _, value in
                    model.perform {
                        try model.archive.setSetting(ArchiveService.backupIncludedKey, value ? "1" : nil)
                        try Archive.setExcludedFromBackup(model.archiveService.paths.root, excluded: !value)
                    }
                }
        }
        SettingsGroup(
            title: String(localized: "Registro accessi"),
            footnote: String(
                localized:
                    "Ogni volta che IAGO usa la rete (solo per scaricare i modelli, su tua richiesta) o Claude legge l'archivio, lo trovi qui."
            )
        ) {
            if entries.isEmpty {
                Text(String(localized: "Nessun accesso alla rete finora.")).foregroundStyle(.secondary)
            }
            ForEach(entries, id: \.id) { entry in
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.at.formatted(date: .abbreviated, time: .shortened)).font(.caption).monospacedDigit()
                        .frame(width: 130, alignment: .leading)
                    Text(entry.detail ?? entry.action).font(.caption).textSelection(.enabled)
                }
            }
        }
        .onAppear {
            includeInBackup = (try? model.archive.setting(ArchiveService.backupIncludedKey)) == "1"
            entries = (try? model.archive.auditEntries(limit: 50)) ?? []
        }
    }
}

private struct SpacePane: View {
    let model: AppModel
    @State private var archiveSize: Int64 = 0
    @State private var downloading: String?
    @State private var progress = 0.0
    @State private var refresh = 0

    var body: some View {
        SettingsGroup(title: String(localized: "Archivio")) {
            HStack {
                Text(String(localized: "Registrazioni, trascrizioni e documenti (cifrati)"))
                Spacer()
                Text(Format.bytes(archiveSize)).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        SettingsGroup(title: String(localized: "Motore locale")) {
            HStack {
                Text(String(localized: "Modelli del motore (Impostazioni › Motore)"))
                Spacer()
                Text(Format.bytes(model.engine.totalDiskSize)).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        SettingsGroup(
            title: String(localized: "Modelli"),
            footnote: String(
                localized:
                    "I modelli si scaricano una volta sola da indirizzi fissi e vengono verificati con un'impronta SHA-256. Poi la trascrizione funziona anche senza rete."
            )
        ) {
            ForEach(ModelSpec.all) { spec in
                let present = model.transcription.models.isPresent(spec)
                HStack {
                    Image(systemName: present ? "checkmark.circle.fill" : "circle").foregroundStyle(
                        present ? .green : .secondary)
                    Text(spec.displayName)
                    Spacer()
                    if downloading == spec.id {
                        ProgressView(value: progress).frame(width: 120)
                    } else if present {
                        Text(Format.bytes(model.transcription.models.diskSize(spec))).foregroundStyle(.secondary)
                            .monospacedDigit()
                        Button(String(localized: "Elimina"), role: .destructive) {
                            model.perform { try model.transcription.models.delete(spec) }
                            refresh += 1
                        }
                        .buttonStyle(.link)
                    } else {
                        Text(Format.bytes(spec.approximateBytes)).foregroundStyle(.secondary).monospacedDigit()
                        Button(String(localized: "Scarica")) { download(spec) }.disabled(downloading != nil)
                    }
                }
            }
            .id(refresh)
        }
        .task {
            let root = model.archiveService.paths.root
            archiveSize = await Task.detached {
                ModelManager.diskSize(root.appendingPathComponent("Items"))
                    + ModelManager.diskSize(root.appendingPathComponent("iago.sqlite"))
            }.value
        }
    }

    private func download(_ spec: ModelSpec) {
        downloading = spec.id
        progress = 0
        let work = model.activity.begin(.modelDownload, spec.id)
        Task {
            do {
                try await model.transcription.downloadModels([spec]) { value in
                    Task { @MainActor in
                        progress = value
                        model.activity.update(work, fraction: value)
                    }
                }
                model.activity.end(work)
            } catch {
                model.activity.end(work, failure: ErrorText.describe(error))
                model.lastError = String(localized: "Download non riuscito: \(ErrorText.describe(error))")
            }
            downloading = nil
            refresh += 1
        }
    }
}

/// The "privacy first" promise, used in Settings and in the onboarding.
struct PrivacySummary: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PrivacyLine(
                icon: "lock.fill",
                text: String(
                    localized:
                        "Tutto ciò che IAGO salva sul Mac è cifrato: ogni elemento ha una sua chiave, custodita nel Portachiavi."
                ))
            PrivacyLine(
                icon: "cpu",
                text: String(
                    localized:
                        "Trascrizione e lettura dei documenti avvengono su questo Mac, con modelli locali. Nessun servizio cloud."
                ))
            PrivacyLine(
                icon: "wifi.slash",
                text: String(
                    localized:
                        "Niente lascia il tuo Mac se non lo decidi tu: niente telemetria, niente statistiche. Puoi collegare Claude ai progetti che scegli e, per lavorare in gruppo, condividere in spazi che controlli tu o la tua azienda."
                ))
            PrivacyLine(
                icon: "trash",
                text: String(
                    localized:
                        "Quando elimini definitivamente un elemento la sua chiave viene distrutta: anche eventuali copie diventano illeggibili."
                ))
        }
    }
}

private struct PrivacyLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 18)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AboutPane: View {
    var body: some View {
        HStack(spacing: 16) {
            Image("Logo").resizable().scaledToFit().frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text("IAGO").font(.title).bold()
                Text(
                    String(
                        localized:
                            "Versione \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"
                    )
                )
                .foregroundStyle(.secondary)
                Text(
                    String(
                        localized:
                            "Registra le call su due tracce, le trascrive e organizza per progetto call, note e documenti. Tutto in locale."
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        SettingsGroup(title: String(localized: "Privacy prima di tutto")) { PrivacySummary() }
        SettingsGroup(title: String(localized: "Licenze")) {
            Text("© 2026 Giovanni Lombi · Creative Commons BY-NC-SA 4.0").bold()
            Text(
                String(
                    localized:
                        "Uso non commerciale, citando l'autore; le versioni modificate vanno condivise con la stessa licenza."
                )
            )
            .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text(
                "GRDB.swift (MIT) · whisper.cpp (MIT) · FluidAudio (Apache-2.0) · Whisper large-v3-turbo (MIT) · Parakeet TDT v3 (CC-BY-4.0) · Silero VAD (MIT) · pyannote community-1"
            )
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

extension Color {
    init?(hex: String) {
        var value: UInt64 = 0
        guard hex.hasPrefix("#"), hex.count == 7, Scanner(string: String(hex.dropFirst())).scanHexInt64(&value) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

    var hexString: String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return String(
            format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255),
            Int(color.blueComponent * 255))
    }
}

/// Clients (ADR-0038): rename, archive, delete. Deleting a client never deletes its projects.
private struct ClientsPane: View {
    let model: AppModel
    @State private var clients: [Client] = []
    @State private var names: [String: String] = [:]
    @State private var deleting: Client?
    @State private var creating = false

    var body: some View {
        SettingsGroup(
            title: String(localized: "Clienti"),
            footnote: String(
                localized:
                    "Un cliente raggruppa più progetti. Eliminare un cliente non elimina i suoi progetti: restano senza cliente."
            )
        ) {
            ForEach(clients) { client in
                HStack(spacing: 8) {
                    if client.archived {
                        Image(systemName: "archivebox").foregroundStyle(.secondary)
                    } else {
                        ClientMark(color: client.color)
                    }
                    TextField(
                        "", text: Binding(get: { names[client.id] ?? client.name }, set: { names[client.id] = $0 })
                    )
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                    .onSubmit {
                        guard let name = names[client.id], !name.trimmingCharacters(in: .whitespaces).isEmpty
                        else { return }
                        model.perform { try model.archive.updateClient(client.id) { $0.name = name } }
                        reload()
                    }
                    Text(String(localized: "\(model.projects.filter { $0.clientId == client.id }.count) progetti"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(client.archived ? String(localized: "Ripristina") : String(localized: "Archivia")) {
                        model.perform { try model.archive.updateClient(client.id) { $0.archived.toggle() } }
                        reload()
                    }
                    .buttonStyle(.link)
                    Button(String(localized: "Elimina…"), role: .destructive) { deleting = client }.buttonStyle(.link)
                }
            }
            if clients.isEmpty { Text(String(localized: "Nessun cliente creato.")).foregroundStyle(.secondary) }
            Button(String(localized: "+ Nuovo cliente")) { creating = true }.buttonStyle(.link)
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $creating) { NewClientSheet(model: model) { _ in reload() } }
        .confirmationDialog(
            String(localized: "Eliminare il cliente «\(deleting?.name ?? "")»?"),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Elimina cliente"), role: .destructive) {
                if let id = deleting?.id { model.perform { try model.archive.deleteClient(id) } }
                deleting = nil
                reload()
            }
        } message: {
            Text(String(localized: "I suoi progetti restano, senza cliente."))
        }
    }

    private func reload() {
        clients = (try? model.archive.clients(includeArchived: true)) ?? []
        names = [:]
        model.reload()
    }
}

/// Streams of one project in Settings: rename on return, archive, delete, add.
private struct ProjectStreamsEditor: View {
    let model: AppModel
    let project: Project
    @State private var creating = false
    @State private var names: [String: String] = [:]
    @State private var deleting: ProjectStream?

    var body: some View {
        let streams = (try? model.archive.streams(projectID: project.id, includeArchived: true)) ?? []
        FlowLayout(spacing: 6) {
            Text(String(localized: "Stream:")).font(.caption).foregroundStyle(.secondary)
            ForEach(streams) { stream in
                HStack(spacing: 4) {
                    Circle().fill(Color.iago(stream.color)).frame(width: 7, height: 7)
                    TextField(
                        "", text: Binding(get: { names[stream.id] ?? stream.name }, set: { names[stream.id] = $0 })
                    )
                    .textFieldStyle(.plain).font(.caption).frame(width: 90)
                    .onSubmit {
                        guard let name = names[stream.id], !name.trimmingCharacters(in: .whitespaces).isEmpty
                        else { return }
                        model.perform { try model.archive.updateStream(stream.id) { $0.name = name } }
                        model.reload()
                    }
                    Button {
                        deleting = stream
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help(String(localized: "Elimina stream"))
                }
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(Color.iago(stream.color).opacity(0.15)))
            }
            Button(String(localized: "+ Stream")) { creating = true }.buttonStyle(.link).font(.caption)
        }
        .sheet(isPresented: $creating) { NewStreamSheet(model: model, project: project) { _ in model.reload() } }
        .confirmationDialog(
            String(localized: "Eliminare lo stream «\(deleting?.name ?? "")»?"),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Elimina stream"), role: .destructive) {
                if let id = deleting?.id { model.perform { try model.archive.deleteStream(id) } }
                deleting = nil
                model.reload()
            }
        } message: {
            Text(String(localized: "Elementi e decisioni restano nel progetto: perdono solo l'etichetta dello stream."))
        }
    }
}

/// The user's own addresses (FR-182: outgoing emails) and colleagues (ADR-0040).
private struct EmailPane: View {
    let model: AppModel
    @State private var addresses: [String] = []
    @State private var people = false

    var body: some View {
        SettingsGroup(
            title: String(localized: "I tuoi indirizzi email"),
            footnote: String(
                localized:
                    "Le email inviate da questi indirizzi risultano \"inviate\", le altre \"ricevute\". Si può sempre cambiare sulla singola email."
            )
        ) {
            TokenField(
                values: Binding(
                    get: { addresses },
                    set: { values in
                        addresses = values
                        model.perform { try model.archive.setUserEmailAddresses(values) }
                    }), placeholder: String(localized: "nome@azienda.it"), prefix: "", suggestions: [])
        }
        WatchedFoldersSettings(model: model)
        SettingsGroup(
            title: String(localized: "Domini noti"),
            footnote: String(
                localized:
                    "Tutti gli indirizzi di un dominio (e dei suoi sottodomini) hanno quel ruolo, in ogni progetto. Una persona aggiunta per nome vale più del dominio. Un dominio di un cliente fa proporre i suoi progetti."
            )
        ) {
            DomainRulesEditor(model: model, clientID: nil)
        }
        SettingsGroup(
            title: String(localized: "Persone"),
            footnote: String(
                localized:
                    "Colleghi interni qui; clienti e fornitori si aggiungono sul cliente o sul progetto (tasto destro nella barra laterale → Persone…). IAGO li riconosce nelle email e propone il progetto."
            )
        ) {
            Button(String(localized: "Colleghi interni…")) { people = true }
        }
        .onAppear { addresses = (try? model.archive.userEmailAddresses()) ?? [] }
        .sheet(isPresented: $people) {
            PeopleSheet(
                model: model, title: String(localized: "Colleghi interni"), clientID: nil, projectID: nil)
        }
    }
}

/// Obsidian mirror (FR-122): a vault folder and the projects to write there, in clear text.
private struct ObsidianPane: View {
    let model: AppModel
    @State private var vault: URL?
    @State private var projects: Set<String> = []
    @State private var confirmingFirst: String?

    var body: some View {
        SettingsGroup(
            title: String(localized: "Cartella del vault"),
            footnote: String(
                localized:
                    "IAGO scrive nella sottocartella IAGO del vault un file per ogni elemento, nota di progetto e decisione dei progetti scelti, con i collegamenti a progetti, clienti e persone. Solo da IAGO verso Obsidian: le altre note del vault non vengono mai toccate."
            )
        ) {
            HStack {
                Text(vault?.path ?? String(localized: "Nessuna cartella scelta")).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button(String(localized: "Scegli…")) { chooseVault() }
                if vault != nil {
                    Button(String(localized: "Scollega")) {
                        vault = nil
                        projects = []
                        model.setObsidian(vault: nil, projects: [])
                    }
                }
            }
        }
        SettingsGroup(
            title: String(localized: "Progetti nel vault"),
            footnote: String(
                localized:
                    "I file nel vault non sono cifrati: chiunque abbia accesso alla cartella può leggerli. Si aggiornano da soli qualche secondo dopo ogni modifica."
            )
        ) {
            ForEach(model.projects) { project in
                Toggle(
                    model.client(project.clientId).map { "\(project.name) · \($0.name)" } ?? project.name,
                    isOn: Binding(
                        get: { projects.contains(project.id) },
                        set: { on in
                            if on, projects.isEmpty {
                                confirmingFirst = project.id
                            } else {
                                toggle(project.id, on)
                            }
                        })
                )
                .disabled(vault == nil)
            }
            HStack {
                if let status = model.obsidianStatus {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(String(localized: "Aggiorna ora")) { model.syncObsidianNow() }
                    .disabled(vault == nil || projects.isEmpty)
            }
        }
        .onAppear {
            vault = model.obsidianVault
            projects = model.obsidianProjects
        }
        .alert(
            String(localized: "Scrivere il progetto in chiaro nel vault?"),
            isPresented: Binding(get: { confirmingFirst != nil }, set: { if !$0 { confirmingFirst = nil } })
        ) {
            Button(String(localized: "Attiva")) {
                if let id = confirmingFirst { toggle(id, true) }
                confirmingFirst = nil
            }
            Button(String(localized: "Annulla"), role: .cancel) { confirmingFirst = nil }
        } message: {
            Text(
                String(
                    localized:
                        "Trascrizioni, email, note e decisioni del progetto verranno copiate in chiaro nella cartella del vault, fuori dall'archivio cifrato di IAGO."
                ))
        }
    }

    private func toggle(_ id: String, _ on: Bool) {
        if on { projects.insert(id) } else { projects.remove(id) }
        model.setObsidian(vault: vault, projects: projects)
    }

    private func chooseVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Usa come vault")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        vault = url
        model.setObsidian(vault: url, projects: projects)
    }
}
