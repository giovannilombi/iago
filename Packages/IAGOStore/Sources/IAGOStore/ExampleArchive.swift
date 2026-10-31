import Foundation
import GRDB
import IAGOCore

/// ADR-0066 (changed 2026-10-30): a new archive starts with example projects of an invented digital agency, so every
/// part of IAGO has something to show. Three invented clients (Poldo S.p.A., Sanna TheBest s.r.l., Atoms) with calls,
/// emails, documents, key points, notes and proposals about UX, UI, product design, branding and headless development.
/// Written once in the app's language, dated around the day it is created. Its items carry `capture_meta = example`
/// (they do not tick the introduction's first steps) and «Rimuovi l'esempio» takes it all away.
public enum ExampleArchive {
    public static let marker = "example"
    /// Client and project IDs of the example, comma-separated: what «Rimuovi l'esempio» deletes.
    public static let idsKey = "example_ids"
    /// The main project, opened by the introduction.
    public static let mainProjectKey = "example_main_project"

    /// What was created, for the caller (pinned stream) and the demo tour.
    public struct Created: Sendable {
        public var mainProjectID: String
        public var firstStreamID: String
        public var kickoffID: String
        public var progressID: String
        public var ssoTaskID: String
    }
}

extension Archive {
    /// The example's main project, if the example is still there.
    public func exampleMainProjectID() throws -> String? {
        guard let id = try setting(ExampleArchive.mainProjectKey),
            try projects(includeArchived: true).contains(where: { $0.id == id })
        else { return nil }
        return id
    }

    public func hasExample() throws -> Bool { !(try setting(ExampleArchive.idsKey) ?? "").isEmpty }

    /// Deletes the example's projects with everything in them, and its clients. What the user moved elsewhere stays.
    public func removeExample() throws {
        let ids = Set((try setting(ExampleArchive.idsKey) ?? "").split(separator: ",").map(String.init))
        for project in try projects(includeArchived: true) where ids.contains(project.id) {
            try deleteProject(project.id)
        }
        for client in try clients(includeArchived: true) where ids.contains(client.id) {
            try deleteClient(client.id)
        }
        try setSetting(ExampleArchive.idsKey, nil)
        try setSetting(ExampleArchive.mainProjectKey, nil)
    }

    /// Creates the example in `language` ("it" or "en").
    @discardableResult
    public func createExample(language: String, now: Date = Date()) throws -> ExampleArchive.Created {
        let en = language == "en"
        func t(_ it: String, _ english: String) -> String { en ? english : it }
        let calendar = Calendar.current
        func day(_ offset: Int, _ hour: Int) -> Date {
            let start = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .hour, value: hour, to: start.addingTimeInterval(Double(offset) * 86_400))!
        }
        let categories = Dictionary(
            try self.categories().map { ($0.name, $0.id) }, uniquingKeysWith: { first, _ in first })
        func category(_ names: String...) -> String? { names.lazy.compactMap { categories[$0] }.first }

        // Clients and projects.
        let poldo = try createClient(name: "Poldo S.p.A.")
        try updateClient(poldo.id) { $0.color = "#2F7DE1" }
        let sanna = try createClient(name: "Sanna TheBest s.r.l.")
        try updateClient(sanna.id) { $0.color = "#3BB273" }
        let atoms = try createClient(name: "Atoms")
        try updateClient(atoms.id) { $0.color = "#E8833A" }
        let portal = try createProject(name: t("Portale clienti headless", "Headless customer portal"))
        let system = try createProject(name: t("Design system", "Design system"))
        let brand = try createProject(name: t("Rebranding", "Rebranding"))
        let discovery = try createProject(name: t("Product discovery", "Product discovery"))
        let team = try createProject(name: t("Team e formazione", "Team and training"))
        for (project, client) in [(portal, poldo), (system, poldo), (brand, sanna), (discovery, atoms)] {
            try setProjectClient(project.id, client.id)
        }
        try setProjectPinned(portal.id, true)
        let uxui = try createStream(projectID: portal.id, name: "UX/UI")
        let development = try createStream(projectID: portal.id, name: t("Sviluppo", "Development"))
        try setSetting(
            ExampleArchive.idsKey,
            [poldo.id, sanna.id, atoms.id, portal.id, system.id, brand.id, discovery.id, team.id].joined(separator: ",")
        )
        try setSetting(ExampleArchive.mainProjectKey, portal.id)

        // Calls: a transcript with named speakers, and a summary for the main ones.
        func call(
            _ title: String, project: String, category: String?, template: String?, date: Date, tags: [String],
            streams: [String] = [], turns: [(Double, String, String)], summary: String? = nil
        ) throws -> Item {
            var names: [String] = []
            for turn in turns where !names.contains(turn.1) { names.append(turn.1) }
            let ids = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, "s\($0 + 1)") })
            let duration = (turns.last?.0 ?? 0) + 20
            var item = try createItem(
                title: title, occurredAt: date, source: .import, status: .transcribed, durationSec: duration,
                captureMeta: ExampleArchive.marker)
            item = try updateItem(item.id) {
                $0.projectId = project
                $0.categoryId = category
            }
            let segments = turns.enumerated().map { index, turn in
                Transcript.Segment(
                    id: index + 1, speaker: ids[turn.1]!, start: turn.0,
                    end: index + 1 < turns.count ? turns[index + 1].0 - 0.5 : turn.0 + 15, text: turn.2)
            }
            let transcript = Transcript(
                itemId: item.id, engine: .init(asr: "example", model: "IAGO"), language: language,
                speakers: names.map { .init(id: ids[$0]!, label: $0, source: .import) }, segments: segments)
            try storeAsset(transcript.encoded(), itemID: item.id, kind: .transcriptJSON, fileName: "transcript.json")
            try setSpeakers(names.map { (ids[$0]!, $0) }, for: item.id)
            try indexTranscript(transcript, itemID: item.id)
            try setTags(tags, for: item.id)
            if !streams.isEmpty { try setStreams(streams, itemID: item.id) }
            if let summary {
                try saveSummary(
                    itemID: item.id, categoryID: category, templateID: template, markdown: summary, model: "gemma-4-12b"
                )
            }
            return item
        }

        let kickoff = try call(
            t("Kickoff portale headless", "Headless portal kickoff"), project: portal.id,
            category: category("Kickoff"), template: "kickoff", date: day(-16, 10), tags: ["ux", "headless", "budget"],
            streams: [uxui.id],
            turns: [
                (
                    0, "Marta Rossi",
                    t(
                        "Buongiorno a tutti, oggi partiamo con il nuovo portale clienti di Poldo.",
                        "Good morning everyone, today we start Poldo's new customer portal.")
                ),
                (
                    14, "Marta Rossi",
                    t(
                        "L'obiettivo è che i clienti vedano ordini, fatture e assistenza in un unico posto, anche da mobile.",
                        "The goal is for customers to see orders, invoices and support in one place, on mobile too.")
                ),
                (
                    40, "Paolo Neri",
                    t(
                        "Proponiamo un'architettura headless: CMS per i contenuti e front-end in Next.js sulle API di Poldo.",
                        "We propose a headless architecture: a CMS for content and a Next.js front end on Poldo's APIs."
                    )
                ),
                (
                    66, "Marta Rossi",
                    t(
                        "Sull'accesso abbiamo deciso: si entra con il SSO aziendale di Poldo.",
                        "On sign-in we decided: you get in with Poldo's company SSO.")
                ),
                (
                    95, "Paolo Neri",
                    t(
                        "Per il rilascio puntiamo al 15 dicembre, con un budget di 60.000 euro.",
                        "For the release we aim at December 15, with a budget of 60,000 euros.")
                ),
                (
                    128, "Luca Bianchi",
                    t(
                        "Per la UX partiamo da interviste a cinque clienti, poi wireframe di home e area ordini.",
                        "For UX we start with interviews with five customers, then wireframes of home and orders.")
                ),
                (
                    151, "Luca Bianchi",
                    t(
                        "Il rischio principale è l'integrazione con il loro gestionale.",
                        "The main risk is the integration with their ERP.")
                ),
                (
                    170, "Marta Rossi",
                    t(
                        "Io seguo il cliente, Luca la UX e la UI, Paolo lo sviluppo.",
                        "I follow the client, Luca UX and UI, Paolo development.")
                ),
                (
                    188, "Luca Bianchi",
                    t(
                        "Venerdì vi mando i primi wireframe della home.",
                        "On Friday I'll send you the first wireframes of the home page.")
                ),
                (
                    205, "Marta Rossi",
                    t(
                        "Perfetto, ci aggiorniamo ogni lunedì con un SAL.",
                        "Great, we'll catch up every Monday with a progress review.")
                ),
            ],
            summary: t(
                """
                ## In breve

                Avviato il portale clienti di Poldo: ordini, fatture e assistenza in un unico posto, anche da mobile. Architettura headless (CMS e Next.js), accesso con SSO aziendale, rilascio previsto il 15 dicembre con 60.000 euro di budget.

                ## Panoramica

                Un portale in cui i clienti di Poldo vedono ordini, fatture e assistenza. [00:14](iago://seek/14)

                ## Scelte tecniche

                - Headless: CMS per i contenuti, front-end Next.js sulle API di Poldo. [00:40](iago://seek/40)
                - Accesso con SSO aziendale. [01:06](iago://seek/66)

                ## Persone e ruoli

                | Persona | Ruolo | Minuto |
                | --- | --- | --- |
                | Marta Rossi | Segue il cliente | [02:50](iago://seek/170) |
                | Luca Bianchi | UX e UI | [02:50](iago://seek/170) |
                | Paolo Neri | Sviluppo | [02:50](iago://seek/170) |

                ## Tempi e tappe

                | Tappa | Data | Minuto |
                | --- | --- | --- |
                | Rilascio del portale | 15 dicembre | [01:35](iago://seek/95) |

                ## Rischi e dipendenze

                - Integrazione con il gestionale di Poldo. [02:31](iago://seek/151)

                ## Prossimi passi

                | Chi | Cosa | Entro | Minuto |
                | --- | --- | --- | --- |
                | Luca Bianchi | Inviare i wireframe della home | venerdì | [03:08](iago://seek/188) |
                """,
                """
                ## In short

                Poldo's customer portal is under way: orders, invoices and support in one place, on mobile too. Headless architecture (CMS and Next.js), company SSO sign-in, release planned on December 15 with a 60,000 euro budget.

                ## Overview

                A portal where Poldo's customers see orders, invoices and support. [00:14](iago://seek/14)

                ## Technical choices

                - Headless: a CMS for content, a Next.js front end on Poldo's APIs. [00:40](iago://seek/40)
                - Company SSO sign-in. [01:06](iago://seek/66)

                ## People and roles

                | Person | Role | Minute |
                | --- | --- | --- |
                | Marta Rossi | Follows the client | [02:50](iago://seek/170) |
                | Luca Bianchi | UX and UI | [02:50](iago://seek/170) |
                | Paolo Neri | Development | [02:50](iago://seek/170) |

                ## Timeline and milestones

                | Milestone | Date | Minute |
                | --- | --- | --- |
                | Portal release | December 15 | [01:35](iago://seek/95) |

                ## Risks and dependencies

                - Integration with Poldo's ERP. [02:31](iago://seek/151)

                ## Next steps

                | Who | What | By | Minute |
                | --- | --- | --- | --- |
                | Luca Bianchi | Send the home page wireframes | Friday | [03:08](iago://seek/188) |
                """))

        let progress = try call(
            t("SAL settimanale portale", "Weekly portal review"), project: portal.id,
            category: category("SAL", "Progress review"), template: "projectSync", date: day(-2, 11),
            tags: ["ux", "headless"], streams: [uxui.id, development.id],
            turns: [
                (0, "Marta Rossi", t("Facciamo il punto sul portale clienti.", "Let's go over the customer portal.")),
                (
                    18, "Luca Bianchi",
                    t(
                        "Il cliente ha approvato i wireframe di home e area ordini; ora passo alla UI con il design system.",
                        "The client approved the home and orders wireframes; now I move to the UI with the design system."
                    )
                ),
                (
                    52, "Paolo Neri",
                    t(
                        "Il CMS headless è collegato al catalogo e gli ordini arrivano dalle API; mancano le fatture.",
                        "The headless CMS is connected to the catalog and orders come from the APIs; invoices are missing."
                    )
                ),
                (
                    88, "Paolo Neri",
                    t(
                        "Il SSO di Poldo richiede un certificato che arriva tra due settimane.",
                        "Poldo's SSO needs a certificate that arrives in two weeks.")
                ),
                (
                    140, "Marta Rossi",
                    t(
                        "Allora spostiamo il rilascio a fine gennaio, lo comunico io a Poldo.",
                        "Then we move the release to the end of January, I'll tell Poldo.")
                ),
                (
                    175, "Luca Bianchi",
                    t(
                        "Intanto completo il design dell'area assistenza.",
                        "Meanwhile I'll finish the design of the support area.")
                ),
            ],
            summary: t(
                """
                ## In breve

                Wireframe approvati e CMS headless già collegato a catalogo e ordini. Il certificato per il SSO arriva tra due settimane: il rilascio si sposta a fine gennaio.

                ## Avanzamento

                - Approvati i wireframe di home e area ordini; si passa alla UI. [00:18](iago://seek/18)
                - CMS collegato al catalogo, ordini dalle API; mancano le fatture. [00:52](iago://seek/52)

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
                | Marta Rossi | Comunicare il nuovo rilascio a Poldo | — | [02:20](iago://seek/140) |
                | Luca Bianchi | Completare il design dell'area assistenza | — | [02:55](iago://seek/175) |
                """,
                """
                ## In short

                Wireframes approved and the headless CMS already connected to catalog and orders. The SSO certificate arrives in two weeks: the release moves to the end of January.

                ## Progress

                - Home and orders wireframes approved; moving on to the UI. [00:18](iago://seek/18)
                - CMS connected to the catalog, orders from the APIs; invoices missing. [00:52](iago://seek/52)

                ## Risks and countermeasures

                | Risk | Impact | Countermeasure | Who | Minute |
                | --- | --- | --- | --- | --- |
                | SSO certificate late | release | Move the release | Marta Rossi | [01:28](iago://seek/88) |

                ## Decisions

                | Decision | Reason | Minute |
                | --- | --- | --- |
                | Release moved to the end of January | SSO certificate in two weeks | [02:20](iago://seek/140) |

                ## Tasks

                | Who | What | By | Minute |
                | --- | --- | --- | --- |
                | Marta Rossi | Tell Poldo about the new release | — | [02:20](iago://seek/140) |
                | Luca Bianchi | Finish the support area design | — | [02:55](iago://seek/175) |
                """))

        let review = try call(
            t("Review del design system", "Design system review"), project: system.id,
            category: category("Review/Demo"), template: "designReview", date: day(-6, 15),
            tags: ["ui", "accessibilita"],
            turns: [
                (
                    0, "Luca Bianchi",
                    t(
                        "Vi mostro i componenti base: bottoni, campi, card e tabelle, con i token di colore e tipografia.",
                        "Here are the base components: buttons, fields, cards and tables, with color and type tokens.")
                ),
                (
                    35, "Sara Gallo",
                    t(
                        "Il contrasto del grigio sui bottoni secondari non passa il livello AA.",
                        "The gray contrast on secondary buttons does not pass level AA.")
                ),
                (
                    62, "Luca Bianchi",
                    t(
                        "Giusto: scuriamo il grigio e ricontrolliamo tutti i token.",
                        "Right: we darken the gray and check all the tokens again.")
                ),
                (
                    90, "Paolo Neri",
                    t(
                        "I componenti li pubblichiamo come libreria React, così il portale li usa direttamente.",
                        "We publish the components as a React library, so the portal uses them directly.")
                ),
            ])

        let workshop = try call(
            t("Workshop di product discovery", "Product discovery workshop"), project: discovery.id,
            category: category("Workshop"), template: "brainstorming", date: day(-9, 9), tags: ["product", "mvp"],
            turns: [
                (
                    0, "Elena Conti",
                    t(
                        "Atoms vuole un'app per prenotare le sale prova degli studi musicali.",
                        "Atoms wants an app to book rehearsal rooms in music studios.")
                ),
                (
                    30, "Luca Bianchi",
                    t(
                        "Dalle interviste: i musicisti prenotano all'ultimo momento e vogliono vedere subito i prezzi.",
                        "From the interviews: musicians book at the last minute and want to see prices right away.")
                ),
                (
                    64, "Speaker 3",
                    t(
                        "Per l'MVP terrei solo ricerca, prenotazione e pagamento: niente community per ora.",
                        "For the MVP I'd keep only search, booking and payment: no community for now.")
                ),
                (
                    98, "Elena Conti",
                    t(
                        "D'accordo, l'MVP è ricerca, prenotazione e pagamento.",
                        "Agreed, the MVP is search, booking and payment.")
                ),
                (
                    120, "Luca Bianchi",
                    t(
                        "Entro due settimane prepariamo il prototipo cliccabile da testare con otto utenti.",
                        "Within two weeks we prepare a clickable prototype to test with eight users.")
                ),
            ])

        let logo = try call(
            t("Presentazione nuovo logo", "New logo presentation"), project: brand.id,
            category: category("Review/Demo"), template: "designReview", date: day(-5, 15), tags: ["brand"],
            turns: [
                (0, "Anna Verdi", t("Vi mostro le tre proposte di logo.", "Here are the three logo proposals.")),
                (
                    40, "Giorgio Ferri",
                    t(
                        "La seconda è la più leggibile anche in piccolo, sull'app e sui social.",
                        "The second one is the most readable even small, on the app and on social media.")
                ),
                (
                    75, "Anna Verdi",
                    t(
                        "Allora sviluppiamo la seconda e proviamo due palette di colore.",
                        "Then we develop the second one and try two color palettes.")
                ),
            ])

        _ = try call(
            t("1to1 con Marta", "1to1 with Marta"), project: team.id, category: category("1to1"),
            template: "oneOnOne", date: day(-1, 17), tags: [],
            turns: [
                (
                    0, "Marta Rossi",
                    t(
                        "Questo mese il portale di Poldo mi ha preso quasi tutto il tempo.",
                        "This month Poldo's portal took almost all of my time.")
                ),
                (
                    30, "Marta Rossi",
                    t(
                        "Vorrei fare il corso di facilitazione dei workshop a novembre.",
                        "I'd like to take the workshop facilitation course in November.")
                ),
            ])

        // Emails and documents.
        let wireframes = try importEmail(
            EmailInput(
                from: .init(name: "Luca Bianchi", address: "luca.bianchi@agenzia.example"),
                to: [.init(name: "Marta Rossi", address: "marta.rossi@agenzia.example")],
                subject: t("Wireframe home - prima versione", "Home wireframes - first version"), sentAt: day(-13, 17),
                messageID: "<example-wireframe@agenzia.example>",
                bodyMarkdown: t(
                    "Ciao Marta,\n\nin allegato la prima versione dei wireframe della home e dell'area ordini del portale Poldo. Fammi sapere entro mercoledì.\n\nLuca",
                    "Hi Marta,\n\nattached is the first version of the home and orders wireframes for the Poldo portal. Let me know by Wednesday.\n\nLuca"
                ),
                direction: .inbound), original: nil)
        let moodboard = try importEmail(
            EmailInput(
                from: .init(name: "Giorgio Ferri", address: "giorgio.ferri@sanna.example"),
                to: [.init(name: "Anna Verdi", address: "anna.verdi@agenzia.example")],
                subject: t("Moodboard per il rebranding", "Moodboard for the rebranding"), sentAt: day(-8, 10),
                messageID: "<example-moodboard@sanna.example>",
                bodyMarkdown: t(
                    "Ciao Anna,\n\nvi mando la moodboard che ci piace: toni caldi, tipografia geometrica, niente sfumature. Il nuovo marchio deve funzionare prima di tutto sull'app.\n\nGiorgio",
                    "Hi Anna,\n\nhere is the moodboard we like: warm tones, geometric type, no gradients. The new brand must work on the app first of all.\n\nGiorgio"
                ),
                direction: .inbound), original: nil)
        for (item, project) in [(wireframes, portal.id), (moodboard, brand.id)] {
            _ = try updateItem(item.id) {
                $0.projectId = project
                $0.captureMeta = ExampleArchive.marker
            }
        }
        func document(_ title: String, project: String, date: Date, markdown: String) throws -> Item {
            let item = try createItem(
                type: .document, title: title, occurredAt: date, source: .import, status: .ready,
                captureMeta: ExampleArchive.marker)
            _ = try updateItem(item.id) { $0.projectId = project }
            try storeAsset(Data(markdown.utf8), itemID: item.id, kind: .contentMD, fileName: "content.md")
            try indexDocument(markdown, itemID: item.id)
            return item
        }
        _ = try document(
            t("Brief portale headless", "Headless portal brief"), project: portal.id, date: day(-18, 9),
            markdown: t(
                "# Brief portale headless\n\nPoldo vuole un portale in cui i clienti trovino ordini, fatture e assistenza.\n\n- Architettura headless: CMS e front-end Next.js.\n- Accesso con SSO aziendale.\n- Prima versione: home, ordini, fatture.\n- Budget: 60.000 euro.",
                "# Headless portal brief\n\nPoldo wants a portal where customers find orders, invoices and support.\n\n- Headless architecture: CMS and Next.js front end.\n- Company SSO sign-in.\n- First version: home, orders, invoices.\n- Budget: 60,000 euros."
            ))
        _ = try document(
            t("Requisiti MVP Atoms", "Atoms MVP requirements"), project: discovery.id, date: day(-8, 12),
            markdown: t(
                "# Requisiti MVP Atoms\n\n- Ricerca delle sale per zona, data e prezzo.\n- Prenotazione in tre passaggi.\n- Pagamento con carta e Apple Pay.\n- Fuori dall'MVP: community, recensioni, abbonamenti.",
                "# Atoms MVP requirements\n\n- Search rooms by area, date and price.\n- Booking in three steps.\n- Payment by card and Apple Pay.\n- Out of the MVP: community, reviews, subscriptions."
            ))

        // Key points: decisions with their history, milestones and open work.
        let december = try createDecision(
            Decision(
                text: t("Rilascio del portale entro il 15 dicembre", "Portal release by December 15"),
                decidedAt: day(-16, 10), projectId: portal.id, sourceItemId: kickoff.id, sourceAtSec: 95,
                origin: .manual))
        _ = try createDecision(
            Decision(
                text: t("Rilascio spostato a fine gennaio", "Release moved to the end of January"),
                decidedAt: day(-2, 11), projectId: portal.id, sourceItemId: progress.id, sourceAtSec: 140,
                origin: .manual,
                notes: t("Serve il certificato per il SSO aziendale.", "The company SSO certificate is needed.")),
            supersedes: [december.id])
        _ = try createDecision(
            Decision(
                text: t("Architettura headless: CMS e Next.js", "Headless architecture: CMS and Next.js"),
                decidedAt: day(-16, 10), projectId: portal.id, sourceItemId: kickoff.id, sourceAtSec: 40,
                origin: .manual), people: ["Paolo Neri"])
        _ = try createDecision(
            Decision(
                text: t("Accesso con SSO aziendale", "Company SSO sign-in"), decidedAt: day(-16, 10),
                projectId: portal.id, sourceItemId: kickoff.id, sourceAtSec: 66, origin: .manual),
            people: ["Marta Rossi"])
        _ = try createDecision(
            Decision(
                text: t("Kickoff con Poldo", "Kickoff with Poldo"), decidedAt: day(-16, 10), projectId: portal.id,
                sourceItemId: kickoff.id, origin: .manual, kind: .milestone))
        var wireframeTask = Decision(
            text: t("Inviare i wireframe della home", "Send the home page wireframes"), decidedAt: day(-16, 10),
            projectId: portal.id, sourceItemId: kickoff.id, sourceAtSec: 188, origin: .manual, kind: .action)
        wireframeTask.status = .done
        _ = try createDecision(wireframeTask, people: ["Luca Bianchi"])
        var sso = Decision(
            text: t("Configurare l'accesso SSO", "Set up SSO sign-in"), decidedAt: day(-5, 9), projectId: portal.id,
            origin: .manual, kind: .action)
        sso.status = .inProgress
        sso.dueAt = day(6, 18)
        sso.ownerId = try person(named: "Paolo Neri")?.id
        let ssoTask = try createDecision(sso, people: ["Paolo Neri"])
        _ = try createDecision(
            Decision(
                text: t("Quale provider SSO usa Poldo?", "Which SSO provider does Poldo use?"), decidedAt: day(-4, 15),
                projectId: portal.id, origin: .manual, kind: .openQuestion), people: ["Marta Rossi"])
        var late = Decision(
            text: t("I testi definitivi arrivano tardi", "The final copy arrives late"), decidedAt: day(-3, 9),
            projectId: portal.id, origin: .manual, kind: .risk)
        late.severity = .high
        _ = try createDecision(late)
        _ = try createDecision(
            Decision(
                text: t("Aggiungere la pagina FAQ", "Add the FAQ page"), decidedAt: day(-1, 16), projectId: portal.id,
                origin: .manual, kind: .request), people: ["Marta Rossi"])
        _ = try createDecision(
            Decision(
                text: t("Contrasto AA su tutti i componenti", "AA contrast on every component"), decidedAt: day(-6, 15),
                projectId: system.id, sourceItemId: review.id, sourceAtSec: 62, origin: .manual))
        _ = try createDecision(
            Decision(
                text: t(
                    "MVP: ricerca, prenotazione e pagamento", "MVP: search, booking and payment"),
                decidedAt: day(-9, 9), projectId: discovery.id, sourceItemId: workshop.id, sourceAtSec: 98,
                origin: .manual), people: ["Elena Conti"])
        var prototype = Decision(
            text: t("Prototipo cliccabile da testare con otto utenti", "Clickable prototype to test with eight users"),
            decidedAt: day(-9, 9), projectId: discovery.id, sourceItemId: workshop.id, sourceAtSec: 120,
            origin: .manual, kind: .action)
        prototype.dueAt = day(5, 18)
        _ = try createDecision(prototype, people: ["Luca Bianchi"])
        _ = try createDecision(
            Decision(
                text: t("Sviluppare la seconda proposta di logo", "Develop the second logo proposal"),
                decidedAt: day(-5, 15), projectId: brand.id, sourceItemId: logo.id, sourceAtSec: 75, origin: .manual),
            people: ["Anna Verdi"])

        // Proposals still to confirm, those present, a project note.
        try replacePendingSuggestions(
            itemID: progress.id, model: "qwen3.5-9b",
            [
                (
                    .activity,
                    SuggestionPayload(
                        text: t("Mandare a Poldo la stima per le fatture", "Send Poldo the estimate for invoices"),
                        quote: t("mancano le fatture", "invoices are missing"), atSec: 52, owner: "Paolo Neri")
                ),
                (
                    .risk,
                    SuggestionPayload(
                        text: t("Il certificato SSO può slittare ancora", "The SSO certificate may slip again"),
                        quote: t(
                            "richiede un certificato che arriva tra due settimane",
                            "needs a certificate that arrives in two weeks"), atSec: 88, severity: "medium")
                ),
            ])
        try setAttendees(["Marta Rossi", "Luca Bianchi", "Paolo Neri"], itemID: progress.id)
        _ = try addNote(
            itemID: nil, projectID: portal.id,
            body: t(
                "Ricordarsi di chiedere a Poldo i testi definitivi delle pagine prodotto.",
                "Remember to ask Poldo for the final copy of the product pages."), notedAt: day(-3, 9))
        return ExampleArchive.Created(
            mainProjectID: portal.id, firstStreamID: uxui.id, kickoffID: kickoff.id, progressID: progress.id,
            ssoTaskID: ssoTask.id)
    }
}
