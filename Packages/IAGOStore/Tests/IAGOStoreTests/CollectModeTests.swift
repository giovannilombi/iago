import Foundation
import Testing

@testable import IAGOStore

/// ADR-0098: «Raccogli», the mode with only the contents.
@Suite struct CollectModeTests {
    @Test func collectIsTheSimplestModeAndHasNoKeyPoints() throws {
        #expect(WorkMode.allCases == [.collect, .track, .manage])
        #expect(!WorkMode.collect.hasKeyPoints && WorkMode.track.hasKeyPoints && WorkMode.manage.hasKeyPoints)
        #expect(Suggestion.Kind.allCases.filter(\.isKeyPoint) == [.decision, .activity, .question, .risk, .request])

        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let project = try archive.createProject(name: "Interviste")
        try archive.setProjectWorkMode(project.id, .collect)
        #expect(archive.workMode(projectID: project.id) == .collect)
        #expect(try archive.collectProjectCount() == 1)
        try archive.setProjectWorkMode(project.id, .manage)
        #expect(try archive.collectProjectCount() == 0)
    }

    @Test func theInboxGetsKeyPointsElsewhereAndOnlyTheOtherProposalsOfCollectProjects() throws {
        let fixture = try ArchiveFixture()
        let archive = fixture.archive
        let interviews = try archive.createProject(name: "Interviste")
        try archive.setProjectWorkMode(interviews.id, .collect)
        let portal = try archive.createProject(name: "Portale")
        let interview = try fixture.makeItem()
        try archive.updateItem(interview.id) { $0.projectId = interviews.id }
        let meeting = try fixture.makeItem()
        try archive.updateItem(meeting.id) { $0.projectId = portal.id }
        let proposals: [(kind: Suggestion.Kind, payload: SuggestionPayload)] = [
            (.decision, SuggestionPayload(text: "Logo blu")),
            (.tag, SuggestionPayload(text: "onboarding")),
            (.person, SuggestionPayload(text: "Chiara Vento")),
        ]
        try archive.replacePendingSuggestions(itemID: interview.id, model: "m", proposals)
        try archive.replacePendingSuggestions(itemID: meeting.id, model: "m", proposals)

        let inbox = try archive.pendingInboxSuggestions()
        #expect(Set(inbox.filter { $0.itemId == interview.id }.map(\.kind)) == [.tag, .person])
        #expect(inbox.filter { $0.itemId == meeting.id }.map(\.kind) == [.decision])
        #expect(try archive.pendingSuggestionCounts() == [interview.id: 2, meeting.id: 3])
    }
}
