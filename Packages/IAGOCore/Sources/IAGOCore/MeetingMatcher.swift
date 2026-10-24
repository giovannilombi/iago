import Foundation

/// A meeting of the Mac's Calendar, as a candidate title for a call (ADR-0051).
public struct MeetingCandidate: Equatable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var hasCallLink: Bool

    public init(id: String, title: String, start: Date, end: Date, hasCallLink: Bool) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.hasCallLink = hasCallLink
    }
}

/// Which calendar meeting a call is (ADR-0051, amended 2026-10-20). Sure only when the title of a Teams window
/// names the meeting, or when a single meeting started around the moment the call began; otherwise the best guess
/// comes with the alternatives, and IAGO asks.
public enum MeetingMatcher {
    public struct Match: Equatable, Sendable {
        /// The best guess; nil when no meeting is going on.
        public var meeting: MeetingCandidate?
        /// Not empty when IAGO is not sure: the meetings to choose from, best guess first.
        public var alternatives: [MeetingCandidate]

        public var isSure: Bool { meeting != nil && alternatives.isEmpty }
    }

    /// How far from its start a call still counts as "that meeting starting".
    public static let startTolerance: (before: TimeInterval, after: TimeInterval) = (600, 900)

    public static func match(_ meetings: [MeetingCandidate], callStart: Date, windowTitles: [String] = [])
        -> Match
    {
        let named = meetings.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !named.isEmpty else { return Match(meeting: nil, alternatives: []) }
        // A Teams window that names the meeting settles it; the longest title wins ("Team lead" over "Team").
        let windows = windowTitles.map(normalized)
        let inWindows = named.filter { meeting in
            let title = normalized(meeting.title)
            return title.count >= 3 && windows.contains { $0.contains(title) }
        }
        if let longest = inWindows.map({ normalized($0.title).count }).max() {
            let best = inWindows.filter { normalized($0.title).count == longest }
            if best.count == 1 { return Match(meeting: best[0], alternatives: []) }
        }
        let withLink = named.filter(\.hasCallLink)
        let pool = withLink.isEmpty ? named : withLink
        let starting = pool.filter {
            let offset = callStart.timeIntervalSince($0.start)
            return offset >= -startTolerance.before && offset <= startTolerance.after
        }
        .sorted { abs(callStart.timeIntervalSince($0.start)) < abs(callStart.timeIntervalSince($1.start)) }
        if starting.count == 1 { return Match(meeting: starting[0], alternatives: []) }
        if starting.count > 1 { return Match(meeting: starting[0], alternatives: starting) }
        // Meetings that began a while ago: the call may be one of them, or another one not in the calendar.
        let ongoing = pool.sorted { $0.start > $1.start }
        return Match(meeting: ongoing[0], alternatives: ongoing)
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }
}
