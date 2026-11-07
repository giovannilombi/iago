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
                // As long as the call's transcript, so the moments fall along the whole bar.
                let seconds = Int(try archive.item(example.kickoffID)?.durationSec ?? 240)
                if let audio = try? silentAudio(seconds: seconds, in: folder) {
                    try archive.storeAsset(audio, itemID: example.kickoffID, kind: .audioMix, fileName: "mix.m4a")
                }
                try seedMoments(archive, itemID: example.kickoffID)
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
                // In front and active, even while the user works in another app: the guide shows an active window.
                NSApp.activate(ignoringOtherApps: true)
                (window.sheetParent ?? window).makeKeyAndOrderFront(nil)
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
            // ADR-0084: the item detail on its own, then scrolled with the sticky bar and «torna su».
            model.viewMode = .list
            await shot("scheda", main)
            try? await Task.sleep(for: .seconds(1))
            model.openDetailSection = "transcript"
            try? await Task.sleep(for: .seconds(1))
            await shot("scheda-barra", main)
            model.openDetailSection = "audio"
            try? await Task.sleep(for: .seconds(1))
            await shot("scheda-momenti", main)
            model.openDetailSection = "top"
            model.viewMode = .timeline
            model.selectedItemID = progress
            await shot("sintesi", main)
            // The playback bar: an audio started in an item stays reachable from another section.
            if let id = kickoff,
                let mix = (try? model.archive.assets(itemID: id))?.first(where: { $0.kind == .audioMix })
            {
                await model.player.load(mix, itemID: id)
                model.player.seek(to: model.player.duration * 0.4)
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
                // ADR-0098: the same project in «Modalità Raccogli», on its items, with a call open.
                model.setProjectWorkMode(portal.id, .collect)
                model.viewMode = .list
                model.selectedItemID = model.summaries.first { $0.item.type == .call }?.id
                try? await Task.sleep(for: .seconds(0.5))
                await shot("raccogli", main)
                model.selectedItemID = nil
                model.setProjectWorkMode(portal.id, .manage)
                model.importing = AppModel.ImportTarget(projectID: portal.id)
                try? await Task.sleep(for: .seconds(0.5))
                await shot("importa", main?.attachedSheet)
                model.importing = nil
            }
            // Only for design reviews, not in the guide: «Punti chiave» with an entry open, and a new key point.
            model.select(.decisions)
            model.viewMode = .timeline
            model.selectedDecisionID = (try? model.archive.setting(ssoKey)) ?? nil
            await shot("pk-dettaglio", main)
            model.editingDecision = DecisionDraft(projectID: portal?.id, kind: .openQuestion)
            try? await Task.sleep(for: .seconds(0.5))
            await shot("nuovo-punto", main)
            model.editingDecision = nil
            model.select(.inbox)
            model.viewMode = .list
            await shot("inbox", main)
            // Only for design reviews: a short window, so both boxes scroll and show «altre N».
            main?.setFrame(NSRect(x: 80, y: 80, width: 1440, height: 640), display: true)
            await shot("inbox-basso", main)
            main?.setFrame(NSRect(x: 80, y: 80, width: 1440, height: 900), display: true)
            // Only for design reviews: the proposals of one item opened on the right.
            model.proposalsItemID = (try? model.archive.pendingKeyPointSuggestions(.all))?.first?.itemId
            try? await Task.sleep(for: .seconds(0.5))
            await shot("inbox-proposte", main)
            model.proposalsItemID = nil
            model.viewMode = .list
            model.select(.labels)
            await shot("categorie-tag", main)
            model.select(.activity)
            await shot("attivita", main)
            if let portal { model.select(.library(.project(portal.id))) }
            model.showsChat = true
            await shot("chiedi", main)
            // ADR-0092: «Chiedi a IAGO» on the whole window, and the simple search in the right pane.
            model.chatFullWindow = true
            await shot("chiedi-finestra", main)
            model.chatFullWindow = false
            model.openSearch()
            model.searchText = "SSO"
            try? await Task.sleep(for: .seconds(1))
            await shot("ricerca", main)
            model.searchText = ""
            model.sidePane = nil
            for (pane, name) in [
                (SettingsView.Pane.permissions, "permessi"), (.engine, "motore"), (.claude, "claude"),
                (.voices, "voci"),
            ] {
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

        /// Two bookmarks and two slides on the kickoff, for the moments on the player and in the transcript.
        static func seedMoments(_ archive: Archive, itemID: String) throws {
            let en = AppLanguage.current == .en
            func t(_ it: String, _ english: String) -> String { en ? english : it }
            let starts =
                ((try? archive.assets(itemID: itemID))?.first { $0.kind == .transcriptJSON })
                .flatMap { try? Transcript.decode(from: archive.readAssetData($0)) }?.segments.map(\.start) ?? []
            /// A few seconds into the segment at `fraction` of the call.
            func at(_ fraction: Double) -> Double {
                starts.isEmpty ? fraction * 600 : starts[Int(Double(starts.count - 1) * fraction)] + 4
            }
            _ = try archive.addMarker(
                itemID: itemID, atSec: at(0.2), note: t("Budget da confermare", "Budget to confirm"))
            _ = try archive.addMarker(itemID: itemID, atSec: at(0.65), note: t("Chi segue l'SSO", "Who owns SSO"))
            let slides = [
                (
                    at(0.4), t("Roadmap del portale", "Portal roadmap"),
                    t("Q1 · Discovery · Wireframe · SSO", "Q1 · Discovery · Wireframes · SSO")
                ),
                (
                    at(0.85), t("Architettura headless", "Headless architecture"),
                    t("CMS · API · Frontend · CDN", "CMS · API · Front end · CDN")
                ),
            ]
            for (seconds, title, body) in slides {
                if let png = slide(title: title, body: body) {
                    _ = try archive.addScreenshot(itemID: itemID, png: png, atSec: seconds, text: "\(title)\n\(body)")
                }
            }
        }

        /// An invented slide, drawn here: never a real screen.
        static func slide(title: String, body: String) -> Data? {
            let size = NSSize(width: 960, height: 540)
            let image = NSImage(size: size, flipped: false) { rect in
                NSColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1).setFill()
                rect.fill()
                NSColor(red: 0.19, green: 0.69, blue: 0.78, alpha: 1).setFill()
                NSRect(x: 0, y: rect.height - 14, width: rect.width, height: 14).fill()
                (title as NSString).draw(
                    at: NSPoint(x: 64, y: 360),
                    withAttributes: [.font: NSFont.boldSystemFont(ofSize: 54), .foregroundColor: NSColor.black])
                (body as NSString).draw(
                    at: NSPoint(x: 64, y: 260),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 32), .foregroundColor: NSColor.darkGray])
                return true
            }
            guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
            return bitmap.representation(using: .png, properties: [:])
        }

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
