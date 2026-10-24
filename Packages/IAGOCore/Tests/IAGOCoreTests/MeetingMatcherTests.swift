import Foundation
import Testing

@testable import IAGOCore

@Suite struct MeetingMatcherTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func meeting(_ title: String, startedMinutesAgo: Double, link: Bool = true) -> MeetingCandidate {
        let start = now.addingTimeInterval(-startedMinutesAgo * 60)
        return MeetingCandidate(
            id: title, title: title, start: start, end: start.addingTimeInterval(3_600), hasCallLink: link)
    }

    @Test func aMeetingStartingNowIsSureEvenWithAnOlderOneStillGoing() {
        let match = MeetingMatcher.match(
            [meeting("TEAM LEAD", startedMinutesAgo: 40), meeting("Fornitore", startedMinutesAgo: 2)], callStart: now)
        #expect(match.isSure)
        #expect(match.meeting?.title == "Fornitore")
    }

    @Test func onlyAnOldMeetingGoingOnIsAsked() {
        // The user may have opened another call that is not in the calendar.
        let match = MeetingMatcher.match([meeting("TEAM LEAD", startedMinutesAgo: 40)], callStart: now)
        #expect(!match.isSure)
        #expect(match.meeting?.title == "TEAM LEAD")
        #expect(match.alternatives.map(\.title) == ["TEAM LEAD"])
    }

    @Test func twoMeetingsStartingTogetherAreAsked() {
        let match = MeetingMatcher.match(
            [meeting("Uno", startedMinutesAgo: 1), meeting("Due", startedMinutesAgo: -3)], callStart: now)
        #expect(!match.isSure)
        #expect(match.meeting?.title == "Uno")
        #expect(Set(match.alternatives.map(\.title)) == ["Uno", "Due"])
    }

    @Test func theTeamsWindowSettlesIt() {
        let match = MeetingMatcher.match(
            [meeting("Team", startedMinutesAgo: 1), meeting("Team lead", startedMinutesAgo: 40)], callStart: now,
            windowTitles: ["Team Lead | Microsoft Teams"])
        #expect(match.isSure)
        #expect(match.meeting?.title == "Team lead")
    }

    @Test func meetingsWithACallLinkComeFirst() {
        let match = MeetingMatcher.match(
            [meeting("Pranzo", startedMinutesAgo: 1, link: false), meeting("Kickoff", startedMinutesAgo: 3)],
            callStart: now)
        #expect(match.isSure)
        #expect(match.meeting?.title == "Kickoff")
    }

    @Test func noMeetingNoTitle() {
        let match = MeetingMatcher.match([], callStart: now)
        #expect(match.meeting == nil && match.alternatives.isEmpty)
    }
}
