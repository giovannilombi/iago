import EventKit
import Foundation
import IAGOCore
import IAGOStore
import Observation

/// The Mac's Calendar as a source of meeting titles and start times (ADR-0051), only if the user turns it on and
/// the work calendar is synced there. Read only.
@MainActor
@Observable
final class MeetingCalendar {
    private let store = EKEventStore()
    private let archive: Archive
    private(set) var authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess

    static let enabledKey = "calls.calendar"
    static let callLinks = ["teams.microsoft.com", "teams.live.com", "zoom.us", "meet.google.com", "webex.com"]

    init(archive: Archive) {
        self.archive = archive
    }

    var enabled: Bool {
        (try? archive.setting(Self.enabledKey)) == "1" && authorized
    }

    /// Turns the Calendar on: macOS asks for access the first time.
    func enable(_ on: Bool) async {
        if on, !authorized {
            authorized = (try? await store.requestFullAccessToEvents()) ?? false
        }
        try? archive.setSetting(Self.enabledKey, on && authorized ? "1" : nil)
    }

    struct Meeting: Equatable {
        var id: String
        var title: String
        var start: Date
        var end: Date
        var hasCallLink: Bool
    }

    /// Meetings in progress around `date` (from 5 minutes before the start), those with a call link first.
    func meetings(around date: Date = Date()) -> [Meeting] {
        guard enabled else { return [] }
        let predicate = store.predicateForEvents(
            withStart: date.addingTimeInterval(-12 * 3_600), end: date.addingTimeInterval(3_600), calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.startDate.addingTimeInterval(-300) <= date && date <= $0.endDate }
            .map { event in
                let text = [event.url?.absoluteString, event.notes, event.location].compactMap { $0 }.joined(
                    separator: " ")
                return Meeting(
                    id: event.calendarItemIdentifier + "@\(event.startDate.timeIntervalSince1970)",
                    title: event.title ?? "", start: event.startDate, end: event.endDate,
                    hasCallLink: Self.callLinks.contains { text.localizedCaseInsensitiveContains($0) })
            }
            .sorted { ($0.hasCallLink ? 0 : 1, $0.start) < ($1.hasCallLink ? 0 : 1, $1.start) }
    }

    /// The meetings going on, for `MeetingMatcher`.
    func candidates(around date: Date = Date()) -> [MeetingCandidate] {
        meetings(around: date).map {
            MeetingCandidate(id: $0.id, title: $0.title, start: $0.start, end: $0.end, hasCallLink: $0.hasCallLink)
        }
    }

    /// Meetings with a call link that start within the last minute: "Sta per iniziare…".
    func starting(at date: Date = Date()) -> [Meeting] {
        meetings(around: date).filter { $0.hasCallLink && abs($0.start.timeIntervalSince(date)) <= 60 }
    }
}
