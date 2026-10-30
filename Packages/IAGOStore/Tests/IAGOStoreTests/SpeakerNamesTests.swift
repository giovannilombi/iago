import Foundation
import Testing

@testable import IAGOStore

@Suite struct SpeakerNamesTests {
    @Test func similarNames() {
        #expect(PersonNameMatcher.isSimilar("Lello", "Antonello"))
        #expect(PersonNameMatcher.isSimilar("Peppe", "Giuseppe"))
        #expect(PersonNameMatcher.isSimilar("Ale", "Alessandro"))
        #expect(PersonNameMatcher.isSimilar("Sandro", "Alessandro"))
        #expect(PersonNameMatcher.isSimilar("Marco", "Marco Rossi"))
        #expect(PersonNameMatcher.isSimilar("Marco Rosi", "Marco Rossi"))
        #expect(PersonNameMatcher.isSimilar("Lello Rossi", "Antonello Rossi"))
        #expect(PersonNameMatcher.isSimilar("Totò", "Salvatore"))
        #expect(!PersonNameMatcher.isSimilar("Anna Rossi", "Marco Rossi"))
        #expect(!PersonNameMatcher.isSimilar("Marco", "Luca"))
        #expect(!PersonNameMatcher.isSimilar("Luca", "Lucia"))
        #expect(!PersonNameMatcher.isSimilar("Mario", "Marco"))
    }

    @Test func knownNamesAndAliases() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        try archive.setSpeakers([("me", "Io"), ("s1", "Speaker 1"), ("s2", "Speaker 2")], for: item.id)
        try archive.renameSpeaker("s1", of: item.id, to: "Antonello Prova")
        // Generic labels are not names.
        #expect(try archive.knownPersonNames() == ["Antonello Prova"])
        #expect(try archive.similarPersonNames(to: "Lello") == ["Antonello Prova"])
        #expect(try archive.similarPersonNames(to: "Antonello Prova").isEmpty)
        #expect(try archive.similarPersonNames(to: "Bruno").isEmpty)
        // A nickname no table knows, taught once.
        try archive.setNameAlias("Toto Bis", for: "Bruno Test")
        #expect(try archive.similarPersonNames(to: "toto bis") == ["Bruno Test"])
    }

    @Test func joinTakesTheNameAndSeparateGivesItBack() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        try archive.setSpeakers([("s1", "Speaker 1"), ("s2", "Speaker 2"), ("s3", "Speaker 3")], for: item.id)
        try archive.renameSpeaker("s1", of: item.id, to: "Anna")
        try archive.mergeSpeaker("s3", into: "s1", of: item.id)
        func labels() throws -> [String: String] {
            Dictionary(uniqueKeysWithValues: try archive.speakers(itemID: item.id).map { ($0.speakerId, $0.label) })
        }
        #expect(try labels()["s3"] == "Anna")
        #expect(try archive.speakers(itemID: item.id).first { $0.speakerId == "s3" }?.mergedInto == "s1")
        // Renaming the target renames the joined one too.
        try archive.renameSpeaker("s1", of: item.id, to: "Anna Prova")
        #expect(try labels()["s3"] == "Anna Prova")
        try archive.separateSpeaker("s3", of: item.id, label: "Speaker 3")
        #expect(try labels() == ["s1": "Anna Prova", "s2": "Speaker 2", "s3": "Speaker 3"])
        #expect(try archive.speakers(itemID: item.id).allSatisfy { $0.mergedInto == nil })
    }

    @Test func attendeesKeepOrderAndKnownSpelling() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let item = try fixture.makeItem()
        try archive.setSpeakers([("s1", "Anna Prova")], for: item.id)
        _ = try archive.renameSpeaker("s1", of: item.id, to: "Anna Prova")
        try archive.setAttendees(["Bruno Test", "anna prova", " ", "Bruno Test"], itemID: item.id)
        #expect(try archive.attendees(itemID: item.id) == ["Bruno Test", "Anna Prova"])
        try archive.setAttendees([], itemID: item.id)
        #expect(try archive.attendees(itemID: item.id).isEmpty)
    }
}
