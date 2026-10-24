import Testing

@testable import IAGOTranscription

@Suite struct VocabularyTests {
    @Test func theVocabularyBecomesAShortPromptWithoutDuplicates() {
        let options = TranscriptionOptions(vocabulary: ["Acme", " acme ", "PX7", "", "Rossi Srl"])
        #expect(options.vocabularyPrompt == "Acme, PX7, Rossi Srl.")
        #expect(TranscriptionOptions().vocabularyPrompt == nil)
        let long = TranscriptionOptions(vocabulary: (1...100).map { "Termine\($0)" })
        #expect((long.vocabularyPrompt?.count ?? 0) <= 220)
    }
}
