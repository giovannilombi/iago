import Foundation
import IAGOCore
import Testing

@testable import IAGOIntelligence

/// Answers with a canned transformation and records what it was asked.
final class FakeEngine: LLMProvider, @unchecked Sendable {
    let modelID = "fake"
    let modelName = "Fake"
    var requests: [LLMRequest] = []
    let answer: @Sendable (String) -> String

    init(answer: @escaping @Sendable (String) -> String) { self.answer = answer }

    func generate(_ request: LLMRequest) async throws -> String {
        requests.append(request)
        return answer(request.prompt)
    }
}

@Suite struct TextTidierTests {
    @Test func cleansTheAnswerAndKeepsOnlyTheText() async throws {
        let engine = FakeEngine { prompt in
            "<think>devo togliere gli intercalari</think>\nEcco il testo riordinato:\n"
                + prompt.replacingOccurrences(
                    of: "ehm, ", with: "")
        }
        let tidy = try await TextTidier.tidy("ehm, il budget è di 12.000 euro", with: engine)
        #expect(tidy == "il budget è di 12.000 euro")
        #expect(engine.requests.count == 1 && engine.requests[0].temperature == 0)
        #expect(engine.requests[0].system.contains("Nomi, numeri, date"))
        #expect(TextTidier.clean("```\nTesto\n```") == "Testo")
    }

    @Test func longTextsGoInPiecesBetweenParagraphs() async throws {
        let paragraph = String(repeating: "parola ", count: 300)  // ~2.100 characters
        let text = [paragraph, paragraph, paragraph].joined(separator: "\n")
        let chunks = TextTidier.chunks(text)
        #expect(chunks.count == 3 && chunks.allSatisfy { $0.count <= TextTidier.chunkLength })
        let engine = FakeEngine { $0 }
        let tidy = try await TextTidier.tidy(text, with: engine)
        #expect(engine.requests.count == 3)
        #expect(tidy.components(separatedBy: "\n\n").count == 3)

        // One huge paragraph is cut between sentences.
        let long = String(repeating: "Una frase abbastanza lunga da contare qualcosa nel totale del testo. ", count: 80)
        #expect(TextTidier.chunks(long).allSatisfy { $0.count <= TextTidier.chunkLength })
    }

    @Test func lostFactsAreReported() {
        let original =
            "Allora, il budget è di 12.000 euro, Esatto, lo conferma Anna entro il 15/10, scrivi a mario@poldo.it"
        #expect(TextTidier.missingFacts(original: original, tidied: original).isEmpty)
        let lost = TextTidier.missingFacts(
            original: original, tidied: "Il budget è di 12000 euro, lo conferma lei entro il 15/10.")
        #expect(lost == ["Anna", "mario@poldo.it"])
    }
}
