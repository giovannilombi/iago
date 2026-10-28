import Foundation
import IAGOCore
import IAGOStore
import Testing

@testable import IAGOIntelligence

/// ADR-0074: points to clear up, risks, requests and activities with owner, deadline and "waiting on", from the same
/// single extraction pass, with the mistakes small models make.
@Suite struct OpenWorkProposalTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }
    /// Wednesday 28 October 2026, 10:00.
    static let wednesday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 10))!

    let lines: [KeyPointExtractor.Line] = [
        .init(atSec: 30, speaker: "Io", text: "Allora per il login usiamo Azure AD, è deciso."),
        .init(atSec: 60, speaker: "Anna", text: "Perfetto. Vi mando i file definitivi entro venerdì."),
        .init(atSec: 90, speaker: "Anna", text: "Ci servirebbe anche l'esportazione in Excel dei report."),
        .init(
            atSec: 120, speaker: "Io",
            text: "Se il fornitore dei server ritarda, rischiamo di saltare la consegna di dicembre."),
        .init(
            atSec: 150, speaker: "Anna", text: "E chi gestisce gli accessi degli utenti esterni? Ci dobbiamo pensare."),
        .init(atSec: 180, speaker: "Io", text: "Preparo il preventivo per l'esportazione entro il 10 novembre."),
    ]

    let open: [KeyPointExtractor.OpenEntry] = [
        .init(id: "q1", kind: .question, text: "Quale provider usiamo per il login SSO?"),
        .init(id: "r1", kind: .request, text: "Esportazione dei report in Excel"),
    ]

    /// Reasoning with braces, a code fence, trailing commas, numbers as text, a date the model counted wrong,
    /// accented keys, a question that is already open, an activity that claims to answer a question.
    static let messyAnswer = """
        <think>Devo trovare decisioni {e attività}.</think>
        ```json
        {"decisioni": [
          {"testo": "Login con Azure AD", "citazione": "per il login usiamo Azure AD, è deciso", "sicurezza": "alta", "chiude": "1"},
        ],
         "attività": [
          {"testo": "Mandare i file definitivi", "chi": "Anna", "attende": "Anna", "entro": "2026-11-06", "citazione": "Vi mando i file definitivi entro venerdì", "sicurezza": "alta", "chiude": null},
          {"testo": "Preparare il preventivo per l'esportazione", "chi": "Io", "attende": "null", "entro": "entro il 10 novembre", "citazione": "Preparo il preventivo per l'esportazione entro il 10 novembre", "sicurezza": "alta", "chiude": "[2]"},
          {"testo": "Consegna di dicembre", "chi": null, "entro": "dicembre", "citazione": "Preparo la consegna di dicembre", "sicurezza": "alta"}
        ],
         "domande": [
          {"testo": "Chi gestisce gli accessi degli utenti esterni?", "citazione": "chi gestisce gli accessi degli utenti esterni?", "sicurezza": "media"},
          {"testo": "Quale provider per il login?", "citazione": "per il login usiamo Azure AD", "sicurezza": "alta"},
        ],
         "rischi": [
          {"testo": "Ritardo del fornitore dei server", "gravità": "Alta", "citazione": "Se il fornitore dei server ritarda, rischiamo di saltare la consegna di dicembre", "sicurezza": "alta"}
        ],
         "richieste": [
          {"testo": "Esportazione in Excel dei report", "citazione": "Ci servirebbe anche l'esportazione in Excel dei report", "sicurezza": "alta"},
          {"testo": "Login con SSO", "citazione": "ci servirebbe il login con SSO per tutti", "sicurezza": "alta"}
        ]}
        ```
        """

    @Test func extractsEveryKindInOnePassAndChecksWhatTheModelSays() async throws {
        let engine = FakeEngine { _ in Self.messyAnswer }
        let result = try await KeyPointExtractor.extract(
            lines, context: .init(date: Self.wednesday, openEntries: open, calendar: Self.calendar), with: engine)
        // One block, one request: the new kinds do not add passes.
        #expect(engine.requests.count == 1)
        #expect(engine.requests[0].prompt.hasPrefix("VOCI APERTE DEL PROGETTO"))
        #expect(engine.requests[0].prompt.contains("[1] Domanda: Quale provider usiamo per il login SSO?"))
        #expect(engine.requests[0].prompt.contains("[2] Richiesta: Esportazione dei report in Excel"))
        #expect(engine.requests[0].system.contains("RICHIESTA") && engine.requests[0].system.contains("\"gravita\""))
        let byText = Dictionary(uniqueKeysWithValues: result.items.map { ($0.text, $0) })
        #expect(result.items.map(\.kind) == [.decision, .activity, .activity, .question, .risk])
        // The decision answers the open question.
        #expect(byText["Login con Azure AD"]?.closesID == "q1")
        // Anna promised the files: we wait for her, until Friday 30 (not the 6 November the model counted).
        let files = try #require(byText["Mandare i file definitivi"])
        #expect(files.waitingOn == "Anna" && files.owner == nil && files.due == "2026-10-30" && files.atSec == 60)
        // The estimate accepts the open request; its deadline is said in full.
        let estimate = try #require(byText["Preparare il preventivo per l'esportazione"])
        #expect(estimate.owner == "Io" && estimate.waitingOn == nil && estimate.due == "2026-11-10")
        #expect(estimate.closesID == "r1")
        #expect(byText["Ritardo del fornitore dei server"]?.severity == "high")
        #expect(byText["Chi gestisce gli accessi degli utenti esterni?"]?.atSec == 150)
        let reasons = Dictionary(result.discarded.map { ($0.item, $0.reason) }, uniquingKeysWith: { a, _ in a })
        #expect(reasons["Consegna di dicembre"] == "citazione non trovata nella trascrizione")
        #expect(reasons["Quale provider per il login?"] == "già aperta nel progetto")
        #expect(reasons["Esportazione in Excel dei report"] == "già aperta nel progetto")
        #expect(reasons["Login con SSO"] == "citazione non trovata nella trascrizione")
    }

    @Test func closingNeedsAValidNumberAKindThatClosesAndTheSameTopic() {
        func point(_ kind: ProposedKeyPoint.Kind, _ text: String) -> ProposedKeyPoint {
            ProposedKeyPoint(kind: kind, text: text, quote: text, atSec: 0, owner: nil, confidence: .high)
        }
        let decision = point(.decision, "Usiamo Azure AD per il login")
        #expect(KeyPointExtractor.closing(decision, number: 1, in: open) == "q1")
        #expect(KeyPointExtractor.closing(decision, number: 0, in: open) == nil)
        #expect(KeyPointExtractor.closing(decision, number: 7, in: open) == nil)
        // Another topic: the number is a guess.
        #expect(KeyPointExtractor.closing(point(.decision, "Riunione ogni lunedì"), number: 1, in: open) == nil)
        // A question or a risk closes nothing; an activity accepts a request but does not answer a question.
        #expect(KeyPointExtractor.closing(point(.question, "Il login con Azure AD?"), number: 1, in: open) == nil)
        #expect(KeyPointExtractor.closing(point(.activity, "Configurare il login"), number: 1, in: open) == nil)
        #expect(KeyPointExtractor.closing(point(.activity, "Stimare l'export Excel"), number: 2, in: open) == "r1")
    }

    @Test func cutAnswersAndNoDateKeepWhatIsComplete() async throws {
        // The model ran out of room in the middle of the second item.
        let cut =
            #"{"decisioni": [], "rischi": [{"testo": "Ritardo del fornitore", "citazione": "Se il fornitore dei server ritarda", "sicurezza": "media"}, {"testo": "Budget"#
        let candidates = KeyPointExtractor.parse(cut)
        #expect(candidates.map(\.point.text) == ["Ritardo del fornitore"])
        // Severity missing: medium.
        #expect(candidates.first?.point.severity == "medium")
        // Without the item's date no deadline is counted.
        let engine = FakeEngine { _ in
            #"{"attivita": [{"testo": "Preventivo", "chi": "Io", "entro": "entro il 10 novembre", "citazione": "Preparo il preventivo per l'esportazione entro il 10 novembre", "sicurezza": "alta"}]}"#
        }
        let result = try await KeyPointExtractor.extract(lines, with: engine)
        #expect(result.items.first?.due == nil && result.items.first?.owner == "Io")
        #expect(!engine.requests[0].prompt.contains("VOCI APERTE"))
    }

    @Test func relativeDeadlinesCountFromTheItemsDate() {
        func resolve(_ text: String) -> String? {
            DueDates.resolve(text, from: Self.wednesday, calendar: Self.calendar)
        }
        #expect(resolve("venerdì") == "2026-10-30")
        #expect(resolve("entro venerdi prossimo") == "2026-10-30")
        #expect(resolve("mercoledì") == "2026-11-04")
        #expect(resolve("lunedì") == "2026-11-02")
        #expect(resolve("venerdì della prossima settimana") == "2026-11-06")
        #expect(resolve("la settimana prossima") == "2026-11-06")
        #expect(resolve("oggi") == "2026-10-28")
        #expect(resolve("domani mattina") == "2026-10-29")
        #expect(resolve("dopodomani") == "2026-10-30")
        #expect(resolve("fra 3 giorni") == "2026-10-31")
        #expect(resolve("tra due settimane") == "2026-11-11")
        #expect(resolve("entro il 10 novembre") == "2026-11-10")
        #expect(resolve("il 5 gennaio") == "2027-01-05")
        #expect(resolve("6/11") == "2026-11-06")
        #expect(resolve("2026-12-01") == "2026-12-01")
        #expect(resolve("fine mese") == "2026-10-31")
        #expect(resolve("entro fine novembre") == "2026-11-30")
        #expect(resolve("fine settimana") == "2026-10-30")
        #expect(resolve("entro fine anno") == "2026-12-31")
        // Not deadlines: a time, an amount, a vague word, an impossible day.
        #expect(resolve("alle 9.30") == nil)
        #expect(resolve("12.000 euro") == nil)
        #expect(resolve("presto") == nil)
        #expect(resolve("31/02") == nil)
    }

    @Test func proposalsCarryTheNewFieldsAndAnswerOpenQuestions() async throws {
        let archive = try memoryArchive()
        let project = try archive.createProject(name: "Portale")
        let question = try archive.createDecision(
            Decision(
                text: "Quale provider usiamo per il login SSO?", decidedAt: Self.wednesday.addingTimeInterval(-86_400),
                projectId: project.id, origin: .manual, kind: .openQuestion))
        _ = try archive.createDecision(
            Decision(
                text: "Riunione ogni lunedì", decidedAt: Self.wednesday, projectId: project.id, origin: .manual))
        let call = try archive.createItem(
            title: "Call di prova", occurredAt: Self.wednesday, source: .recording, status: .transcribed)
        try archive.updateItem(call.id) { $0.projectId = project.id }
        let engine = FakeEngine { prompt in
            if prompt.contains("TAG ESISTENTI") { return #"{"esistenti": [], "nuovi": []}"# }
            return Self.messyAnswer
        }
        let proposals = try await SuggestionEngine.propose(
            .init(
                itemID: call.id, projectID: project.id, lines: lines, isCall: true, speakers: [:],
                date: Self.wednesday),
            engine: engine, embedder: nil, archive: archive)
        #expect(engine.requests.filter { $0.system == KeyPointExtractor.system }.count == 1)
        #expect(engine.requests[0].prompt.contains("[1] Domanda: Quale provider usiamo per il login SSO?"))
        let kinds = proposals.map(\.kind)
        #expect(kinds.contains(.question) && kinds.contains(.risk) && kinds.contains(.activity))
        let decision = try #require(proposals.first { $0.kind == .decision })
        #expect(decision.payload.supersedesID == question.id)
        let files = try #require(proposals.first { $0.payload.text == "Mandare i file definitivi" })
        #expect(files.payload.waitingOn == "Anna" && files.payload.due != nil && files.payload.dueDate != nil)
        #expect(proposals.first { $0.kind == .risk }?.payload.severity == "high")
    }
}
