import Foundation

/// The two tracks of a recording (ADR-0002), plus the single track of an import.
public enum TrackKind: String, Codable, CodingKeyRepresentable, Sendable, CaseIterable {
    case mic
    case system
}

/// Event recorded in the capture metadata (FR-13, spec 6.2).
public struct CaptureMarker: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case pause
        case resume
        case deviceChange
        case systemTapRebuilt
        case autoPauseSleep
        /// "Segna momento" (FR-05): `detail` holds the optional note.
        case bookmark
        /// ADR-0051: the user is muted in Teams; the mic track gets silence until `micUnmuted`.
        case micMuted
        case micUnmuted
    }

    public var kind: Kind
    /// Position on the recording timeline, in seconds (pauses excluded).
    public var at: Double
    public var track: TrackKind?
    public var detail: String?

    public init(kind: Kind, at: Double, track: TrackKind? = nil, detail: String? = nil) {
        self.kind = kind
        self.at = at
        self.track = track
        self.detail = detail
    }
}

/// Contents of `session.json`, written next to the raw tracks while recording (spec 6.5).
/// It is everything needed to finalize a session after a crash.
public struct SessionManifest: Codable, Sendable, Equatable {
    public enum State: String, Codable, Sendable {
        case recording
        case paused
        case stopped
        case finalized
    }

    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var itemID: ItemID
    public var startedAt: Date
    public var state: State
    public var sampleRate: Double
    public var markers: [CaptureMarker]
    /// Device names used per track, in order of use.
    public var devices: [TrackKind: [String]]
    /// Timeline length in seconds when the session was stopped; nil while recording.
    public var duration: Double?
    /// ADR-0051: the meeting title, if known, as the tentative title of the item.
    public var suggestedTitle: String?

    public init(itemID: ItemID, startedAt: Date, sampleRate: Double) {
        self.schemaVersion = Self.currentSchemaVersion
        self.itemID = itemID
        self.startedAt = startedAt
        self.state = .recording
        self.sampleRate = sampleRate
        self.markers = []
        self.devices = [:]
        self.duration = nil
    }

    public static func decode(from data: Data) throws -> SessionManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionManifest.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

/// Default title of a saved item (FR-17): `Unclassified · 2026-10-14 09:30`.
public enum ItemTitle {
    public static func unclassified(startedAt: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "Unclassified · \(formatter.string(from: startedAt))"
    }
}
