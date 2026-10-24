import Foundation
import GRDB
import IAGOCore

// Rows of the phase 1 tables (spec 8.2, 8.4). Defaults for the sync columns are placeholders: the
// real values are set by `SyncWriter` when the record is saved.

public struct Project: SyncRecord, Identifiable, Hashable {
    public static let databaseTableName = "project"
    public var id: String
    public var name: String
    public var color: String?
    public var archived = false
    public var claudeAccessible = false
    /// ADR-0044: Claude may also add and edit notes, decisions and items (only when `claudeAccessible`).
    public var claudeWritable = false
    public var sharingEnabled = false
    public var pinned = false
    public var lastUsedAt: Date?
    /// ADR-0038: the client the project belongs to, if any.
    public var clientId: String?
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

public struct Category: SyncRecord, Identifiable, Hashable {
    public static let databaseTableName = "category"
    public var id: String
    public var name: String
    public var color: String?
    public var sortOrder: Int
    public var isBuiltin = false
    public var archived = false
    /// ADR-0054: nil for the main categories; the family ("Agile", "Direzione"…) of the others, which stay
    /// archived until the user turns them on.
    public var family: String?
    /// The summary template of the library this category uses; nil: none.
    public var templateId: String?
    /// The user's own version of the template (JSON in Meetily's format), when edited.
    public var templateJson: String?
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""

    /// FR-100 (open decision G closed by the user on 2026-10-12).
    /// ADR-0054: "Commerciale" became "Client/Sales", "Customer discovery" added; the families come from `library`.
    public static let builtinNames = [
        "1to1", "Kickoff", "SAL", "Workshop", "Review/Demo", "Client/Sales", "Customer discovery", "Interna", "Altro",
    ]
}

public struct Tag: SyncRecord, Identifiable, Hashable {
    public static let databaseTableName = "tag"
    public var id: String
    public var name: String
    public var normalized: String
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

public struct Item: SyncRecord, Identifiable, Hashable {
    public enum Kind: String, Codable, Sendable { case call, email, document }
    /// `mcp`: inserted by the user through Claude (ADR-0044).
    public enum Source: String, Codable, Sendable { case recording, `import`, mcp }
    public enum Status: String, Codable, Sendable {
        case recording, recorded, transcribing, transcribed, error
        /// Documents (spec 8.4.1).
        case extracting, ready
    }

    public static let databaseTableName = "item"
    public var id: String
    public var type: Kind = .call
    public var title: String
    public var occurredAt: Date
    public var durationSec: Double?
    public var source: Source
    public var status: Status
    public var projectId: String?
    public var categoryId: String?
    public var shared = false
    /// JSON with pauses, device changes and devices used (spec 8.2).
    public var captureMeta: String?
    /// Set while the item is in the trash (ADR-0030).
    public var trashedAt: Date?
    /// `discarded` for recordings thrown away with "Scarta" (ADR-0032), nil for the normal trash.
    public var trashReason: String?
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""

    public init(
        id: String, type: Kind = .call, title: String, occurredAt: Date, durationSec: Double? = nil, source: Source,
        status: Status, projectId: String? = nil, categoryId: String? = nil, captureMeta: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.occurredAt = occurredAt
        self.durationSec = durationSec
        self.source = source
        self.status = status
        self.projectId = projectId
        self.categoryId = categoryId
        self.captureMeta = captureMeta
    }

    public var itemID: ItemID? { ItemID(rawValue: id) }
}

public struct Asset: SyncRecord, Identifiable, Hashable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case audioMic = "audio_mic"
        case audioSystem = "audio_system"
        case audioMix = "audio_mix"
        case audioImport = "audio_import"
        case transcriptJSON = "transcript_json"
        case transcriptTXT = "transcript_txt"
        case transcriptMD = "transcript_md"
        /// v1.4 (spec 8.4.1): original of an imported document and its Markdown.
        case originalDocument = "original_document"
        case originalImage = "original_image"
        case contentMD = "content_md"
        /// Original of an imported transcript (e.g. Teams .vtt/.docx), kept as precious source material.
        case originalTranscript = "original_transcript"
        /// File attached to a note (image, screenshot, document), kept when the user asks for it.
        case noteAttachment = "note_attachment"
        /// Original `.eml` of an email (FR-200).
        case originalEmail = "original_eml"
        /// The Markdown as extracted, kept when the user corrects it (FR-191).
        case contentMDAuto = "content_md_auto"

        public var isAudio: Bool { [.audioMic, .audioSystem, .audioMix, .audioImport].contains(self) }
    }

    public static let databaseTableName = "asset"
    public var id: String
    public var itemId: String
    public var kind: Kind
    /// Path relative to the items root, e.g. `<itemId>/mic.m4a.enc`.
    public var relPath: String
    public var sizeBytes: Int64?
    /// SHA-256 of the plaintext, hex.
    public var sha256: String?
    /// The note a `note_attachment` belongs to.
    public var noteId: String?
    /// Original file name, for display and export.
    public var originalName: String?
    public var trashedAt: Date?
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

public struct Marker: SyncRecord, Identifiable, Hashable {
    public enum Status: String, Codable, Sendable { case open, converted, dismissed }

    public static let databaseTableName = "marker"
    public var id: String
    public var itemId: String
    public var atSec: Double
    public var note: String?
    public var status: Status = .open
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

public struct Note: SyncRecord, Identifiable, Hashable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case note, email, lateDecision = "late_decision", update
    }
    /// `mcp`: written by the user through Claude (ADR-0044).
    public enum Input: String, Codable, Sendable { case typed, voice, mcp }

    public static let databaseTableName = "note"
    public var id: String
    public var itemId: String?
    public var projectId: String?
    public var kind: Kind = .note
    public var input: Input = .typed
    /// Markdown.
    public var body: String
    public var notedAt: Date
    public var shared = false
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""

    public init(
        id: String, itemId: String?, projectId: String? = nil, kind: Kind = .note, input: Input = .typed, body: String,
        notedAt: Date
    ) {
        self.id = id
        self.itemId = itemId
        self.projectId = projectId
        self.kind = kind
        self.input = input
        self.body = body
        self.notedAt = notedAt
    }
}

public struct ItemSpeaker: Codable, FetchableRecord, PersistableRecord, Sendable, Hashable {
    public static let databaseTableName = "item_speaker"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }
    public var itemId: String
    public var speakerId: String
    public var label: String
    public var entityId: String?
}

public struct AuditEntry: Codable, FetchableRecord, Sendable, Hashable {
    public static let databaseTableName = "audit_log"
    public var id: Int64
    public var at: Date
    public var actor: String
    public var action: String
    public var detail: String?
}

/// A person, organization or topic (spec 8.4). Phase 2 only creates people typed on decisions.
public struct Entity: SyncRecord, Identifiable, Hashable {
    public enum Kind: String, Codable, Sendable { case person, organization, topic }

    public static let databaseTableName = "entity"
    public var id: String
    public var type: Kind
    public var name: String
    public var normalized: String
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

/// Decision register entry (FR-150…157). Survives its source: if the item or note is deleted the
/// decision keeps text, date and people and only loses the link (FR-156).
public struct Decision: SyncRecord, Identifiable, Hashable {
    /// FR-157: actions and open questions share the model; the UI exposes only `decision` for now.
    /// "Punti chiave" (ADR-0046): a decision, an activity (`action`: to do or under way, may become a decision)
    /// or a milestone (something important that happened). `openQuestion` is reserved (ADR-0014).
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case decision, action, milestone, openQuestion = "open_question"
    }
    /// `active`: valid (decision), open (activity), standing (milestone). `done`: an activity carried out.
    public enum Status: String, Codable, Sendable, CaseIterable { case active, done, superseded, cancelled }
    /// `mcp`: added by the user through Claude (ADR-0044).
    public enum Origin: String, Codable, Sendable { case marker, selection, note, extraction, manual, mcp }

    public static let databaseTableName = "decision"
    public var id: String
    public var kind: Kind = .decision
    public var text: String
    public var decidedAt: Date
    public var projectId: String?
    public var sourceItemId: String?
    public var sourceAtSec: Double?
    public var sourceNoteId: String?
    public var status: Status = .active
    public var supersedesId: String?
    public var origin: Origin
    public var notes: String?
    /// Name the user gave to the chain this decision starts (only on the first decision of a chain).
    public var chainName: String?
    public var shared = false
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""

    public init(
        id: String = "", text: String, decidedAt: Date, projectId: String? = nil, sourceItemId: String? = nil,
        sourceAtSec: Double? = nil, sourceNoteId: String? = nil, supersedesId: String? = nil, origin: Origin,
        notes: String? = nil, kind: Kind = .decision
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.decidedAt = decidedAt
        self.projectId = projectId
        self.sourceItemId = sourceItemId
        self.sourceAtSec = sourceAtSec
        self.sourceNoteId = sourceNoteId
        self.supersedesId = supersedesId
        self.origin = origin
        self.notes = notes
    }
}

/// A client: groups projects, holds no items itself (ADR-0038).
public struct Client: SyncRecord, Identifiable, Hashable {
    public static let databaseTableName = "client"
    public var id: String
    public var name: String
    public var color: String?
    public var archived = false
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}

/// A stream of a project ("Design", "Sviluppo"…): items and decisions can be in several (ADR-0038).
public struct ProjectStream: SyncRecord, Identifiable, Hashable {
    public static let databaseTableName = "stream"
    public var id: String
    public var projectId: String
    public var name: String
    public var color: String?
    public var sortOrder = 0
    public var archived = false
    public var createdAt = Date.distantPast
    public var updatedAt = Date.distantPast
    public var deletedAt: Date?
    public var version = 0
    public var deviceId = ""
}
