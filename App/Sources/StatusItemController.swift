import AVFoundation
import AppKit
import IAGOCapture
import IAGOEngine
import IAGOStore
import IAGOTranscription

/// Owns the menu bar icon. Left click and right click are handled separately (FR-01..FR-03),
/// which is why this uses `NSStatusItem` instead of SwiftUI's `MenuBarExtra`.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let controller: RecordingController
    private let archive: ArchiveService
    private let notifier: Notifier
    private var snapshot: RecordingController.Snapshot?
    private var refreshTask: Task<Void, Never>?
    private var micOverrideUID: String?
    private var bookmarkFlashUntil: Date?
    private var importingCount = 0
    private let transcription: TranscriptionService
    /// Running transcription job and its progress (FR-01 "job in corso").
    private var runningJob: (id: String, progress: Double)?
    private var modelDownloadProgress: Double?
    /// "Attività" (ADR-0055): what the menu bar knows goes there too.
    let activity: ActivityCenter
    /// ADR-0056: a mandatory update blocks new recordings until it is installed.
    var updates: UpdateService?

    init(
        controller: RecordingController, archive: ArchiveService, transcription: TranscriptionService,
        notifier: Notifier, activity: ActivityCenter
    ) {
        self.activity = activity
        self.controller = controller
        self.archive = archive
        self.transcription = transcription
        self.notifier = notifier
        super.init()
        observeJobs()
        micOverrideUID = try? archive.archive.setting(Self.micKey)
        if let uid = micOverrideUID { Task { await controller.setMicOverride(uid: uid) } }
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
        render()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func refresh() async {
        snapshot = await controller.snapshot()
        render()
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let state = snapshot?.state ?? .idle
        let needsAttention = snapshot?.silentTrack != nil || snapshot?.lastError != nil
        var badge = MenuBarIcon.Badge.none
        switch state {
        case .idle:
            let busy =
                modelDownloadProgress != nil || engineDownload != nil || runningJob != nil || importingCount > 0
                || (snapshot?.finalizingCount ?? 0) > 0
            badge = busy ? .busy : .none
        case .recording: badge = needsAttention ? .attention : .recording
        case .paused: badge = .paused
        }
        if let until = bookmarkFlashUntil, until > Date() {
            let image = NSImage(systemSymbolName: "bookmark.fill", accessibilityDescription: accessibilityLabel(state))
            image?.isTemplate = true
            button.image = image
        } else {
            button.image = MenuBarIcon.image(badge, accessibility: accessibilityLabel(state))
        }
        if state != .idle {
            button.title = " " + Self.format(snapshot?.elapsed ?? 0)
        } else if let fraction = modelDownloadProgress ?? engineDownload?.fraction ?? runningJob?.progress {
            button.title = " \(Int(fraction * 100))%"
        } else {
            button.title = ""
        }
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    }

    /// ADR-0048: a local engine being downloaded, shown with its percentage like the transcription models.
    private var engineDownload: EngineProgress? { windows?.model.engine.progress.values.first }

    private func accessibilityLabel(_ state: RecordingController.State) -> String {
        switch state {
        case .idle: String(localized: "IAGO, inattivo")
        case .recording: String(localized: "IAGO, in registrazione")
        case .paused: String(localized: "IAGO, in pausa")
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        // Left click opens the menu (a stray click must never pause a call); right click or
        // control-click starts, pauses and resumes.
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            toggleRecording()
        } else {
            showMenu()
        }
    }

    /// A new recording waits for a mandatory update (ADR-0056); one going on is never stopped.
    private func blockedByMandatoryUpdate() -> Bool {
        guard let version = updates?.mandatoryVersion else { return false }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "Aggiornamento obbligatorio")
        alert.informativeText = String(
            localized:
                "È uscita la versione \(version) di IAGO: per continuare a registrare va installata. Ci vuole un minuto; l'archivio resta com'è."
        )
        alert.addButton(withTitle: String(localized: "Aggiorna ora"))
        alert.addButton(withTitle: String(localized: "Più tardi"))
        if alert.runModal() == .alertFirstButtonReturn { updates?.checkNow() }
        return true
    }

    private func toggleRecording() {
        if (snapshot?.state ?? .idle) == .idle, blockedByMandatoryUpdate() { return }
        Task {
            guard await MicrophonePermission.ensure() else { return }
            // FR-217: a voice note being dictated is stopped and transcribed before the call starts.
            if (snapshot?.state ?? .idle) == .idle { await windows?.model.voiceNotes.stopForCall() }
            do {
                try await controller.toggle()
            } catch {
                presentError(error)
            }
            await refresh()
        }
    }

    /// ADR-0051: a detected call is recorded the same way as from the menu. True if it started.
    func startRecordingForCall() async -> Bool {
        guard (snapshot?.state ?? .idle) == .idle, !blockedByMandatoryUpdate(), await MicrophonePermission.ensure()
        else { return false }
        await windows?.model.voiceNotes.stopForCall()
        do {
            try await controller.start()
        } catch {
            presentError(error)
            return false
        }
        await refresh()
        return true
    }

    func stopRecordingForCall() async {
        await controller.stop()
        await refresh()
    }

    @objc private func acceptCallProposal() { windows?.model.calls.acceptProposal() }

    // MARK: Menu (FR-03)

    private func showMenu() {
        let menu = NSMenu()
        let state = snapshot?.state ?? .idle

        menu.addItem(disabledItem(statusLine()))
        let open = item(String(localized: "Apri IAGO"), #selector(openMainWindow))
        open.keyEquivalent = "o"
        menu.addItem(open)
        if let silent = snapshot?.silentTrack {
            let track = silent == .mic ? String(localized: "microfono") : String(localized: "audio di sistema")
            menu.addItem(disabledItem(String(localized: "⚠︎ Traccia \(track) muta da oltre 30 s")))
        }
        if let proposal = windows?.model.calls.pendingProposal, state == .idle {
            let record = item(String(localized: "Registra la call «\(proposal)»"), #selector(acceptCallProposal))
            menu.addItem(record)
        }
        if let progress = engineDownload {
            menu.addItem(
                disabledItem(String(localized: "Download del motore: \(EnginePane.progressText(progress))")))
        }
        if let indexing = windows?.model.intelligence.indexing {
            menu.addItem(
                disabledItem(String(localized: "Indicizzo per la ricerca: \(indexing.done) di \(indexing.total)")))
        }
        if let title = windows?.model.intelligence.proposingFor {
            menu.addItem(disabledItem(String(localized: "Preparo le proposte per «\(title)»")))
        }
        if let error = snapshot?.lastError {
            menu.addItem(disabledItem(String(localized: "⚠︎ Problema nella registrazione. Dettaglio tecnico: \(error)")))
        }
        menu.addItem(.separator())

        if state == .idle {
            menu.addItem(item(String(localized: "Avvia registrazione"), #selector(startRecording)))
        } else {
            menu.addItem(
                item(
                    state == .paused ? String(localized: "Riprendi") : String(localized: "Pausa"),
                    #selector(togglePause)))
            menu.addItem(item(String(localized: "Stop"), #selector(stopRecording)))
            menu.addItem(item(String(localized: "Nuova registrazione"), #selector(newRecording)))
            menu.addItem(item(String(localized: "Scarta registrazione…"), #selector(discardRecording)))
            menu.addItem(.separator())
            let bookmark = item(String(localized: "Segna momento"), #selector(addBookmark))
            bookmark.isEnabled = state == .recording
            menu.addItem(bookmark)
            let bookmarkWithNote = item(String(localized: "Segna momento con nota…"), #selector(addBookmarkWithNote))
            bookmarkWithNote.isEnabled = state == .recording
            bookmarkWithNote.isAlternate = true
            bookmarkWithNote.keyEquivalentModifierMask = .option
            menu.addItem(bookmarkWithNote)
        }
        menu.addItem(micMenuItem())
        menu.addItem(.separator())
        // FR-216/217: not during a call (bookmarks are there for that).
        let voiceNote = item(String(localized: "Nota vocale…"), #selector(openVoiceNote))
        voiceNote.isEnabled = state == .idle
        if state != .idle { voiceNote.toolTip = String(localized: "Durante una call usa \"Segna momento\"") }
        menu.addItem(voiceNote)
        menu.addItem(item(String(localized: "Importa file…"), #selector(chooseFilesToImport)))
        if runningJob != nil {
            menu.addItem(item(String(localized: "Annulla trascrizione"), #selector(cancelTranscription)))
        }
        if modelDownloadProgress == nil, !transcription.models.missing().isEmpty {
            menu.addItem(
                item(String(localized: "Scarica modelli di trascrizione (1,6 GB)…"), #selector(downloadModels)))
        }
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Guida di IAGO"), #selector(openHelp)))
        let update = item(
            updates?.mandatoryVersion.map { String(localized: "Installa l'aggiornamento \($0) (obbligatorio)…") }
                ?? updates?.availableVersion.map { String(localized: "Installa l'aggiornamento \($0)…") }
                ?? String(localized: "Controlla aggiornamenti…"), #selector(checkUpdates))
        menu.addItem(update)
        let settings = item(String(localized: "Impostazioni…"), #selector(openSettings))
        settings.keyEquivalent = ","
        menu.addItem(settings)
        let quit = item(String(localized: "Esci"), #selector(quit))
        quit.keyEquivalent = "q"
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func statusLine() -> String {
        guard let snapshot else { return String(localized: "Inattivo") }
        let mic = snapshot.micName.map { String(localized: "mic: \($0)") } ?? String(localized: "mic: nessuno")
        switch snapshot.state {
        case .idle:
            if let fraction = modelDownloadProgress {
                return String(localized: "Download modelli… \(Int(fraction * 100))%")
            }
            if let job = runningJob { return String(localized: "Trascrizione in corso… \(Int(job.progress * 100))%") }
            if importingCount > 0 { return String(localized: "Importazione in corso…") }
            return snapshot.finalizingCount > 0
                ? String(localized: "Salvataggio in corso…") : String(localized: "Inattivo")
        case .recording: return "● \(Self.format(snapshot.elapsed)) — \(mic)"
        case .paused: return String(localized: "❚❚ In pausa \(Self.format(snapshot.elapsed)) — \(mic)")
        }
    }

    private func micMenuItem() -> NSMenuItem {
        micOverrideUID = try? archive.archive.setting(Self.micKey)
        let parent = NSMenuItem(title: String(localized: "Microfono"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let automatic = item(String(localized: "Automatico (segue l'app di call)"), #selector(selectMic(_:)))
        automatic.state = micOverrideUID == nil ? .on : .off
        submenu.addItem(automatic)
        submenu.addItem(.separator())
        for device in CaptureEngine.availableInputDevices() {
            let entry = item(device.name, #selector(selectMic(_:)))
            entry.representedObject = device.uid
            entry.state = micOverrideUID == device.uid ? .on : .off
            submenu.addItem(entry)
        }
        parent.submenu = submenu
        return parent
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func startRecording() { toggleRecording() }

    @objc private func openVoiceNote() { windows?.showVoiceNote() }

    @objc private func togglePause() { toggleRecording() }

    @objc private func stopRecording() {
        Task {
            await controller.stop()
            await refresh()
        }
    }

    @objc private func newRecording() {
        Task {
            do { try await controller.newRecording() } catch { presentError(error) }
            await refresh()
        }
    }

    /// FR-05: bookmark now, brief feedback on the icon.
    @objc private func addBookmark() {
        Task {
            guard await controller.addBookmark() != nil else { return }
            flashBookmark()
        }
    }

    /// The moment is fixed at the click; the note is added afterwards.
    @objc private func addBookmarkWithNote() {
        Task {
            guard let position = await controller.addBookmark() else { return }
            flashBookmark()
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = String(localized: "Segna momento")
            alert.informativeText = String(localized: "Nota per il momento \(Self.format(position)) (facoltativa)")
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            alert.addButton(withTitle: String(localized: "Salva"))
            alert.addButton(withTitle: String(localized: "Senza nota"))
            if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
                await controller.setBookmarkNote(at: position, note: field.stringValue)
            }
        }
    }

    private func flashBookmark() {
        bookmarkFlashUntil = Date().addingTimeInterval(1)
        render()
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            render()
        }
    }

    @objc private func selectMic(_ sender: NSMenuItem) {
        micOverrideUID = sender.representedObject as? String
        // Remembered across launches (Settings › Audio).
        try? archive.archive.setSetting(Self.micKey, micOverrideUID)
        let uid = micOverrideUID
        Task { await controller.setMicOverride(uid: uid) }
    }

    @objc private func chooseFilesToImport() {
        // Opened after the status menu has closed: a modal panel started while the menu is still
        // tracking can stay hidden behind other apps (IAGO has no Dock icon).
        DispatchQueue.main.async { [weak self] in
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.audio, .movie]
            panel.message = String(localized: "Scegli file audio o video da importare in IAGO")
            panel.prompt = String(localized: "Importa")
            panel.level = .floating
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            guard panel.runModal() == .OK else { return }
            self?.importFiles(panel.urls)
        }
    }

    /// FR-30: import from the menu. Dropping on the menu bar icon is not offered: dragging a file to
    /// the top of the screen opens Mission Control. Drop on the main window comes with block 4.
    private func importFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        importingCount += 1
        render()
        let work = activity.begin(.importFiles, urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) file")
        Task {
            let results = await archive.importFiles(urls)
            activity.end(work)
            importingCount -= 1
            render()
            // An explicit action: the imported item opens in the main window; failures in an alert.
            let imported = results.filter { if case .success = $0.result { true } else { false } }.map(\.name)
            let failures = results.compactMap { entry -> String? in
                if case .failure(let error) = entry.result {
                    "\(entry.name): \(ErrorText.describe(error))"
                } else {
                    nil
                }
            }
            if case .success(let item)? = results.last(where: { if case .success = $0.result { true } else { false } })?
                .result
            {
                windows?.showMain(selecting: item.id)
            }
            guard !failures.isEmpty else { return }
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            do {
                alert.alertStyle = .warning
                alert.messageText = String(localized: "Importazione non riuscita")
                alert.informativeText = (failures + imported.map { String(localized: "Importato: \($0)") }).joined(
                    separator: "\n")
            }
            alert.runModal()
        }
    }

    // MARK: Transcription

    private func observeJobs() {
        Task { [weak self, transcription, notifier] in
            for await event in transcription.queue.events {
                guard let self else { return }
                switch event {
                case .started(let job):
                    runningJob = (job.id, 0)
                    activity.runningJob = .init(id: job.id, itemID: job.itemId, progress: 0)
                case .progress(let jobID, let itemID, let fraction):
                    if runningJob?.id == jobID { runningJob = (jobID, fraction) }
                    if activity.runningJob?.id == jobID {
                        activity.runningJob?.progress = fraction
                    } else {
                        activity.runningJob = .init(id: jobID, itemID: itemID, progress: fraction)
                    }
                case .finished(let job):
                    runningJob = nil
                    if activity.runningJob?.id == job.id { activity.runningJob = nil }
                    let title = (try? transcription.archive.item(job.itemId ?? "")?.title) ?? ""
                    switch job.status {
                    case .done:
                        notifier.post(
                            title: String(localized: "Trascrizione completata"), body: title, fallbackToAlert: true)
                    case .failed:
                        presentAlert(String(localized: "Trascrizione non riuscita"), "\(title)\n\(job.error ?? "")")
                    default: break
                    }
                }
                render()
            }
        }
    }

    static let micKey = "mic_override_uid"

    /// Applies the microphone chosen in the settings (nil = follow the call app, ADR-0004).
    func setMicOverride(_ uid: String?) {
        micOverrideUID = uid
        try? archive.archive.setSetting(Self.micKey, uid)
        Task { await controller.setMicOverride(uid: uid) }
    }

    /// Main window and post-recording panel (block 4).
    var windows: WindowManager?

    @objc private func discardRecording() {
        windows?.model.discardRecording()
    }

    @objc private func openSettings() {
        windows?.showSettings()
    }

    @objc private func openHelp() {
        windows?.showHelp()
    }

    @objc private func checkUpdates() {
        updates?.checkNow()
    }

    @objc private func openMainWindow() {
        windows?.showMain()
    }

    /// Called when a transcription is requested but the models are missing.
    func offerModelDownload() {
        if confirmModelDownload() { downloadModels() }
    }

    @objc private func cancelTranscription() {
        guard let id = runningJob?.id else { return }
        Task { try? await transcription.queue.cancel(id) }
    }

    private func confirmModelDownload() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = String(localized: "Servono i modelli di trascrizione")
        alert.informativeText = String(
            localized:
                "IAGO trascrive solo su questo Mac. Per farlo deve scaricare una volta i modelli (circa 1,6 GB) da indirizzi fissi, verificandone l'integrità. Il download viene registrato nel registro accessi."
        )
        alert.addButton(withTitle: String(localized: "Scarica"))
        alert.addButton(withTitle: String(localized: "Annulla"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Explicit user action: the only moment IAGO goes on the network for models (spec 4.2, 7.5).
    @objc private func downloadModels() {
        guard modelDownloadProgress == nil else { return }
        modelDownloadProgress = 0
        render()
        let work = activity.begin(.modelDownload)
        Task {
            do {
                try await transcription.downloadMissingModels { fraction in
                    Task { @MainActor [weak self] in
                        self?.modelDownloadProgress = fraction
                        self?.activity.update(work, fraction: fraction)
                        self?.render()
                    }
                }
                activity.end(work)
                modelDownloadProgress = nil
                render()
                presentAlert(String(localized: "Modelli scaricati"), String(localized: "Ora IAGO può trascrivere."))
            } catch {
                activity.end(work, failure: ErrorText.describe(error))
                modelDownloadProgress = nil
                render()
                presentAlert(String(localized: "Download dei modelli non riuscito"), ErrorText.describe(error))
            }
        }
    }

    private func presentAlert(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func presentError(_ error: Error) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "Impossibile avviare la registrazione")
        alert.informativeText = ErrorText.describe(error)
        alert.runModal()
    }

    static func format(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
}

enum MicrophonePermission {
    /// Asks for microphone access the first time; explains how to fix it when denied (spec 15).
    @MainActor
    static func ensure() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = String(localized: "Accesso al microfono negato")
            alert.informativeText = String(
                localized:
                    "Consenti a IAGO l'uso del microfono in Impostazioni di Sistema › Privacy e sicurezza › Microfono.")
            alert.addButton(withTitle: String(localized: "Apri Impostazioni"))
            alert.addButton(withTitle: String(localized: "Annulla"))
            if alert.runModal() == .alertFirstButtonReturn,
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
            {
                NSWorkspace.shared.open(url)
            }
            return false
        }
    }
}
