import Foundation
import IAGOCore
import Testing

@testable import IAGOStore

@Suite struct TranscriptsTests {
    func transcript(_ itemID: String, asr: String, speaker: String, text: String) -> Transcript {
        Transcript(
            itemId: itemID, engine: .init(asr: asr, model: "test"), language: "it",
            speakers: [.init(id: speaker, label: speaker == "t1" ? "Anna Prova" : "Speaker 1", source: .system)],
            segments: [.init(id: 0, speaker: speaker, start: 0, end: 2, text: text)])
    }

    @Test func teamsBesideIAGOSwapAndRemove() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        let iago = transcript(item.id, asr: "whisper", speaker: "s1", text: "testo di IAGO")
        let teams = transcript(item.id, asr: "teams", speaker: "t1", text: "testo di Teams")
        try archive.storeAsset(try iago.encoded(), itemID: item.id, kind: .transcriptJSON, fileName: "transcript.json")
        try archive.setSpeakers([("s1", "Speaker 1")], for: item.id)
        try archive.attachAlternateTranscript(
            try teams.encoded(), speakers: [("t1", "Anna Prova")], original: nil, to: item.id)

        func texts() throws -> (String?, String?) {
            let both = try archive.transcripts(itemID: item.id)
            let main = try both.main.map { try Transcript.decode(from: archive.readAssetData($0)).segments[0].text }
            let other = try both.alternate.map {
                try Transcript.decode(from: archive.readAssetData($0)).segments[0].text
            }
            return (main, other)
        }
        #expect(try texts() == ("testo di IAGO", "testo di Teams"))
        try archive.swapTranscripts(itemID: item.id)
        #expect(try texts() == ("testo di Teams", "testo di IAGO"))
        // A new main transcript is written to its own file: the other one is untouched.
        try archive.storeAsset(
            try transcript(item.id, asr: "teams", speaker: "t1", text: "Teams di nuovo").encoded(), itemID: item.id,
            kind: .transcriptJSON, fileName: "transcript.json")
        #expect(try texts() == ("Teams di nuovo", "testo di IAGO"))
        // Removing the main one: the other takes its place, and Teams' speakers go.
        try archive.removeTranscript(main: true, itemID: item.id)
        #expect(try texts() == ("testo di IAGO", nil))
        #expect(try archive.speakers(itemID: item.id).map(\.speakerId) == ["s1"])
    }

    @Test func iagoTranscriptionMovesTeamsAside() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        let teams = transcript(item.id, asr: "teams", speaker: "t1", text: "testo di Teams")
        try archive.storeAsset(try teams.encoded(), itemID: item.id, kind: .transcriptJSON, fileName: "transcript.json")
        try archive.setMainTranscriptAside(itemID: item.id)
        let aside = try #require(try archive.transcripts(itemID: item.id).alternate)
        #expect(try Transcript.decode(from: archive.readAssetData(aside)).isImported)
    }

    @Test func searchLooksInBothTranscriptsOnce() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        let iago = transcript(item.id, asr: "whisper", speaker: "s1", text: "il preventivo lo manda Feretti")
        let teams = transcript(item.id, asr: "teams", speaker: "t1", text: "il preventivo lo manda Ferretti")
        try archive.storeAsset(try iago.encoded(), itemID: item.id, kind: .transcriptJSON, fileName: "transcript.json")
        try archive.indexTranscript(iago, itemID: item.id)
        try archive.attachAlternateTranscript(
            try teams.encoded(), speakers: [("t1", "Anna Prova")], original: nil, to: item.id)

        // Only in Teams': found, and marked.
        let onlyTeams = try archive.search("Ferretti")
        #expect(onlyTeams.count == 1)
        #expect(onlyTeams.first?.alternate == "teams")
        // In both: once, from the main one.
        let both = try archive.search("preventivo")
        #expect(both.count == 1)
        #expect(both.first?.alternate == nil)
        // Reindexing the main one keeps the other's passages.
        try archive.indexTranscript(iago, itemID: item.id)
        #expect(try archive.search("Ferretti").count == 1)
        // After the swap IAGO's is the other one.
        try archive.swapTranscripts(itemID: item.id)
        try archive.indexTranscript(teams, itemID: item.id)
        #expect(try archive.search("Feretti").first?.alternate == "iago")
        // Removing the other one removes its passages.
        try archive.removeTranscript(main: false, itemID: item.id)
        #expect(try archive.search("Feretti").isEmpty)
    }

    @Test func summaryRemembersItsTranscript() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        let teams = transcript(item.id, asr: "teams", speaker: "t1", text: "testo di Teams")
        try archive.storeAsset(try teams.encoded(), itemID: item.id, kind: .transcriptJSON, fileName: "transcript.json")
        try archive.saveSummary(itemID: item.id, categoryID: nil, templateID: nil, markdown: "Sintesi", model: "test")
        #expect(try archive.summary(itemID: item.id)?.transcriptSource == "teams")
    }
}
