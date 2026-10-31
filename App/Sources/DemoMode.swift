import AVFoundation
import AppKit
import IAGOCapture
import IAGOCore
import IAGOStore
import os

/// Debug only: a demo archive with invented clients, projects, calls and summaries, for the guide's screenshots
/// (CLAUDE.md: never real data in images). `-IAGODemoRoot <dir>` opens the archive there instead of the user's;
/// `-IAGODemoTour <dir>` then walks the window through the guide's screens: for each one it writes
/// `<name>.ready` (the window number) and waits for `<name>.png`, taken outside with `screencapture -l`.
enum DemoMode {
    static var root: URL? {
        #if DEBUG
            UserDefaults.standard.string(forKey: "IAGODemoRoot").map { URL(fileURLWithPath: $0, isDirectory: true) }
        #else
            nil
        #endif
    }

    /// A demo archive is open: no first-visit sheets, the tour shows them itself.
    static var isActive: Bool { root != nil }

    /// Debug only: `-IAGOTrialRoot <dir>` opens a copy of the user's archive there, to try a branch without touching
    /// the real one (`scripts/try-branch.sh`). Unlike the demo root, nothing is seeded.
    static var trialRoot: URL? {
        #if DEBUG
            UserDefaults.standard.string(forKey: "IAGOTrialRoot").map { URL(fileURLWithPath: $0, isDirectory: true) }
        #else
            nil
        #endif
    }

    #if DEBUG
        static let logger = Logger(subsystem: "com.giovannilombi.iago", category: "demo")

        /// Fills an empty demo archive once, with the same example projects a new archive gets (ADR-0066), plus a
        /// silent audio so the player and the playback bar have something to show.
        @MainActor
        static func seedIfNeeded(_ service: ArchiveService) async {
            let archive = service.archive
            guard root != nil, ((try? archive.clients()) ?? []).isEmpty else { return }
            do {
                try archive.setSetting(WindowManager.onboardingKey, "1")
                try archive.setSetting(WindowManager.tourHiddenKey, "1")
                try archive.setSetting(StarterExample.doneKey, "1")
                let example = try archive.createExample(language: AppLanguage.current.rawValue)
                try archive.setSetting(kickoffKey, example.kickoffID)
                try archive.setSetting(progressKey, example.progressID)
                try archive.setSetting(ssoKey, example.ssoTaskID)
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
                    "iago-demo", isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                if let audio = try? silentAudio(seconds: 1_860, in: folder) {
                    try archive.storeAsset(audio, itemID: example.kickoffID, kind: .audioMix, fileName: "mix.m4a")
                    _ = try archive.updateItem(example.kickoffID) { $0.durationSec = 1_860 }
                }
                if let tag = try archive.tags(for: example.kickoffID).first {
                    try archive.setSetting(AppModel.pinnedLabelsKey, "tag:\(tag.id)")
                }
            } catch {
                logger.error("Demo seed failed: \(String(describing: error), privacy: .public)")
            }
        }

        static let kickoffKey = "demo.kickoff"
        static let progressKey = "demo.progress"
        static let ssoKey = "demo.sso"

        /// Walks the window through the guide's screens, waiting for each screenshot.
        @MainActor
        static func runTour(model: AppModel, windows: WindowManager, calls detector: CallDetector) async {
            guard let path = UserDefaults.standard.string(forKey: "IAGODemoTour") else { return }
            let out = URL(fileURLWithPath: path, isDirectory: true)
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            model.reload()
            let portal = ((try? model.archive.exampleMainProjectID()) ?? nil).flatMap { id in
                model.projects.first { $0.id == id }
            }
            let kickoff = (try? model.archive.setting(kickoffKey)) ?? nil
            let progress = (try? model.archive.setting(progressKey)) ?? nil
            // `-IAGODemoShots a,b`: only these screens, to check a fix without retaking the whole guide.
            let only = UserDefaults.standard.string(forKey: "IAGODemoShots").map {
                Set($0.split(separator: ",").map(String.init))
            }
            func shot(_ name: String, _ window: NSWindow?) async {
                guard let window, only?.contains(name) ?? true else { return }
                try? await Task.sleep(for: .seconds(1.5))
                try? "\(window.windowNumber)".write(
                    to: out.appendingPathComponent("\(name).ready"), atomically: true, encoding: .utf8)
                for _ in 0..<120 {
                    if FileManager.default.fileExists(atPath: out.appendingPathComponent("\(name).png").path) { break }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
            windows.showMain()
            let main = NSApp.windows.first { $0.frameAutosaveName == "IAGOMainWindow" } ?? NSApp.keyWindow
            main?.setFrame(NSRect(x: 80, y: 80, width: 1440, height: 900), display: true)
            if let portal { model.select(.library(.project(portal.id))) }
            model.viewMode = .timeline
            model.viewContent = .all
            model.selectedItemID = kickoff
            await shot("finestra", main)
            model.selectedItemID = progress
            await shot("sintesi", main)
            // The playback bar: an audio started in an item stays reachable from another section.
            if let id = kickoff,
                let mix = (try? model.archive.assets(itemID: id))?.first(where: { $0.kind == .audioMix })
            {
                await model.player.load(mix, itemID: id)
                model.player.seek(to: 494)
                model.select(.activity)
                await shot("ascolto", main)
                model.player.close()
            }
            if let portal { model.select(.library(.project(portal.id))) }
            model.viewMode = .timeline
            await shot("punti-chiave", main)
            // ADR-0075: the wide views, with the inspector open on a card.
            model.viewMode = .board
            model.selectedDecisionID = (try? model.archive.setting(ssoKey)) ?? nil
            await shot("kanban", main)
            model.viewMode = .map
            model.selectedDecisionID = nil
            await shot("grafo", main)
            model.viewMode = .overview
            await shot("riepilogo", main)
            // ADR-0076: the same project in «Modalità Traccia», its short «Riepilogo», and the two sheets.
            if let portal {
                model.setProjectWorkMode(portal.id, .track)
                model.viewMode = .overview
                await shot("riepilogo-breve", main)
                model.setProjectWorkMode(portal.id, .manage)
                model.modeIntro = .project(portal.id)
                try? await Task.sleep(for: .seconds(0.5))
                await shot("modalita", main?.attachedSheet)
                model.modeIntro = nil
                model.importing = AppModel.ImportTarget(projectID: portal.id)
                try? await Task.sleep(for: .seconds(0.5))
                await shot("importa", main?.attachedSheet)
                model.importing = nil
            }
            model.select(.inbox)
            model.viewMode = .list
            await shot("inbox", main)
            model.viewMode = .list
            model.select(.labels)
            await shot("categorie-tag", main)
            model.select(.activity)
            await shot("attivita", main)
            if let portal { model.select(.library(.project(portal.id))) }
            model.showsChat = true
            await shot("chiedi", main)
            model.showsChat = false
            for (pane, name) in [(SettingsView.Pane.permissions, "permessi"), (.engine, "motore"), (.claude, "claude")]
            {
                model.settingsPane = pane
                windows.showSettings()
                await shot(name, NSApp.windows.first { $0.title == String(localized: "Impostazioni di IAGO") })
            }
            // The panel after Stop (FR-20), with those present (ADR-0031).
            if let sal = progress {
                windows.showPostRecording(itemID: sal)
                await shot(
                    "dopo-stop",
                    NSApp.windows.first { $0.title == String(localized: "Nuova registrazione") && $0.isVisible })
                NSApp.windows.first { $0.title == String(localized: "Nuova registrazione") }?.close()
            }
            detector.showExamplePrompt()
            try? await Task.sleep(for: .seconds(1))
            await shot("proposta", NSApp.windows.first { $0 is NSPanel && $0.isVisible && $0.frame.width < 500 })
            windows.showHelp()
            await shot("guida", NSApp.windows.first { $0.title == String(localized: "Guida di IAGO") })
            windows.showTour(force: true)
            await shot(
                "tour", NSApp.windows.first { $0.title == String(localized: "Benvenuto in IAGO") && $0.isVisible })
            try? "".write(to: out.appendingPathComponent("done"), atomically: true, encoding: .utf8)
            // `terminate` waited on open sheets and left the demo running: the tour has nothing to save.
            exit(0)
        }

        // MARK: Content (invented)

        static func silentAudio(seconds: Int, in folder: URL) throws -> URL {
            let url = folder.appendingPathComponent("silence.m4a")
            try? FileManager.default.removeItem(at: url)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16_000, AVNumberOfChannelsKey: 1,
            ]
            let file = try AVAudioFile(forWriting: url, settings: settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 16_000)!
            buffer.frameLength = 16_000
            for _ in 0..<seconds { try file.write(from: buffer) }
            return url
        }
    #endif
}
