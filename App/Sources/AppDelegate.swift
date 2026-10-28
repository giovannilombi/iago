import AVFoundation
import AppKit
import IAGOCapture
import IAGOEngine
import IAGOTranscription
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "app")
    private var controller: RecordingController?
    private var paths: StoragePaths?
    private var archive: ArchiveService?
    private var transcription: TranscriptionService?
    private var windows: WindowManager?
    private var statusItemController: StatusItemController?
    private let notifier = Notifier()
    private var services: ServiceProvider?
    private var updates: UpdateService?
    private var shortcuts: GlobalShortcuts?
    private var pausedForSleep = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The Dock shows the icon while a window is open: set it explicitly, so a stale icon cache
        // never shows the generic one.
        if let icon = NSImage(named: "AppIcon") { NSApp.applicationIconImage = icon }
        do {
            // DEBUG: a demo archive elsewhere, for the guide's screenshots, or a copy of the archive to try a branch.
            let paths =
                try (DemoMode.root ?? DemoMode.trialRoot).map { StoragePaths(root: $0) } ?? StoragePaths.applicationSupport()
            try paths.createDirectories()
            try paths.clearScratch()
            self.paths = paths
            // A restore prepared before the relaunch replaces the archive before it is opened (ADR-0041).
            let restoring = FileManager.default.fileExists(atPath: paths.restorePending.path)
            if restoring { BackupService.installPendingRestore(paths: paths) }
            let archive = try ArchiveService(paths: paths)
            self.archive = archive
            if restoring { try? archive.archive.audit(.backup, action: "backup_restored") }
            let controller = RecordingController(paths: paths)
            self.controller = controller
            // One heavy job at a time on the GPU and the memory: transcription, engine, embedding (ADR-0069).
            let lane = EngineLane(
                chatBesideTranscription: EnginePolicy.chatDuringTranscription(ramGB: EnginePolicy.ramGB))
            let transcription = TranscriptionService(archive: archive.archive, paths: paths, lane: lane)
            self.transcription = transcription
            let activity = ActivityCenter()
            let statusItemController = StatusItemController(
                controller: controller, archive: archive, transcription: transcription, notifier: notifier,
                activity: activity)
            self.statusItemController = statusItemController
            let engine = EngineService(
                root: paths.models.appendingPathComponent("LLM", isDirectory: true), archive: archive.archive,
                notifier: notifier, lane: lane)
            let intelligence = IntelligenceService(
                archive: archive.archive, engine: engine, recorder: controller, notifier: notifier)
            let folderImporter = FolderImporter(archiveService: archive, notifier: notifier)
            let updates = UpdateService(archive: archive.archive)
            self.updates = updates
            statusItemController.updates = updates
            let calls = CallDetector(archive: archive.archive, recorder: controller)
            calls.startRecording = { [weak statusItemController] in
                await statusItemController?.startRecordingForCall() ?? false
            }
            calls.stopRecording = { [weak statusItemController] in await statusItemController?.stopRecordingForCall() }
            let model = AppModel(
                archiveService: archive, transcription: transcription, recorder: controller, engine: engine,
                intelligence: intelligence, folderImporter: folderImporter, calls: calls, activity: activity)
            model.updates = updates
            calls.start()
            intelligence.start()
            folderImporter.start()
            model.requestModelDownload = { [weak statusItemController] in statusItemController?.offerModelDownload() }
            model.setMicOverride = { [weak statusItemController] uid in statusItemController?.setMicOverride(uid) }
            let windows = WindowManager(model: model)
            self.windows = windows
            let services = ServiceProvider(model: model, windows: windows)
            self.services = services
            NSApp.servicesProvider = services
            NSUpdateDynamicServices()
            statusItemController.windows = windows
            NSApp.mainMenu = MainMenu.make { [weak windows] in windows?.showSettings() }
            // ADR-0072: mark a moment, with a screenshot, start or stop, from any app.
            let shortcuts = GlobalShortcuts(archive: archive.archive) { [weak statusItemController] action in
                switch action {
                case .bookmark: statusItemController?.markMoment()
                case .screenshot: statusItemController?.addScreenshot()
                case .record: statusItemController?.startOrStopRecording()
                }
            }
            shortcuts.start()
            self.shortcuts = shortcuts
            model.shortcuts = shortcuts
            observeControllerEvents(controller, archive: archive)
            observeSleep()
            Task {
                // Recovery first: it finalizes interrupted sessions into tmp/finalized, then everything
                // waiting there (and the phase 0 recordings) is encrypted into the archive.
                await recoverInterruptedSessions(controller)
                let failures = await archive.archivePending()
                if !failures.isEmpty {
                    notifier.post(
                        title: String(localized: "Errore nell'archiviazione"),
                        body: String(localized: "\(failures.count) registrazioni non sono state archiviate."))
                }
                await archive.purgeExpiredTrash()
                #if DEBUG
                    await DemoMode.seedIfNeeded(archive)
                #endif
                // A brand-new archive starts with a neutral example of the structure (ADR-0066).
                if (try? archive.archive.setting(WindowManager.onboardingKey)) != "1",
                    let example = try? archive.archive.createStarterExampleIfNew(),
                    let stream = example.streamIDs.first
                {
                    try? archive.archive.setSetting(AppModel.pinnedLabelsKey, "stream:\(stream)")
                    model.reload()
                }
                await archive.buildSearchIndexIfNeeded()
                await EngineBench.runIfRequested(
                    archive: archive.archive, engine: engine, root: paths.root, notifier: notifier)
                await EngineBench.summaryIfRequested(
                    archive: archive.archive, engine: engine, root: paths.root, notifier: notifier)
                await archive.refreshEmailBodies()
                #if DEBUG
                    await DemoMode.runTour(model: model, windows: windows, calls: calls)
                #endif
                ClaudeConnection.provisionServerKey(archive: archive.archive)
                if (try? archive.archive.setting(WindowManager.onboardingKey)) != "1"
                    || UserDefaults.standard.bool(forKey: "IAGOShowOnboarding")
                {
                    if !DebugAutomation.isActive { windows.showOnboarding() }
                } else if !DebugAutomation.isActive {
                    windows.showTour()
                }
                do {
                    try await transcription.start()
                } catch {
                    logger.error("Job queue failed to start: \(error)")
                }
                if !DebugAutomation.isActive { await model.offerVoiceNoteLeftovers() }
                #if DEBUG
                    // `-IAGODebugDictate <audio file>`: transcribes it as a voice note into `<audio file>.txt`
                    // (never in the log: no transcript content in logs).
                    if let path = UserDefaults.standard.string(forKey: "IAGODebugDictate") {
                        let start = Date()
                        do {
                            let text = try await transcription.dictate(URL(fileURLWithPath: path))
                            try text.write(toFile: path + ".txt", atomically: true, encoding: .utf8)
                            logger.notice(
                                "Debug dictate: \(text.count) characters in \(Date().timeIntervalSince(start), format: .fixed(precision: 1)) s"
                            )
                        } catch {
                            logger.error("Debug dictate failed: \(error)")
                        }
                    }
                    if UserDefaults.standard.bool(forKey: "IAGOInstallLocalModels") {
                        installLocalModels(transcription)
                    }
                    if UserDefaults.standard.bool(forKey: "IAGOOpenWindow") { windows.showMain() }
                    // `-IAGOSelectTitle <title>` (`-IAGOTimeline YES`): opens that item, for layout checks.
                    if let title = UserDefaults.standard.string(forKey: "IAGOSelectTitle"),
                        let item = try? archive.archive.items().first(where: { $0.title == title })
                    {
                        windows.showMain(selecting: item.id)
                        if UserDefaults.standard.bool(forKey: "IAGOTimeline") { windows.model.viewMode = .timeline }
                    }
                    // `-IAGODecisions YES`: the global decision register.
                    if UserDefaults.standard.bool(forKey: "IAGODecisions") {
                        windows.showMain()
                        windows.model.select(.decisions)
                    }
                    // `-IAGODebugTranscribe <itemId>` (`-IAGODebugDeleteAudio YES` for action 3).
                    if let itemID = UserDefaults.standard.string(forKey: "IAGODebugTranscribe") {
                        let delete = UserDefaults.standard.bool(forKey: "IAGODebugDeleteAudio")
                        do {
                            try await transcription.transcribe(itemID: itemID, deleteAudio: delete)
                        } catch {
                            logger.error("Debug transcribe failed: \(error)")
                        }
                    }
                #endif
                #if DEBUG
                    if let path = UserDefaults.standard.string(forKey: "IAGODebugImport") {
                        // Several files separated by "|", imported together (pairing of Teams transcripts).
                        let results = await archive.importFiles(
                            path.split(separator: "|").map { URL(fileURLWithPath: String($0)) })
                        logger.notice("Debug import: \(results.map { "\($0.name): \($0.result)" }, privacy: .public)")
                    }
                    // `-IAGODebugPurge <id|id>`: deletes these items for good, then quits (cleaning test data).
                    if let ids = UserDefaults.standard.string(forKey: "IAGODebugPurge") {
                        for id in ids.split(separator: "|") {
                            do {
                                try archive.archive.purgeItem(String(id))
                                logger.notice("Debug purge: \(id, privacy: .public) deleted")
                            } catch {
                                logger.error("Debug purge of \(id, privacy: .public) failed: \(error)")
                            }
                        }
                        exit(0)  // terminate(nil) is ignored while the launch task is still running
                    }
                    // `-IAGODebugEmail <a.eml|b.eml>`: opens the window with the email import sheet (nothing is saved
                    // until "Importa").
                    if let path = UserDefaults.standard.string(forKey: "IAGODebugEmail") {
                        windows.showMain()
                        windows.model.importFiles(path.split(separator: "|").map { URL(fileURLWithPath: String($0)) })
                    }
                #endif
                await DebugAutomation.runIfRequested(controller: controller)
            }
            scheduleDailyTrashPurge(archive)
        } catch {
            logger.error("Startup failed: \(error)")
            let alert = NSAlert()
            alert.messageText = String(localized: "IAGO non riesce ad aprire l'archivio")
            alert.informativeText = ErrorText.describe(error)
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    /// Clicking the Dock icon (shown while a window is open) brings the main window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { windows?.showMain() }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller else { return .terminateNow }
        Task {
            let snapshot = await controller.snapshot()
            if snapshot.state != .idle {
                guard confirmQuitWhileRecording() else {
                    sender.reply(toApplicationShouldTerminate: false)
                    return
                }
                await controller.stop()
            }
            await controller.waitForFinalizations()
            await transcription?.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func confirmQuitWhileRecording() -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Registrazione in corso")
        alert.informativeText = String(localized: "La registrazione verrà salvata prima di uscire.")
        alert.addButton(withTitle: String(localized: "Salva ed esci"))
        alert.addButton(withTitle: String(localized: "Annulla"))
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func recoverInterruptedSessions(_ controller: RecordingController) async {
        let recovered = await controller.recoverInterruptedSessions()
        for recording in recovered {
            logger.notice("Recovered session \(recording.itemID.rawValue)")
            notifier.post(
                title: String(localized: "Recuperata una registrazione interrotta"),
                body: recording.title, fallbackToAlert: true)
        }
    }

    #if DEBUG
        /// Debug aid: copies the models already on this Mac (repo `Models/`, FluidAudio cache) instead of
        /// downloading them again; hashes are checked as for a download.
        private func installLocalModels(_ transcription: TranscriptionService) {
            let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(
                "../../Models")
            let fluid = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FluidAudio/Models")
            let sources: [(ModelSpec, URL)] = [
                (.whisperTurbo, repo.appendingPathComponent("ggml-large-v3-turbo.bin")),
                (.vad, fluid.appendingPathComponent("silero-vad")),
                (.diarizer, fluid.appendingPathComponent("speaker-diarization")),
            ]
            for (spec, source) in sources where !transcription.models.isPresent(spec) {
                do {
                    try transcription.models.installLocal(spec, from: source.standardizedFileURL)
                    logger.notice("Installed \(spec.id, privacy: .public) from local copy")
                } catch {
                    logger.error("Local install of \(spec.id, privacy: .public) failed: \(error)")
                }
            }
        }
    #endif

    private func scheduleDailyTrashPurge(_ archive: ArchiveService) {
        Task {
            while !Task.isCancelled {
                // Every 5 minutes: discarded recordings expire after one hour (ADR-0032).
                try? await Task.sleep(for: .seconds(300))
                await archive.purgeExpiredTrash()
            }
        }
    }

    private func observeControllerEvents(_ controller: RecordingController, archive: ArchiveService) {
        Task { [weak self, logger, notifier] in
            for await event in controller.events {
                switch event {
                case .finalized(let recording):
                    logger.notice(
                        "Finalized \(recording.itemID.rawValue) (\(recording.duration, format: .fixed(precision: 1)) s)"
                    )
                    do {
                        let item = try await archive.archiveFinalized(recording.directory)
                        // ADR-0032: a discarded recording goes to "Scartate temporanee", no panel.
                        if self?.windows?.model.applyPendingDiscard(item.id) == true { continue }
                        // FR-20: classify right after Stop (not for sessions recovered after a crash).
                        if !recording.recovered, !DebugAutomation.isActive {
                            // FR-22: with a default action set in the settings, apply it without asking.
                            switch (try? archive.archive.setting(TranscriptionService.defaultActionKey)) ?? "ask" {
                            case "audio": break
                            case "transcribe":
                                self?.windows?.model.transcribe(item.id, deleteAudio: false, roomMode: false)
                            case "transcribe_delete":
                                self?.windows?.model.transcribe(item.id, deleteAudio: true, roomMode: false)
                            default: self?.windows?.showPostRecording(itemID: item.id)
                            }
                        }
                    } catch {
                        // The plaintext folder stays in tmp/finalized and is retried at the next launch.
                        logger.error("Archiving \(recording.itemID.rawValue) failed: \(error)")
                        notifier.post(
                            title: String(localized: "Errore nell'archiviazione"), body: ErrorText.describe(error))
                    }
                case .finalizationFailed(let itemID, let message):
                    logger.error("Finalization failed for \(itemID): \(message)")
                    notifier.post(
                        title: String(localized: "Errore nel salvataggio della registrazione"),
                        body: String(
                            localized:
                                "L'audio registrato resta sul Mac. Dettaglio tecnico: \(message)"
                        ))
                case .captureFailure(let message):
                    logger.error("Capture failure: \(message)")
                }
            }
        }
    }

    /// FR-15: pause automatically on sleep, ask whether to resume on wake.
    private func observeSleep() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleWillSleep() }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleDidWake() }
        }
    }

    private func handleWillSleep() {
        guard let controller else { return }
        Task {
            if await controller.snapshot().state == .recording {
                await controller.pause(dueToSleep: true)
                pausedForSleep = true
            }
        }
    }

    private func handleDidWake() {
        guard pausedForSleep, let controller else { return }
        pausedForSleep = false
        let alert = NSAlert()
        alert.messageText = String(localized: "Registrazione in pausa")
        alert.informativeText = String(
            localized: "La registrazione è stata messa in pausa quando il Mac è andato in stop.")
        alert.addButton(withTitle: String(localized: "Riprendi"))
        alert.addButton(withTitle: String(localized: "Stop e salva"))
        alert.addButton(withTitle: String(localized: "Lascia in pausa"))
        NSApp.activate()
        let response = alert.runModal()
        Task {
            switch response {
            case .alertFirstButtonReturn: await controller.resume()
            case .alertSecondButtonReturn: await controller.stop()
            default: break
            }
        }
    }
}
