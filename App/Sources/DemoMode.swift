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

        /// Fills an empty demo archive once.
        @MainActor
        static func seedIfNeeded(_ service: ArchiveService) async {
            let archive = service.archive
            guard root != nil, ((try? archive.clients()) ?? []).isEmpty else { return }
            do {
                try archive.setSetting(WindowManager.onboardingKey, "1")
                try archive.setSetting(WindowManager.tourHiddenKey, "1")
                let acme = try archive.createClient(name: "Acme Srl")
                try archive.updateClient(acme.id) { $0.color = "#2F7DE1" }
                let verdi = try archive.createClient(name: "Studio Verdi")
                try archive.updateClient(verdi.id) { $0.color = "#3BB273" }
                let portal = try archive.createProject(name: "Portale clienti")
                let loyalty = try archive.createProject(name: "App fedeltà")
                let rebrand = try archive.createProject(name: "Rebranding")
                let training = try archive.createProject(name: "Formazione interna")
                for (project, client) in [(portal, acme), (loyalty, acme), (rebrand, verdi)] {
                    try archive.setProjectClient(project.id, client.id)
                }
                try archive.setProjectPinned(portal.id, true)
                let design = try archive.createStream(projectID: portal.id, name: "Design")
                _ = try archive.createStream(projectID: portal.id, name: "Sviluppo")
                let categories = Dictionary(uniqueKeysWithValues: try archive.categories().map { ($0.name, $0.id) })

                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
                    "iago-demo", isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                var items: [String: Item] = [:]
                for call in calls {
                    let url = folder.appendingPathComponent("\(call.title).vtt")
                    try vtt(call.turns).write(to: url, atomically: true, encoding: .utf8)
                    guard case .success(let item)? = await service.importFiles([url]).first?.result else { continue }
                    let project = [
                        "portal": portal, "loyalty": loyalty, "rebrand": rebrand, "training": training,
                    ][call.project]
                    _ = try archive.updateItem(item.id) {
                        $0.title = call.title
                        $0.occurredAt = call.date
                        $0.projectId = project?.id
                        $0.categoryId = categories[call.category]
                    }
                    try archive.setTags(call.tags, for: item.id)
                    if call.project == "portal" { try archive.setStreams([design.id], itemID: item.id) }
                    if let summary = call.summary {
                        try archive.saveSummary(
                            itemID: item.id, categoryID: categories[call.category], templateID: call.template,
                            markdown: summary, model: "gemma-4-12b")
                    }
                    items[call.title] = item
                }
                // Email and document.
                let eml = folder.appendingPathComponent("wireframe.eml")
                try email.write(to: eml, atomically: true, encoding: .utf8)
                let brief = folder.appendingPathComponent("Brief portale clienti.md")
                try briefText.write(to: brief, atomically: true, encoding: .utf8)
                for url in [brief] {
                    if case .success(let item)? = await service.importFiles([url]).first?.result {
                        _ = try archive.updateItem(item.id) { $0.projectId = portal.id }
                    }
                }
                if var draft = try? service.readEmail(eml) {
                    draft.projectID = portal.id
                    _ = try? await service.importEmail(draft)
                }

                // Key points, with a decision that supersedes another.
                let kickoff = items["Kickoff portale clienti"]
                // Silent audio, so the player and the playback bar have something to show.
                if let kickoff, let audio = try? silentAudio(seconds: 1_860, in: folder) {
                    try archive.storeAsset(audio, itemID: kickoff.id, kind: .audioMix, fileName: "mix.m4a")
                    _ = try archive.updateItem(kickoff.id) { $0.durationSec = 1_860 }
                }
                let december = try archive.createDecision(
                    Decision(
                        text: "Rilascio del portale entro il 15 dicembre", decidedAt: day(-12, 10),
                        projectId: portal.id,
                        sourceItemId: kickoff?.id, sourceAtSec: 95, origin: .manual))
                _ = try archive.createDecision(
                    Decision(
                        text: "Rilascio spostato a fine gennaio", decidedAt: day(-2, 11), projectId: portal.id,
                        sourceItemId: items["SAL settimanale portale"]?.id, sourceAtSec: 140, origin: .manual,
                        notes: "Serve più tempo per l'accesso con SSO aziendale."), supersedes: [december.id])
                _ = try archive.createDecision(
                    Decision(
                        text: "Accesso con SSO aziendale", decidedAt: day(-12, 10), projectId: portal.id,
                        sourceItemId: kickoff?.id, sourceAtSec: 62, origin: .manual), people: ["Marta Rossi"])
                _ = try archive.createDecision(
                    Decision(
                        text: "Inviare i wireframe della home", decidedAt: day(-12, 10), projectId: portal.id,
                        sourceItemId: kickoff?.id, sourceAtSec: 170, origin: .manual, kind: .action),
                    people: ["Luca Bianchi"])
                _ = try archive.createDecision(
                    Decision(
                        text: "Kickoff con Acme", decidedAt: day(-12, 10), projectId: portal.id,
                        sourceItemId: kickoff?.id, origin: .manual, kind: .milestone))
                // Open work for the kanban and the overview (ADR-0074).
                var sso = Decision(
                    text: "Configurare l'accesso SSO", decidedAt: day(-5, 9), projectId: portal.id, origin: .manual,
                    kind: .action)
                sso.status = .inProgress
                sso.dueAt = day(6, 18)
                sso.ownerId = try archive.person(named: "Luca Bianchi")?.id
                _ = try archive.createDecision(sso, people: ["Luca Bianchi"])
                _ = try archive.createDecision(
                    Decision(
                        text: "Quale provider SSO usa Acme?", decidedAt: day(-4, 15), projectId: portal.id,
                        origin: .manual, kind: .openQuestion), people: ["Marta Rossi"])
                var late = Decision(
                    text: "I testi definitivi arrivano tardi", decidedAt: day(-3, 9), projectId: portal.id,
                    origin: .manual, kind: .risk)
                late.severity = .high
                _ = try archive.createDecision(late)
                _ = try archive.createDecision(
                    Decision(
                        text: "Aggiungere la pagina FAQ", decidedAt: day(-1, 16), projectId: portal.id,
                        origin: .manual, kind: .request), people: ["Marta Rossi"])
                _ = try archive.addNote(
                    itemID: nil, projectID: portal.id,
                    body: "Ricordarsi di chiedere ad Acme i testi definitivi delle pagine prodotto.",
                    notedAt: day(-3, 9))
                if let tag = try archive.tags(for: kickoff?.id ?? "").first {
                    try archive.setSetting(AppModel.pinnedLabelsKey, "tag:\(tag.id)")
                }
            } catch {
                logger.error("Demo seed failed: \(String(describing: error), privacy: .public)")
            }
        }

        /// Walks the window through the guide's screens, waiting for each screenshot.
        @MainActor
        static func runTour(model: AppModel, windows: WindowManager, calls detector: CallDetector) async {
            guard let path = UserDefaults.standard.string(forKey: "IAGODemoTour") else { return }
            let out = URL(fileURLWithPath: path, isDirectory: true)
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            model.reload()
            let portal = model.projects.first { $0.name == "Portale clienti" }
            let item = { (title: String) in
                (try? model.archive.summaries(.recent))?.first { $0.item.title == title }?.id
            }
            func shot(_ name: String, _ window: NSWindow?) async {
                guard let window else { return }
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
            model.selectedItemID = item("Kickoff portale clienti")
            await shot("finestra", main)
            model.selectedItemID = item("SAL settimanale portale")
            await shot("sintesi", main)
            // The playback bar: an audio started in an item stays reachable from another section.
            if let id = item("Kickoff portale clienti"),
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
            model.selectedDecisionID =
                (try? model.archive.decisions(DecisionQuery(scope: .all)))?.first {
                    $0.decision.text == "Configurare l'accesso SSO"
                }?.id
            await shot("kanban", main)
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
            for (pane, name) in [(SettingsView.Pane.permissions, "permessi"), (.engine, "motore")] {
                model.settingsPane = pane
                windows.showSettings()
                await shot(name, NSApp.windows.first { $0.title == String(localized: "Impostazioni di IAGO") })
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

        static func day(_ offset: Int, _ hour: Int) -> Date {
            let start = Calendar.current.startOfDay(for: Date())
            return Calendar.current.date(
                byAdding: .hour, value: hour, to: start.addingTimeInterval(Double(offset) * 86_400))!
        }

        struct Call {
            var title: String
            var project: String
            var category: String
            var template: String
            var date: Date
            var tags: [String]
            var turns: [(Double, String, String)]
            var summary: String?
        }

        static func vtt(_ turns: [(Double, String, String)]) -> String {
            func clock(_ seconds: Double) -> String {
                String(
                    format: "%02d:%02d:%06.3f", Int(seconds) / 3600, Int(seconds) / 60 % 60,
                    seconds.truncatingRemainder(dividingBy: 60))
            }
            var lines = ["WEBVTT", ""]
            for (index, turn) in turns.enumerated() {
                let end = index + 1 < turns.count ? turns[index + 1].0 : turn.0 + 8
                lines += ["\(clock(turn.0)) --> \(clock(end))", "<v \(turn.1)>\(turn.2)</v>", ""]
            }
            return lines.joined(separator: "\n")
        }

        static let calls: [Call] = [
            Call(
                title: "Kickoff portale clienti", project: "portal", category: "Kickoff", template: "kickoff",
                date: day(-12, 10), tags: ["ux", "budget"],
                turns: [
                    (0, "Marta Rossi", "Buongiorno a tutti, oggi partiamo con il portale clienti di Acme."),
                    (
                        14, "Marta Rossi",
                        "L'obiettivo è che i clienti vedano ordini, fatture e assistenza in un unico posto."
                    ),
                    (38, "Luca Bianchi", "Per il design partiamo dalla home e dall'area ordini, poi il resto."),
                    (62, "Marta Rossi", "Sull'accesso abbiamo deciso: si entra con il SSO aziendale di Acme."),
                    (95, "Paolo Neri", "Per il rilascio puntiamo al 15 dicembre, con un budget di 40.000 euro."),
                    (128, "Luca Bianchi", "Il rischio principale è l'integrazione con il loro gestionale."),
                    (151, "Marta Rossi", "Io seguo il cliente, Luca il design, Paolo lo sviluppo."),
                    (170, "Luca Bianchi", "Venerdì vi mando i primi wireframe della home."),
                    (196, "Marta Rossi", "Perfetto, ci aggiorniamo ogni lunedì con un SAL."),
                ],
                summary: """
                    ## In breve

                    Avviato il portale clienti di Acme: ordini, fatture e assistenza in un unico posto. Accesso con SSO aziendale, rilascio previsto il 15 dicembre con 40.000 euro di budget. Primi wireframe venerdì.

                    ## Panoramica

                    Un portale in cui i clienti di Acme vedono ordini, fatture e assistenza. [00:14](iago://seek/14)

                    ## Criteri di successo

                    _Non emerso_

                    ## Persone e ruoli

                    | Persona | Ruolo | Minuto |
                    | --- | --- | --- |
                    | Marta Rossi | Segue il cliente | [02:31](iago://seek/151) |
                    | Luca Bianchi | Design | [02:31](iago://seek/151) |
                    | Paolo Neri | Sviluppo | [02:31](iago://seek/151) |

                    ## Tempi e tappe

                    | Tappa | Data | Minuto |
                    | --- | --- | --- |
                    | Rilascio del portale | 15 dicembre | [01:35](iago://seek/95) |

                    ## Rischi e dipendenze

                    - Integrazione con il gestionale di Acme. [02:08](iago://seek/128)

                    ## Come ci si aggiorna

                    - SAL ogni lunedì. [03:16](iago://seek/196)

                    ## Prossimi passi

                    | Chi | Cosa | Entro | Minuto |
                    | --- | --- | --- | --- |
                    | Luca Bianchi | Inviare i wireframe della home | venerdì | [02:50](iago://seek/170) |
                    """),
            Call(
                title: "SAL settimanale portale", project: "portal", category: "SAL", template: "projectSync",
                date: day(-2, 11), tags: ["ux"],
                turns: [
                    (0, "Marta Rossi", "Facciamo il punto sul portale clienti."),
                    (18, "Luca Bianchi", "I wireframe della home e dell'area ordini sono approvati dal cliente."),
                    (52, "Paolo Neri", "L'integrazione con il gestionale funziona sugli ordini, mancano le fatture."),
                    (88, "Paolo Neri", "Il SSO di Acme richiede un certificato che arriva tra due settimane."),
                    (140, "Marta Rossi", "Allora spostiamo il rilascio a fine gennaio, lo comunico io ad Acme."),
                    (175, "Luca Bianchi", "Intanto completo il design dell'area assistenza."),
                ],
                summary: """
                    ## In breve

                    Wireframe approvati e ordini già collegati al gestionale. Il certificato per il SSO arriva tra due settimane: il rilascio si sposta a fine gennaio.

                    ## Avanzamento

                    Approvati i wireframe di home e area ordini; ordini collegati al gestionale. [00:18](iago://seek/18)

                    ## Tappe e stato

                    | Tappa | Stato | Previsione | Minuto |
                    | --- | --- | --- | --- |
                    | Wireframe | approvati | — | [00:18](iago://seek/18) |
                    | Integrazione fatture | da fare | — | [00:52](iago://seek/52) |

                    ## Rischi e contromisure

                    | Rischio | Impatto | Contromisura | Chi | Minuto |
                    | --- | --- | --- | --- | --- |
                    | Certificato SSO in ritardo | rilascio | Spostare il rilascio | Marta Rossi | [01:28](iago://seek/88) |

                    ## Decisioni

                    | Decisione | Motivo | Minuto |
                    | --- | --- | --- |
                    | Rilascio spostato a fine gennaio | Certificato SSO tra due settimane | [02:20](iago://seek/140) |

                    ## Attività

                    | Chi | Cosa | Entro | Minuto |
                    | --- | --- | --- | --- |
                    | Marta Rossi | Comunicare il nuovo rilascio ad Acme | — | [02:20](iago://seek/140) |
                    | Luca Bianchi | Completare il design dell'area assistenza | — | [02:55](iago://seek/175) |

                    ## Documenti citati

                    _Non emerso_
                    """),
            Call(
                title: "Presentazione nuovo logo", project: "rebrand", category: "Review/Demo",
                template: "designReview",
                date: day(-5, 15), tags: ["brand"],
                turns: [
                    (0, "Anna Verdi", "Vi mostro le tre proposte di logo."),
                    (40, "Giorgio Verdi", "La seconda è la più leggibile anche in piccolo."),
                    (75, "Anna Verdi", "Allora sviluppiamo la seconda e proviamo due varianti di colore."),
                ], summary: nil),
            Call(
                title: "1to1 con Marta", project: "training", category: "1to1", template: "oneOnOne",
                date: day(-1, 17), tags: [],
                turns: [
                    (0, "Marta Rossi", "Questo mese il portale mi ha preso quasi tutto il tempo."),
                    (30, "Marta Rossi", "Vorrei fare il corso di facilitazione a novembre."),
                ], summary: nil),
        ]

        static let email = """
            From: Luca Bianchi <luca.bianchi@acme.example>
            To: Marta Rossi <marta.rossi@acme.example>
            Subject: Wireframe home - prima versione
            Date: \(DateFormatter.rfc822.string(from: day(-9, 16)))
            Message-ID: <demo-wireframe@acme.example>
            Content-Type: text/plain; charset=utf-8

            Ciao Marta,
            in allegato la prima versione dei wireframe della home e dell'area ordini.
            Fammi sapere entro mercoledì.
            Luca
            """

        static let briefText = """
            # Brief portale clienti

            Acme vuole un portale in cui i clienti trovino ordini, fatture e assistenza.

            - Accesso con SSO aziendale.
            - Prima versione: home, ordini, fatture.
            - Budget: 40.000 euro.
            """
    #endif
}

#if DEBUG
    extension DateFormatter {
        static let rfc822: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            return formatter
        }()
    }
#endif
