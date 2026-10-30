import Foundation

/// `transcript.json`, the source of truth of a transcription (spec 7.3). TXT and MD are rendered from it.
public struct Transcript: Codable, Sendable, Equatable {
    public struct Engine: Codable, Sendable, Equatable {
        public var asr: String
        public var model: String
        public var diarization: String?
        public var version: String?

        public init(asr: String, model: String, diarization: String? = nil, version: String? = nil) {
            self.asr = asr
            self.model = model
            self.diarization = diarization
            self.version = version
        }
    }

    public struct Speaker: Codable, Sendable, Equatable {
        public enum Source: String, Codable, Sendable {
            case mic
            case system
            case `import`
        }

        public var id: String
        public var label: String
        public var source: Source

        public init(id: String, label: String, source: Source) {
            self.id = id
            self.label = label
            self.source = source
        }

        /// The mic track is always the user (FR-41).
        public static func me(label: String = "Io") -> Speaker { Speaker(id: "me", label: label, source: .mic) }
    }

    public struct Segment: Codable, Sendable, Equatable {
        public var id: Int
        public var speaker: String
        public var start: Double
        public var end: Double
        public var text: String
        public var confidence: Double?

        public init(id: Int, speaker: String, start: Double, end: Double, text: String, confidence: Double? = nil) {
            self.id = id
            self.speaker = speaker
            self.start = start
            self.end = end
            self.text = text
            self.confidence = confidence
        }
    }

    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var itemId: String
    public var engine: Engine

    /// A transcript made outside IAGO (Teams, ADR-0033): its minutes count from the start of that transcription, not
    /// of the recording, so they are never links to the audio (ADR-0078).
    public var isImported: Bool { engine.asr == "teams" }
    public var language: String?
    public var createdAt: Date
    public var speakers: [Speaker]
    public var segments: [Segment]

    public init(
        itemId: String, engine: Engine, language: String?, createdAt: Date = Date(), speakers: [Speaker],
        segments: [Segment]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.itemId = itemId
        self.engine = engine
        self.language = language
        self.createdAt = createdAt
        self.speakers = speakers
        self.segments = segments
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> Transcript {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Transcript.self, from: data)
    }
}
