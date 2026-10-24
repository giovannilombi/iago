import Testing

@testable import IAGOIntelligence

@Test func moduleIsLinked() {
    #expect(IAGOIntelligenceModule.name == "IAGOIntelligence")
}

@Test func modelAnswersBecomeCleanTitles() {
    #expect(TitleSuggester.clean("Titolo: \"Kickoff spostato a gennaio.\"\nAltro") == "Kickoff spostato a gennaio")
    #expect(TitleSuggester.clean("**Offerta entro venerdì**") == "Offerta entro venerdì")
    #expect(TitleSuggester.clean("«Budget approvato»") == "Budget approvato")
}

@Test func firstSentenceIsTheFallbackHint() {
    #expect(TitleSuggester.firstSentence("Spostiamo il kickoff. Poi l'offerta.") == "Spostiamo il kickoff")
    #expect(TitleSuggester.firstSentence(String(repeating: "a", count: 120), limit: 10) == "aaaaaaaaaa…")
}
