import Foundation
import IAGOCore
import Testing

@testable import IAGOIntelligence

@Suite struct SummaryGeneratorTests {
    let lines = [
        KeyPointExtractor.Line(
            atSec: 12, speaker: "Mario", text: "Abbiamo chiuso la grafica della home la settimana scorsa."),
        KeyPointExtractor.Line(
            atSec: 75, speaker: "Anna", text: "Il rilascio slitta al 15 novembre per il ritardo dei testi."),
        KeyPointExtractor.Line(
            atSec: 130, speaker: "Mario", text: "Mi occupo io di mandare i testi a Luca entro venerdì."),
    ]

    var template: SummaryTemplate { SummaryLibrary.template("projectSync")! }

    @Test func verifiedPointsGoInTheirSectionsWithTheirMinute() async throws {
        let engine = FakeEngine { prompt in
            if prompt.contains("Avanzamento:") || prompt.contains("Attività:") {
                // "In breve": one sentence with an invented number is dropped.
                return "Il progetto avanza con la home chiusa. Il budget sale a 40.000 euro."
            }
            return """
                {"sezioni": [
                  {"titolo": "Avanzamento", "punti": [{"testo": "Chiusa la grafica della home",
                    "citazione": "abbiamo chiuso la grafica della home la settimana scorsa"},
                    {"testo": "Il progetto è in ritardo sui testi", "citazione": "riassunto"},
                    {"testo": "Speso il 40% del budget", "citazione": "riassunto"},
                    {"testo": "abbiamo chiuso la grafica", "citazione": "Abbiamo chiuso la grafica della home"}]},
                  {"titolo": "Tappe e stato", "punti": [{"testo": "Rilascio spostato al 15 novembre",
                    "citazione": "Il rilascio slitta al 15 novembre", "campi": {"Tappa": "Rilascio", "Stato": "in ritardo"}},
                    {"testo": "Rilascio al 20 novembre", "citazione": "Il rilascio slitta al 20 novembre"}]},
                  {"titolo": "Attività", "punti": [{"testo": "Mandare i testi a Luca", "citazione":
                    "mi occupo io di mandare i testi a Luca entro venerdì", "campi": {"Chi": "Mario", "Entro": "venerdì", "Cosa": "non specificato"}}]},
                  {"titolo": "Sezione inventata", "punti": [{"testo": "x", "citazione": "Abbiamo chiuso la grafica"}]}
                ]}
                """
        }
        let result = try await SummaryGenerator.generate(
            .init(lines: lines, template: template, date: nil, participants: ["Mario", "Anna"], title: "SAL"),
            with: engine)
        let byTitle = Dictionary(uniqueKeysWithValues: result.sections.map { ($0.title, $0.points) })
        #expect(byTitle["Avanzamento"]?.first?.atSec == 12)
        // An overview without a quote stays (no minute), unless it has a number nobody said.
        #expect(
            byTitle["Avanzamento"]?.map(\.text) == [
                "Chiusa la grafica della home", "Il progetto è in ritardo sui testi",
            ])
        #expect(byTitle["Avanzamento"]?.last?.atSec == nil)
        // The invented date (20 novembre) is not in the transcript: dropped.
        #expect(byTitle["Tappe e stato"]?.map(\.text) == ["Rilascio spostato al 15 novembre"])
        #expect(result.discarded.contains { $0.point == "Rilascio al 20 novembre" })
        #expect(byTitle["Attività"]?.first?.fields["Chi"] == "Mario")
        #expect(
            SummaryGenerator.withoutOwner("Mario deve mandare i testi", fields: ["Chi": "Mario"]) == "Mandare i testi")
        #expect(result.discarded.contains { $0.reason == "frase copiata dal parlato, non riassunta" })
        #expect(result.markdown.contains("| Mario | Mandare i testi a Luca | venerdì | [02:10](iago://seek/130) |"))
        #expect(result.markdown.contains("## Rischi e contromisure\n\n_Non emerso_"))
        #expect(result.markdown.contains("**Partecipanti:** Mario, Anna"))
        #expect(result.markdown.contains("Il progetto avanza con la home chiusa."))
        #expect(!result.markdown.contains("40.000"))
    }

    @Test func cutAnswersKeepTheirCompletePointsAndCopiesAreDropped() {
        let cut =
            #"{"sezioni":[{"titolo":"Decisioni","punti":[{"testo":"Scelto il codice 22","citazione":"mettiamo la 22"},{"testo":"Profi"#
        let object = SummaryGenerator.jsonObject(cut)
        let sections = object?["sezioni"] as? [[String: Any]]
        #expect((sections?.first?["punti"] as? [[String: Any]])?.count == 1)
        // A bracket closed in the wrong place (as Gemma did): the following sections are still read.
        let broken =
            #"{"sezioni":[{"titolo":"Decisioni","punti":[{"testo":"Scelto il 22","citazione":"la 22"}]}]},{"titolo":"Attività","punti":[{"testo":"Mandare il modulo","citazione":"mando il modulo"}]}]}"#
        let parsed = SummaryGenerator.sectionObjects(broken)
        #expect(parsed.compactMap { $0["titolo"] as? String } == ["Decisioni", "Attività"])
        // Stray quotes and commas (as Gemma wrote): points are still read, with their fields.
        let messy =
            #"{"sezioni":[{"titolo":"Attività","punti":[{"testo":"Preparare la presentazione","citazione":"ci chiede di preparare una presentazione",","campi":{"Chi":"Anna","Cosa":"presentazione"}}]},{"titolo":"Punti salienti","punti":[{"testo":"Il cliente ha problemi di design","citazione":"hanno un problema di operations","},{"testo":"Rossi Srl come caso","citazione":"partito da Rossi Srl","}]}]}"#
        let lenient = SummaryGenerator.lenientSections(messy)
        #expect(lenient.map { ($0["punti"] as? [[String: Any]])?.count ?? 0 } == [1, 2])
        #expect(((lenient.first?["punti"] as? [[String: Any]])?.first?["campi"] as? [String: String])?["Chi"] == "Anna")
        #expect(SummaryGenerator.parse(messy, template: SummaryLibrary.template("standard")!).count == 2)
        #expect(SummaryGenerator.isCopy("Mettiamo la 22 così, va bene", of: "mettiamo la 22 così va bene"))
        #expect(!SummaryGenerator.isCopy("Scelto il codice attività 22", of: "mettiamo la 22 così"))
    }

    @Test func templatesRoundTripInMeetilysFormat() throws {
        let json = template.json()
        #expect(json.contains("\"item_format\""))
        let parsed = try #require(SummaryTemplate.parse(json))
        #expect(parsed.sections == template.sections)
        #expect(Set(SummaryLibrary.all.map(\.id)).count == SummaryLibrary.all.count)
    }
}
