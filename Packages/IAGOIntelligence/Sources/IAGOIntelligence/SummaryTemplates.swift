import Foundation
import IAGOCore

/// A summary template in Meetily's JSON format (github.com/Zackriya-Solutions/meeting-minutes, MIT), so templates can
/// be exchanged with it (ADR-0054).
public struct SummaryTemplate: Codable, Sendable, Equatable, Identifiable {
    public struct Section: Codable, Sendable, Equatable {
        public enum Format: String, Codable, Sendable { case paragraph, list, string }

        public var title: String
        public var instruction: String
        public var format: Format
        /// A Markdown table header ("| **Chi** | Cosa | Entro |\n| --- | --- | --- |"): the points become rows.
        public var itemFormat: String?

        enum CodingKeys: String, CodingKey {
            case title, instruction, format
            case itemFormat = "item_format"
        }

        public init(_ title: String, _ instruction: String, _ format: Format = .list, columns: [String]? = nil) {
            self.title = title
            self.instruction = instruction
            self.format = format
            itemFormat = columns.map { columns in
                "| " + columns.map { "**\($0)**" }.joined(separator: " | ") + " |\n|"
                    + String(repeating: " --- |", count: columns.count)
            }
        }

        /// The column names of `itemFormat`, without Markdown.
        public var columns: [String] {
            guard let header = itemFormat?.components(separatedBy: "\n").first else { return [] }
            return header.split(separator: "|").map {
                $0.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
        }
    }

    /// Library id ("oneOnOne"); empty for a template read from a file.
    public var id: String
    public var name: String
    public var description: String
    public var sections: [Section]
    /// Where it comes from, for the credits ("Meetily", "Hyprnote").
    public var basedOn: String

    enum CodingKeys: String, CodingKey { case name, description, sections }

    public init(id: String, name: String, description: String, basedOn: String, sections: [Section]) {
        self.id = id
        self.name = name
        self.description = description
        self.basedOn = basedOn
        self.sections = sections
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = ""
        basedOn = ""
        name = try container.decode(String.self, forKey: .name)
        description = (try? container.decode(String.self, forKey: .description)) ?? ""
        sections = try container.decode([Section].self, forKey: .sections)
    }

    /// Meetily's JSON, for export and for the user's own version of a template.
    public func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    public static func parse(_ json: String) -> SummaryTemplate? {
        guard let template = try? JSONDecoder().decode(SummaryTemplate.self, from: Data(json.utf8)),
            !template.sections.isEmpty
        else { return nil }
        return template
    }
}

/// The templates of Meetily and Hyprnote (github.com/fastrepl/hyprnote, MIT), translated and adapted; duplicates
/// merged, the clinical one left out (ADR-0054). Credits in docs/licenses.md.
public enum SummaryLibrary {
    public static func template(_ id: String?) -> SummaryTemplate? {
        all.first { $0.id == id }
    }

    typealias S = SummaryTemplate.Section

    static let nextSteps = S(
        "Prossimi passi", "Cosa si farà dopo la riunione e chi lo fa.", columns: ["Chi", "Cosa", "Entro"])

    /// The library in the language of the app (ADR-0077): same ids in Italian and English.
    public static var all: [SummaryTemplate] { ContentLanguage.current == .en ? englishLibrary : italianLibrary }

    public static let italianLibrary: [SummaryTemplate] = [
        .init(
            id: "standard", name: "Riunione standard",
            description: "Per riunioni generiche: esiti, decisioni e attività.", basedOn: "Meetily",
            // Meetily's "Summary" is IAGO's "In breve", on top of every summary.
            sections: [
                S("Decisioni", "Le decisioni prese durante la riunione."),
                S("Attività", "I compiti assegnati, con chi li fa e per quando.", columns: ["Chi", "Cosa", "Entro"]),
                S("Punti salienti", "I temi principali, gli argomenti e le osservazioni importanti."),
            ]),
        .init(
            id: "oneOnOne", name: "1:1", description: "Incontri individuali con una persona del team.",
            basedOn: "Hyprnote",
            sections: [
                S("Aggiornamenti", "Cosa è successo dall'ultima volta."),
                S("Successi e difficoltà", "Risultati da riconoscere e ostacoli incontrati."),
                S("Obiettivi e avanzamento", "Gli obiettivi in corso e a che punto sono."),
                S("Feedback", "Feedback dato e ricevuto, nei due sensi."),
                S("Impegni", "Cosa si impegna a fare ciascuno.", columns: ["Chi", "Cosa", "Entro"]),
            ]),
        .init(
            id: "kickoff", name: "Kickoff",
            description: "Avvio di un progetto o di un incarico con un cliente: obiettivi e allineamento.",
            basedOn: "Hyprnote",
            sections: [
                S("Panoramica", "Perimetro, obiettivi e consegne del progetto.", .paragraph),
                S("Criteri di successo", "Come si capirà che il progetto è riuscito."),
                S(
                    "Persone e ruoli", "Chi partecipa e con quale ruolo o responsabilità.",
                    columns: ["Persona", "Ruolo"]),
                S("Tempi e tappe", "Le date e le tappe principali.", columns: ["Tappa", "Data"]),
                S("Rischi e dipendenze", "Rischi, vincoli e cose da cui il progetto dipende."),
                S("Come ci si aggiorna", "Frequenza delle riunioni e modo di comunicare."),
                nextSteps,
            ]),
        .init(
            id: "projectSync", name: "Stato avanzamento (SAL)",
            description: "Riunioni periodiche sullo stato del progetto: tappe, rischi, decisioni.", basedOn: "Meetily",
            sections: [
                S("Avanzamento", "Cosa è stato fatto dall'ultimo aggiornamento.", .paragraph),
                S(
                    "Tappe e stato", "Le tappe con il loro stato e la data prevista.",
                    columns: ["Tappa", "Stato", "Previsione"]),
                S(
                    "Rischi e contromisure", "I rischi principali, l'impatto, cosa si fa e chi se ne occupa.",
                    columns: ["Rischio", "Impatto", "Contromisura", "Chi"]),
                S("Decisioni", "Le decisioni prese e il motivo.", columns: ["Decisione", "Motivo"]),
                S("Attività", "I compiti, con chi li fa e per quando.", columns: ["Chi", "Cosa", "Entro"]),
                S("Documenti citati", "Documenti, file o materiali nominati durante la riunione."),
            ]),
        .init(
            id: "brainstorming", name: "Workshop / brainstorming",
            description: "Sessioni creative e di ideazione.", basedOn: "Hyprnote",
            sections: [
                S("Obiettivo della sessione", "Quale problema o opportunità si esplora.", .paragraph),
                S("Idee emerse", "Tutte le idee proposte, raggruppate per tema."),
                S("Idee più promettenti", "Le idee che vale la pena approfondire."),
                S("Criteri per valutarle", "Come si è deciso di valutare le idee."),
                nextSteps,
            ]),
        .init(
            id: "designReview", name: "Review / demo",
            description: "Presentazione di un lavoro (design, prototipo, soluzione) e raccolta dei feedback.",
            basedOn: "Hyprnote",
            sections: [
                S("Cosa è stato presentato", "Il lavoro mostrato e la soluzione proposta.", .paragraph),
                S("Alternative considerate", "Altre strade valutate e perché sono state scartate."),
                S("Feedback", "I commenti ricevuti, punto per punto.", columns: ["Punto", "Feedback", "Chi"]),
                S("Modifiche richieste", "Cosa va cambiato."),
                S("Approvato e da rivedere", "Cosa è approvato e cosa resta aperto."),
                nextSteps,
            ]),
        .init(
            id: "clientSales", name: "Client / Sales",
            description: "Incontri commerciali con clienti o potenziali clienti.",
            basedOn: "Meetily, Hyprnote",
            sections: [
                S("Contesto del cliente", "Chi è il cliente e la sua situazione.", .paragraph),
                S("Situazione attuale e problemi", "Come lavora oggi e quali problemi vuole risolvere."),
                S("Obiettivi e criteri di successo", "Cosa vuole ottenere e come misurerà il risultato."),
                S(
                    "Consegne concordate", "Cosa è stato concordato di consegnare.",
                    columns: ["Consegna", "Chi", "Entro"]),
                S("Budget, tempi e condizioni", "Prezzi, tempi, condizioni contrattuali o di pagamento citati."),
                S("Obiezioni e dubbi", "Le preoccupazioni o le obiezioni del cliente."),
                S("Concorrenti citati", "Altri fornitori o soluzioni nominati."),
                nextSteps,
            ]),
        .init(
            id: "customerDiscovery", name: "Customer discovery",
            description: "Interviste a clienti o utenti per capire bisogni e problemi.", basedOn: "Hyprnote",
            sections: [
                S("Contesto", "Chi è l'intervistato e il suo contesto.", .paragraph),
                S("Come fa oggi", "Come risolve oggi il problema."),
                S("Problemi", "Difficoltà e frustrazioni raccontate."),
                S("Bisogni e obiettivi", "Cosa vorrebbe ottenere."),
                S("Reazioni alla proposta", "Come ha reagito alle soluzioni proposte, se ce ne sono state."),
                S("Cose imparate", "Le scoperte principali dell'intervista."),
            ]),
        .init(
            id: "sprintPlanning", name: "Sprint planning",
            description: "Pianificazione di uno sprint e dei suoi obiettivi.", basedOn: "Hyprnote",
            sections: [
                S("Obiettivo dello sprint", "L'obiettivo principale dello sprint.", .paragraph),
                S("Lavori presi in carico", "Storie e compiti dello sprint.", columns: ["Lavoro", "Chi"]),
                S("Disponibilità", "Disponibilità e capacità del team."),
                S("Dipendenze e rischi", "Dipendenze esterne e rischi."),
                S("Quando è \"fatto\"", "I criteri per considerare finito il lavoro."),
            ]),
        .init(
            id: "dailyStandup", name: "Daily standup", description: "Aggiornamento quotidiano breve del team.",
            basedOn: "Meetily, Hyprnote",
            sections: [
                S("Fatto ieri", "Cosa ha completato ciascuno.", columns: ["Chi", "Fatto"]),
                S("Piano di oggi", "Su cosa lavora oggi ciascuno.", columns: ["Chi", "Oggi"]),
                S("Blocchi", "Ostacoli e chi può aiutare.", columns: ["Chi", "Blocco"]),
                S("Comunicazioni", "Annunci o informazioni per tutti."),
            ]),
        .init(
            id: "retrospective", name: "Retrospective",
            description: "Fine sprint, fase o progetto: cosa ha funzionato e cosa cambiare.",
            basedOn: "Meetily, Hyprnote",
            sections: [
                S("Cosa è andato bene", "Successi e cose da continuare a fare."),
                S("Cosa non è andato bene", "Problemi e cose da smettere di fare."),
                S(
                    "Cosa iniziare a fare", "Nuove pratiche o esperimenti proposti.",
                    columns: ["Idea", "Chi la propone"]),
                S("Cosa abbiamo imparato", "Le lezioni principali."),
                S("Azioni", "Le azioni concrete, con chi le fa.", columns: ["Chi", "Azione", "Entro"]),
            ]),
        .init(
            id: "boardMeeting", name: "Board meeting", description: "Consigli e riunioni di governo dell'azienda.",
            basedOn: "Hyprnote",
            sections: [
                S("Andamento", "Aggiornamenti su risultati e operatività.", .paragraph),
                S("Iniziative strategiche", "A che punto sono le priorità strategiche."),
                S("Conti", "Budget, cassa e salute finanziaria."),
                S("Delibere", "Le decisioni e le delibere prese."),
                S("Rischi e conformità", "Rischi e adempimenti."),
                nextSteps,
            ]),
        .init(
            id: "executiveBriefing", name: "Executive briefing",
            description: "Discussioni strategiche di direzione.", basedOn: "Hyprnote",
            sections: [
                S("Quadro strategico", "Contesto e obiettivi.", .paragraph),
                S("Numeri chiave", "Indicatori e andamenti citati."),
                S("Decisioni", "Decisioni strategiche e motivi."),
                S("Risorse", "Budget e persone assegnati."),
                S("Rischi e opportunità", "Rischi strategici e opportunità di crescita."),
                S("Azioni", "Le azioni decise, con chi le segue.", columns: ["Chi", "Azione"]),
            ]),
        .init(
            id: "investorPitch", name: "Investor pitch", description: "Presentazioni a investitori.",
            basedOn: "Hyprnote",
            sections: [
                S("Contesto", "Chi è l'investitore e lo scopo dell'incontro.", .paragraph),
                S("Cosa è stato presentato", "I punti principali della presentazione."),
                S("Domande", "Le domande e i dubbi dell'investitore."),
                S("Feedback", "Reazioni e commenti."),
                S("Interesse", "Livello di interesse e prossimi passi indicati."),
                S("Cose da mandare", "Informazioni richieste e azioni.", columns: ["Cosa", "Entro"]),
            ]),
        .init(
            id: "performanceReview", name: "Performance review",
            description: "Valutazioni e colloqui di crescita.", basedOn: "Hyprnote",
            sections: [
                S("Periodo", "Il periodo valutato, in breve.", .paragraph),
                S("Risultati", "I risultati e i contributi principali."),
                S("Punti di forza", "Capacità e comportamenti da mantenere."),
                S("Aree di crescita", "Dove migliorare."),
                S("Obiettivi di carriera", "Aspirazioni e percorso."),
                S("Piano", "Obiettivi di sviluppo e prossimi passi.", columns: ["Obiettivo", "Entro"]),
            ]),
        .init(
            id: "incidentPostmortem", name: "Incident postmortem",
            description: "Analisi senza colpe di un incidente o di un disservizio.", basedOn: "Hyprnote",
            sections: [
                S("Cosa è successo", "L'incidente e quando.", .paragraph),
                S("Cronologia", "La sequenza degli eventi.", columns: ["Quando", "Evento"]),
                S("Causa", "Cosa ha causato l'incidente."),
                S("Impatto", "Effetti su utenti e attività."),
                S("Risoluzione", "Come è stato risolto."),
                S("Lezioni", "Cosa si è imparato."),
                S("Azioni preventive", "Cosa si fa per evitarlo.", columns: ["Chi", "Azione", "Entro"]),
            ]),
        .init(
            id: "roadmapReview", name: "Revisione della roadmap",
            description: "Priorità di prodotto e roadmap.", basedOn: "Hyprnote",
            sections: [
                S("Stato attuale", "A che punto sono le iniziative in corso.", .paragraph),
                S("Prossime funzioni", "Priorità e tempi del prossimo periodo."),
                S("Feedback dei clienti", "Cosa dicono utenti e clienti."),
                S("Metriche", "Indicatori e modo di misurare."),
                S("Decisioni", "Decisioni e compromessi."),
            ]),
        .init(
            id: "lectureNotes", name: "Formazione", description: "Corsi, lezioni e webinar.", basedOn: "Hyprnote",
            sections: [
                S("Argomento", "Corso, tema e relatore.", .string),
                S("Concetti chiave", "Le idee principali spiegate."),
                S("Definizioni", "Termini da ricordare."),
                S("Esempi", "Esempi e applicazioni pratiche."),
                S("Dubbi da chiarire", "Domande rimaste aperte."),
            ]),
    ]
}
