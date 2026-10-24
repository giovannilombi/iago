import Foundation

/// Which call apps are using the microphone now (ADR-0051): the same Core Audio process objects used to pick the
/// microphone (ADR-0004), no extra permission. Only dedicated call apps count, not browsers, so a video on a web
/// page or a dictation does not look like a call.
public enum CallActivity {
    public struct App: Sendable, Equatable {
        public var bundleID: String
        public var name: String
    }

    /// Dedicated call apps, matched as bundle ID prefixes (helpers included).
    public static let callApps: [(prefix: String, name: String)] = [
        ("com.microsoft.teams", "Teams"),
        ("us.zoom.", "Zoom"),
        ("com.cisco.webex", "Webex"),
        ("com.webex.", "Webex"),
        ("com.apple.FaceTime", "FaceTime"),
        ("com.tinyspeck.slackmacgap", "Slack"),
    ]

    /// Call apps among `processes` that are capturing audio, IAGO excluded.
    public static func apps(in processes: [ProcessAudioInfo], ownPID: Int32) -> [App] {
        var result: [App] = []
        for process in processes where process.pid != ownPID && process.isRunningInput {
            guard let bundleID = process.bundleID,
                let match = callApps.first(where: { bundleID.hasPrefix($0.prefix) }),
                !result.contains(where: { $0.name == match.name })
            else { continue }
            result.append(App(bundleID: bundleID, name: match.name))
        }
        return result
    }

    /// The same, read from Core Audio now.
    public static func current() -> [App] {
        apps(in: CoreAudioSystem.processes(), ownPID: ProcessInfo.processInfo.processIdentifier)
    }
}
