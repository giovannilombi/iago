import Foundation
import GRDB
import Testing

@testable import IAGOStore

@Suite struct VoicesTests {
    /// Two clearly different voices and a slightly different take of the first.
    let anna: [Float] = [1, 0.1, 0, 0]
    let annaAgain: [Float] = [0.95, 0.15, 0.05, 0]
    let bruno: [Float] = [0, 0, 1, 0.2]

    func call(_ fixture: ArchiveFixture, _ title: String, _ voices: [SpeakerVoice]) throws -> String {
        let item = try fixture.makeItem(title)
        try fixture.archive.setSpeakers(
            [("me", "Io")] + voices.enumerated().map { ($1.speakerID, "Speaker \($0 + 1)") }, for: item.id)
        try fixture.archive.storeVoices(voices, itemID: item.id)
        return item.id
    }

    func storedRows(_ archive: Archive) throws -> Int {
        try archive.database.writer.read { db in try Int.fetchOne(db, sql: "SELECT count(*) FROM item_voice") ?? 0 }
    }

    @Test func nothingIsKeptWhileOff() throws {
        let fixture = try ArchiveFixture()
        let id = try call(fixture, "Call", [SpeakerVoice(speakerID: "s1", embedding: anna, seconds: 60)])
        try fixture.archive.renameSpeaker("s1", of: id, to: "Anna")
        #expect(try storedRows(fixture.archive) == 0)
        #expect(try fixture.archive.voicePrints().isEmpty)
        #expect(try fixture.archive.voiceMatches(itemID: id).isEmpty)
    }

    @Test func namingASpeakerTeachesTheVoiceAndTheNextCallProposesIt() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        try archive.setVoicesEnabled(true)
        let first = try call(
            fixture, "Prima",
            [
                SpeakerVoice(speakerID: "s1", embedding: anna, seconds: 120),
                SpeakerVoice(speakerID: "s2", embedding: bruno, seconds: 90),
            ])
        try archive.renameSpeaker("s1", of: first, to: "Anna")
        let prints = try archive.voicePrints()
        #expect(prints.map(\.name) == ["Anna"])
        #expect(prints.first?.calls == 1)
        #expect(prints.first?.seconds == 120)

        let second = try call(
            fixture, "Seconda",
            [
                SpeakerVoice(speakerID: "s1", embedding: bruno, seconds: 40),
                SpeakerVoice(speakerID: "s2", embedding: annaAgain, seconds: 50),
            ])
        let matches = try archive.voiceMatches(itemID: second)
        #expect(matches.map(\.speakerID) == ["s2"])
        #expect(matches.first?.name == "Anna")
        #expect((matches.first?.similarity ?? 0) > 0.9)

        // Once named in this call, Anna is not proposed again here.
        try archive.renameSpeaker("s2", of: second, to: "Anna")
        #expect(try archive.voiceMatches(itemID: second).isEmpty)
        #expect(try archive.voicePrints().first?.calls == 2)
    }

    @Test func shortSpeechIsNotKept() throws {
        let fixture = try ArchiveFixture()
        try fixture.archive.setVoicesEnabled(true)
        _ = try call(fixture, "Call", [SpeakerVoice(speakerID: "s1", embedding: anna, seconds: 4)])
        #expect(try storedRows(fixture.archive) == 0)
    }

    @Test func embeddingsAreSealedWithTheItemKey() throws {
        let fixture = try ArchiveFixture()
        try fixture.archive.setVoicesEnabled(true)
        let id = try call(fixture, "Call", [SpeakerVoice(speakerID: "s1", embedding: anna, seconds: 30)])
        let stored = try fixture.archive.database.writer.read { db in
            try Data.fetchOne(db, sql: "SELECT embedding FROM item_voice WHERE item_id = ?", arguments: [id])
        }
        let plain = anna.withUnsafeBufferPointer { Data(buffer: $0) }
        #expect(stored != nil)
        #expect(stored?.range(of: plain) == nil)
    }

    @Test func renamingBackOrToAnotherNameMovesTheVoice() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        try archive.setVoicesEnabled(true)
        let id = try call(fixture, "Call", [SpeakerVoice(speakerID: "s1", embedding: anna, seconds: 30)])
        try archive.renameSpeaker("s1", of: id, to: "Ana")
        try archive.renameSpeaker("s1", of: id, to: "Anna")
        // The misspelt voice has nothing left behind it.
        #expect(try archive.voicePrints().map(\.name) == ["Anna"])
        try archive.renameSpeaker("s1", of: id, to: "Speaker 1")
        #expect(try archive.voicePrints().isEmpty)
        #expect(try storedRows(archive) == 1)  // kept, for when it gets a name again
    }

    @Test func forgettingAVoiceOrDeletingTheCallTakesItAway() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        try archive.setVoicesEnabled(true)
        let first = try call(fixture, "Prima", [SpeakerVoice(speakerID: "s1", embedding: anna, seconds: 30)])
        let second = try call(fixture, "Seconda", [SpeakerVoice(speakerID: "s1", embedding: bruno, seconds: 30)])
        try archive.renameSpeaker("s1", of: first, to: "Anna")
        try archive.renameSpeaker("s1", of: second, to: "Bruno")

        try archive.purgeItem(second)
        #expect(try archive.voicePrints().map(\.name) == ["Anna"])

        let anna = try #require(try archive.voicePrints().first)
        try archive.forgetVoice(anna.id)
        #expect(try archive.voicePrints().isEmpty)
        #expect(try storedRows(archive) == 0)
    }

    @Test func forgettingAllRemovesUnnamedSpeakersToo() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        try archive.setVoicesEnabled(true)
        let id = try call(
            fixture, "Call",
            [
                SpeakerVoice(speakerID: "s1", embedding: anna, seconds: 30),
                SpeakerVoice(speakerID: "s2", embedding: bruno, seconds: 30),
            ])
        try archive.renameSpeaker("s1", of: id, to: "Anna")
        try archive.forgetAllVoices()
        #expect(try archive.voicePrints().isEmpty)
        #expect(try storedRows(archive) == 0)
    }

    @Test func aTranscriptionAgainTiesNamedSpeakersAtOnce() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let id = try call(fixture, "Call", [])
        try archive.setSpeakers([("s1", "Speaker 1")], for: id)
        try archive.renameSpeaker("s1", of: id, to: "Anna")  // named before voices were on
        try archive.setVoicesEnabled(true)
        try archive.storeVoices([SpeakerVoice(speakerID: "s1", embedding: anna, seconds: 30)], itemID: id)
        #expect(try archive.voicePrints().map(\.name) == ["Anna"])
    }

    @Test func assignmentNeedsAClearWinner() {
        let voices: [String: [Float]] = ["a": [1, 0], "b": [0.99, 0.14]]
        // Close to both: no proposal.
        #expect(
            VoiceMath.assign(speakers: ["s1": [1, 0.07]], voices: voices, threshold: 0.6, margin: 0.05).isEmpty)
        // One voice, two speakers: only the closer one gets it.
        let one = VoiceMath.assign(
            speakers: ["s1": [1, 0.3], "s2": [1, 0]], voices: ["a": [1, 0]], threshold: 0.6, margin: 0.05)
        #expect(one.map(\.speakerID) == ["s2"])
        // Far from every voice: nothing.
        #expect(
            VoiceMath.assign(speakers: ["s1": [0, 1]], voices: ["a": [1, 0]], threshold: 0.6, margin: 0.05).isEmpty)
    }

    @Test func genericLabelsAreNotNames() {
        #expect(!Archive.isVoiceName("Speaker 2"))
        #expect(!Archive.isVoiceName("Stanza 3"))
        #expect(!Archive.isVoiceName("Io"))
        #expect(!Archive.isVoiceName("  "))
        #expect(Archive.isVoiceName("Anna"))
        #expect(Archive.isVoiceName("Speakerina"))
    }
}
