import Foundation
import Testing

@testable import IAGOStore

@Suite struct FirstStepsTests {
    @Test func stepsTickThemselves() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        #expect(try archive.firstSteps().done == 0)
        let item = try fixture.makeItem()
        try archive.setSpeakers([("s1", "Speaker 1")], for: item.id)
        #expect(try archive.firstSteps().namedSpeaker == false)
        try archive.renameSpeaker("s1", of: item.id, to: "Anna Prova")
        let steps = try archive.firstSteps()
        #expect(steps.namedSpeaker)
        #expect(!steps.asked)
    }
}
