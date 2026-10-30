import Foundation
import GRDB
import IAGOCore

/// Two transcripts of the same call (ADR-0078): IAGO's and Teams', side by side. `transcriptJSON` is the main one,
/// which summaries, proposals, exports and Claude read; `alternateTranscriptJSON` the other. Search looks in both.
/// Both stay until the user removes one.
extension Archive {
    public struct Transcripts: Sendable {
        public var main: Asset?
        public var alternate: Asset?
    }

    public func transcripts(itemID: String) throws -> Transcripts {
        let assets = try assets(itemID: itemID)
        return Transcripts(
            main: assets.first { $0.kind == .transcriptJSON },
            alternate: assets.first { $0.kind == .alternateTranscriptJSON })
    }

    /// `teams` or `iago`: where the main transcript comes from; nil without one.
    public func mainTranscriptSource(itemID: String) throws -> String? {
        guard let main = try transcripts(itemID: itemID).main,
            let transcript = try? Transcript.decode(from: readAssetData(main))
        else { return nil }
        return transcript.isImported ? "teams" : "iago"
    }

    /// An imported transcript next to the one the call has: the call keeps its own as the main one.
    public func attachAlternateTranscript(
        _ transcriptJSON: Data, speakers: [(id: String, label: String)], original: URL?, to itemID: String
    ) throws {
        if let original {
            try storeAsset(
                original, itemID: itemID, kind: .originalTranscript,
                fileName: "original-transcript.\(original.pathExtension.lowercased())",
                originalName: original.lastPathComponent)
        }
        try storeAsset(transcriptJSON, itemID: itemID, kind: .alternateTranscriptJSON, fileName: "transcript-alt.json")
        try setSpeakers(speakers, for: itemID)
        try indexAlternateTranscript(itemID: itemID)
    }

    /// The main transcript becomes the other one and vice versa. Both are written again under their own file, so a
    /// later transcription never overwrites the other one.
    public func swapTranscripts(itemID: String) throws {
        let current = try transcripts(itemID: itemID)
        guard let main = current.main, let alternate = current.alternate else { return }
        let mainData = try readAssetData(main)
        let alternateData = try readAssetData(alternate)
        try storeAsset(alternateData, itemID: itemID, kind: .transcriptJSON, fileName: "transcript.json")
        try storeAsset(mainData, itemID: itemID, kind: .alternateTranscriptJSON, fileName: "transcript-alt.json")
        try indexAlternateTranscript(itemID: itemID)
    }

    /// Moves the main transcript aside before a new one takes its place: IAGO's transcription added to a call that
    /// had only Teams'. The one aside is replaced, if there was one.
    public func setMainTranscriptAside(itemID: String) throws {
        guard let main = try transcripts(itemID: itemID).main else { return }
        try storeAsset(
            try readAssetData(main), itemID: itemID, kind: .alternateTranscriptJSON, fileName: "transcript-alt.json")
        try indexAlternateTranscript(itemID: itemID)
    }

    /// Removes one of the two transcripts for good (the user confirmed it). Removing the main one makes the other the
    /// main one. The speakers only the removed one had go with it; an imported transcript takes its original file.
    public func removeTranscript(main: Bool, itemID: String) throws {
        let current = try transcripts(itemID: itemID)
        guard let removed = main ? current.main : current.alternate else { return }
        let transcript = try Transcript.decode(from: readAssetData(removed))
        if main, let alternate = current.alternate {
            try storeAsset(
                try readAssetData(alternate), itemID: itemID, kind: .transcriptJSON, fileName: "transcript.json")
            try purgeAsset(alternate.id)
        } else {
            try purgeAsset(removed.id)
        }
        if transcript.isImported,
            let original = try assets(itemID: itemID).first(where: { $0.kind == .originalTranscript })
        {
            try purgeAsset(original.id)
        }
        let kept = try transcripts(itemID: itemID).main.flatMap { try? Transcript.decode(from: readAssetData($0)) }
        let keptIDs = Set(kept?.speakers.map(\.id) ?? [])
        let gone = transcript.speakers.map(\.id).filter { !keptIDs.contains($0) }
        try database.writer.write { db in
            for id in gone {
                try db.execute(
                    sql: "DELETE FROM item_speaker WHERE item_id = ? AND speaker_id = ?", arguments: [itemID, id])
            }
        }
        try indexAlternateTranscript(itemID: itemID)
    }
}
