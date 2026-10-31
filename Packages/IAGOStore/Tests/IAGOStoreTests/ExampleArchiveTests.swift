import Foundation
import Testing

@testable import IAGOStore

@Suite struct ExampleArchiveTests {
    @Test(arguments: ["it", "en"]) func exampleFillsEveryPartAndGoesAway(language: String) throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let created = try #require(try archive.createStarterExampleIfNew(language: language))
        #expect(try archive.createStarterExampleIfNew(language: language) == nil)
        #expect(try archive.clients().map(\.name).sorted() == ["Atoms", "Poldo S.p.A.", "Sanna TheBest s.r.l."])
        #expect(try archive.exampleMainProjectID() == created.mainProjectID)
        let items = try archive.items()
        #expect(items.count == 10)
        #expect(Set(items.map(\.type)) == [.call, .email, .document])
        #expect(try archive.summary(itemID: created.kickoffID) != nil)
        #expect(try archive.decisions(DecisionQuery(scope: .all, statuses: [])).count >= 12)
        #expect(try !archive.search(language == "en" ? "headless" : "headless").isEmpty)
        // The example does not tick the introduction's first steps.
        #expect(try archive.firstSteps().done == 0)

        try archive.removeExample()
        #expect(try archive.clients().isEmpty)
        #expect(try archive.items().isEmpty)
        #expect(try archive.exampleMainProjectID() == nil)
    }
}
