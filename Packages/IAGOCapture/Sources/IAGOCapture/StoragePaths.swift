import Foundation

/// On-disk layout (spec 9.1).
public struct StoragePaths: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static func applicationSupport() throws -> StoragePaths {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return StoragePaths(root: base.appendingPathComponent("IAGO", isDirectory: true))
    }

    public var database: URL { root.appendingPathComponent("iago.sqlite") }
    /// Encrypted files, one folder per item.
    public var items: URL { root.appendingPathComponent("Items", isDirectory: true) }
    public var models: URL { root.appendingPathComponent("Models", isDirectory: true) }
    /// Recordings in progress (plaintext until finalized, spec 9.1).
    public var sessions: URL { root.appendingPathComponent("tmp/sessions", isDirectory: true) }
    /// Finalized plaintext tracks waiting to be encrypted into `Items/`.
    public var finalized: URL { root.appendingPathComponent("tmp/finalized", isDirectory: true) }
    /// Scratch space for imports and decrypted copies; emptied at launch.
    /// An unpacked backup waiting to replace the archive at the next launch (ADR-0041).
    public var restorePending: URL { root.appendingPathComponent("restore-pending", isDirectory: true) }
    /// Archives replaced by a restore, kept aside (never deleted automatically).
    public var replacedArchives: URL { root.appendingPathComponent("Archivi sostituiti", isDirectory: true) }

    /// Voice notes waiting for their transcription (FR-215): not emptied at launch like `scratch`, so a
    /// failed one can be offered again.
    public var voiceNotes: URL { root.appendingPathComponent("tmp/voice-notes", isDirectory: true) }
    public var scratch: URL { root.appendingPathComponent("tmp/scratch", isDirectory: true) }
    /// Phase 0 plaintext recordings, imported into the archive at launch (ADR-0029).
    public var legacyRecordings: URL { root.appendingPathComponent("Recordings", isDirectory: true) }

    public func createDirectories() throws {
        for url in [items, models, sessions, finalized, scratch] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Removes leftovers of decrypted or converted files (spec 9.4).
    public func clearScratch() throws {
        if FileManager.default.fileExists(atPath: scratch.path) { try FileManager.default.removeItem(at: scratch) }
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }
}
