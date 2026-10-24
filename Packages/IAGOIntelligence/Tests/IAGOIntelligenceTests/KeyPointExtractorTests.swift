import Foundation
import IAGOCore
import Testing

@testable import IAGOIntelligence

@Suite struct KeyPointExtractorTests {
    let lines: [KeyPointExtractor.Line] = [
        .init(atSec: 24, speaker: "Speaker 2", text: "Allora, Alessandro è un dipendente, un nuovo ingresso."),
        .init(
            atSec: 121, speaker: "Speaker 1",
            text: "Va bene, facciamo il contributo dell'azienda al 2% e il lavoratore all'1,2%."),
        .init(atSec: 434, speaker: "Speaker 3", text: "Io scelgo il profilo prudente, per ora."),
        .init(atSec: 700, speaker: "Speaker 2", text: "Ti mando il modulo compilato domani mattina."),
    ]

    @Test func keepsOnlyQuotedSureAndDistinctItems() async throws {
        let engine = FakeEngine { prompt in
            if prompt.contains("[11:40]") {
                return
                    #"{"decisioni": [], "attivita": [{"testo": "Inviare il modulo", "chi": "Speaker 2", "citazione": "ti mando il modulo compilato domani mattina", "sicurezza": "alta"}]}"#
            }
            return """
                Ecco il JSON:
                ```json
                {"decisioni": [
                  {"testo": "Contributo azienda 2%, lavoratore 1,2%", "citazione": "facciamo il contributo dell'azienda al 2% e il lavoratore all'1,2%", "sicurezza": "alta"},
                  {"testo": "Contributo azienda 1,55%", "citazione": "facciamo il contributo dell'azienda al 1,55%", "sicurezza": "alta"},
                  {"testo": "Profilo prudente", "citazione": "scelgo il profilo prudente, per ora", "sicurezza": "media"},
                  {"testo": "Inventata", "citazione": "parliamo di qualcosa che nessuno ha detto mai", "sicurezza": "alta"},
                  {"testo": "Alessandro è dipendente", "citazione": "Alessandro è un dipendente, un nuovo ingresso", "sicurezza": "bassa"},
                  {"testo": "Contributo dell'azienda al 2% e del lavoratore all'1,2%", "citazione": "Va bene, facciamo il contributo dell'azienda al 2%", "sicurezza": "alta"}
                ], "attivita": []}
                ```
                """
        }
        let result = try await KeyPointExtractor.extract(lines, with: engine)
        // Two blocks: the first 10 minutes, then the rest.
        #expect(engine.requests.count == 2)
        #expect(
            result.items.map(\.text) == [
                "Contributo azienda 2%, lavoratore 1,2%", "Profilo prudente", "Inviare il modulo",
            ])
        #expect(result.items.map(\.atSec) == [121, 434, 700])
        #expect(result.items.last?.owner == "Speaker 2" && result.items.last?.kind == .activity)
        let reasons = Dictionary(uniqueKeysWithValues: result.discarded.map { ($0.item, $0.reason) })
        #expect(reasons["Contributo azienda 1,55%"] == "citazione non trovata nella trascrizione")  // invented number
        #expect(reasons["Inventata"] == "citazione non trovata nella trascrizione")
        #expect(reasons["Alessandro è dipendente"] == "sicurezza bassa")
        #expect(reasons["Contributo dell'azienda al 2% e del lavoratore all'1,2%"] == "doppione")
        #expect(engine.requests[0].system.contains("NON sono decisioni"))
    }

    @Test func unreadableAnswersGiveNothing() async throws {
        let result = try await KeyPointExtractor.extract(lines, with: FakeEngine { _ in "Non saprei." })
        #expect(result.items.isEmpty)
    }
}
