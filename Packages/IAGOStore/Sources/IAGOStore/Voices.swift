import CryptoKit
import Foundation
import GRDB

/// One person's voice, learnt from the calls where the user gave a speaker that name (ADR-0073).
public struct VoicePrint: Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    /// Calls the print comes from.
    public var calls: Int
    /// Seconds of speech behind it.
    public var seconds: Double
    public var updatedAt: Date
}

/// The embedding of one speaker of a call, as the diarizer computed it.
public struct SpeakerVoice: Sendable, Equatable {
    public var speakerID: String
    public var embedding: [Float]
    public var seconds: Double

    public init(speakerID: String, embedding: [Float], seconds: Double) {
        self.speakerID = speakerID
        self.embedding = embedding
        self.seconds = seconds
    }
}

/// A speaker of a call that sounds like a known voice.
public struct VoiceMatch: Sendable, Equatable {
    public var speakerID: String
    public var voiceID: String
    public var name: String
    public var similarity: Double
}

/// Cosine similarity of speaker embeddings and the choice of who is who.
enum VoiceMath {
    static func normalized(_ vector: [Float]) -> [Float] {
        let norm = vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
        return norm > 0 ? vector.map { $0 / norm } : vector
    }

    /// The direction shared by a voice's samples, each weighted by its seconds of speech.
    static func centroid(_ samples: [(embedding: [Float], seconds: Double)]) -> [Float]? {
        guard let size = samples.first?.embedding.count else { return nil }
        var sum = [Float](repeating: 0, count: size)
        for sample in samples where sample.embedding.count == size {
            let weight = Float(sample.seconds)
            for (index, value) in normalized(sample.embedding).enumerated() { sum[index] += value * weight }
        }
        return normalized(sum)
    }

    static func similarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        return Double(zip(normalized(a), normalized(b)).reduce(0) { $0 + $1.0 * $1.1 })
    }

    /// Best pairs first; a voice goes to one speaker at most, and only when it is clearly closer than any other
    /// voice: a wrong name is worse than none.
    static func assign(
        speakers: [String: [Float]], voices: [String: [Float]], threshold: Double, margin: Double
    ) -> [(speakerID: String, voiceID: String, similarity: Double)] {
        var candidates: [(speakerID: String, voiceID: String, similarity: Double)] = []
        for (speakerID, embedding) in speakers {
            let ranked = voices.map { ($0.key, similarity(embedding, $0.value)) }.sorted { $0.1 > $1.1 }
            guard let best = ranked.first, best.1 >= threshold else { continue }
            if ranked.count > 1, best.1 - ranked[1].1 < margin { continue }
            candidates.append((speakerID, best.0, best.1))
        }
        var usedVoices: Set<String> = []
        var result: [(speakerID: String, voiceID: String, similarity: Double)] = []
        for candidate in candidates.sorted(by: { $0.similarity > $1.similarity })
        where usedVoices.insert(candidate.voiceID).inserted {
            result.append(candidate)
        }
        return result.sorted { $0.speakerID < $1.speakerID }
    }
}

/// Voice prints (ADR-0073): on by default since ADR-0094, off when the user turns them off. Each diarized speaker of a call keeps its embedding,
/// sealed with the item's key; naming the speaker ties it to that person's voice, and the next calls get a proposal
/// "Speaker 2 sembra Marco". A print is the mean of the calls it comes from: deleting a call, or forgetting a voice,
/// takes it away. Nothing of this goes to Claude, the exports or the sync.
extension Archive {
    public static let voicesEnabledKey = "voices.enabled"
    /// Below this much speech an embedding is too unreliable to learn from or to match.
    public static let minimumVoiceSeconds = 10.0
    /// Cosine similarity a speaker needs to be proposed as a known voice, and its lead over the next voice.
    /// To calibrate with real calls (ADR-0073).
    public static let voiceThreshold = 0.6
    public static let voiceMargin = 0.05

    /// On unless the user turned it off (ADR-0094): no setting means on.
    public func voicesEnabled() -> Bool { ((try? setting(Self.voicesEnabledKey)) ?? nil) != "0" }

    public func setVoicesEnabled(_ enabled: Bool) throws {
        try setSetting(Self.voicesEnabledKey, enabled ? "1" : "0")
    }

    /// Generic labels ("Speaker 2", "Stanza 3", "Io") are not names to learn a voice for.
    public static func isVoiceName(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return !["Io", "Speaker", "Stanza", "Partecipante"].contains { trimmed == $0 || trimmed.hasPrefix("\($0) ") }
    }

    /// Keeps the speakers' embeddings of a call just transcribed, replacing those of an earlier transcription.
    /// Speakers that already have a name (a call transcribed again) are tied to that voice at once.
    public func storeVoices(_ voices: [SpeakerVoice], itemID: String) throws {
        guard voicesEnabled() else { return }
        let key = try itemKey(itemID)
        let now = self.now()
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM item_voice WHERE item_id = ?", arguments: [itemID])
            for voice in voices where voice.seconds >= Self.minimumVoiceSeconds && !voice.embedding.isEmpty {
                let label = try String.fetchOne(
                    db, sql: "SELECT label FROM item_speaker WHERE item_id = ? AND speaker_id = ?",
                    arguments: [itemID, voice.speakerID])
                let voiceID = try label.flatMap { try Self.isVoiceName($0) ? Self.voiceID(named: $0, now, db) : nil }
                try db.execute(
                    sql:
                        "INSERT INTO item_voice (item_id, speaker_id, embedding, seconds, voice_id) VALUES (?, ?, ?, ?, ?)",
                    arguments: [
                        itemID, voice.speakerID,
                        try Self.seal(voice.embedding, key: key, itemID: itemID, speakerID: voice.speakerID),
                        voice.seconds, voiceID,
                    ])
            }
            try Self.dropEmptyVoices(db)
        }
    }

    /// Whether the call has its speakers' voice prints (transcribed with recognition on).
    public func hasVoices(itemID: String) throws -> Bool {
        try database.writer.read { db in
            try Bool.fetchOne(db, sql: "SELECT EXISTS (SELECT 1 FROM item_voice WHERE item_id = ?)", arguments: [itemID])
                ?? false
        }
    }

    /// The known voices, by name.
    public func voicePrints() throws -> [VoicePrint] {
        try database.writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT v.id, v.name, v.updated_at, count(iv.item_id) AS calls, coalesce(sum(iv.seconds), 0) AS seconds
                    FROM voice v LEFT JOIN item_voice iv ON iv.voice_id = v.id
                    GROUP BY v.id ORDER BY v.name COLLATE NOCASE
                    """
            ).map {
                VoicePrint(
                    id: $0["id"], name: $0["name"], calls: $0["calls"], seconds: $0["seconds"],
                    updatedAt: $0["updated_at"])
            }
        }
    }

    /// Forgets one voice: the print and the embeddings of the calls it came from.
    public func forgetVoice(_ id: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM item_voice WHERE voice_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM voice WHERE id = ?", arguments: [id])
        }
    }

    /// Forgets every voice, and the embeddings of speakers not named yet.
    public func forgetAllVoices() throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM item_voice")
            try db.execute(sql: "DELETE FROM voice")
        }
    }

    /// Speakers of a call, still without a name, that sound like a known voice. A voice already named in this
    /// call is not proposed again.
    public func voiceMatches(itemID: String) throws -> [VoiceMatch] {
        guard voicesEnabled() else { return [] }
        let rows = try database.writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT iv.item_id, iv.speaker_id, iv.embedding, iv.seconds, iv.voice_id, s.label
                    FROM item_voice iv LEFT JOIN item_speaker s ON s.item_id = iv.item_id AND s.speaker_id = iv.speaker_id
                    WHERE iv.item_id = ? OR iv.voice_id IS NOT NULL
                    """, arguments: [itemID])
        }
        var keys: [String: SymmetricKey] = [:]
        func open(_ row: Row) -> [Float]? {
            let owner: String = row["item_id"]
            guard let key = keys[owner] ?? (try? itemKey(owner)) else { return nil }
            keys[owner] = key
            return try? Self.open(row["embedding"], key: key, itemID: owner, speakerID: row["speaker_id"])
        }
        var unnamed: [String: [Float]] = [:]
        var namedHere: Set<String> = []
        var samples: [String: [(embedding: [Float], seconds: Double)]] = [:]
        for row in rows {
            let owner: String = row["item_id"]
            let voiceID: String? = row["voice_id"]
            if owner == itemID {
                if let voiceID {
                    namedHere.insert(voiceID)
                } else if !Self.isVoiceName(row["label"] ?? ""), let embedding = open(row) {
                    unnamed[row["speaker_id"]] = embedding
                }
            } else if let voiceID, let embedding = open(row) {
                samples[voiceID, default: []].append((embedding, row["seconds"]))
            }
        }
        let centroids = samples.filter { !namedHere.contains($0.key) }.compactMapValues(VoiceMath.centroid)
        guard !unnamed.isEmpty, !centroids.isEmpty else { return [] }
        let names = Dictionary(uniqueKeysWithValues: try voicePrints().map { ($0.id, $0.name) })
        return VoiceMath.assign(
            speakers: unnamed, voices: centroids, threshold: Self.voiceThreshold, margin: Self.voiceMargin
        ).compactMap { pair in
            names[pair.voiceID].map {
                VoiceMatch(speakerID: pair.speakerID, voiceID: pair.voiceID, name: $0, similarity: pair.similarity)
            }
        }
    }

    // MARK: Inside the archive

    /// After a speaker is named (or renamed back to "Speaker 2"): its embedding joins that voice, or leaves it.
    static func linkVoice(itemID: String, speakerID: String, label: String, now: Date, _ db: Database) throws {
        guard
            try String.fetchOne(db, sql: "SELECT value FROM setting WHERE key = ?", arguments: [voicesEnabledKey])
                != "0"
        else { return }
        let voiceID = isVoiceName(label) ? try voiceID(named: label, now, db) : nil
        try db.execute(
            sql: "UPDATE item_voice SET voice_id = ? WHERE item_id = ? AND speaker_id = ?",
            arguments: [voiceID, itemID, speakerID])
        if let voiceID, db.changesCount > 0 {
            try db.execute(sql: "UPDATE voice SET updated_at = ? WHERE id = ?", arguments: [now, voiceID])
        }
        try dropEmptyVoices(db)
    }

    /// The item is deleted for good: its speakers' embeddings go with it.
    static func removeVoices(itemID: String, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM item_voice WHERE item_id = ?", arguments: [itemID])
        try dropEmptyVoices(db)
    }

    private static func voiceID(named label: String, _ now: Date, _ db: Database) throws -> String {
        let name = label.trimmingCharacters(in: .whitespaces)
        if let id = try String.fetchOne(db, sql: "SELECT id FROM voice WHERE name = ?", arguments: [name]) {
            return id
        }
        let id = newID(at: now)
        try db.execute(
            sql: "INSERT INTO voice (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)",
            arguments: [id, name, now, now])
        return id
    }

    /// A voice with no call left behind it is no voice.
    private static func dropEmptyVoices(_ db: Database) throws {
        try db.execute(
            sql: "DELETE FROM voice WHERE id NOT IN (SELECT voice_id FROM item_voice WHERE voice_id IS NOT NULL)")
    }

    private static func seal(_ embedding: [Float], key: SymmetricKey, itemID: String, speakerID: String) throws -> Data
    {
        let data = embedding.withUnsafeBufferPointer { Data(buffer: $0) }
        return try AES.GCM.seal(data, using: key, authenticating: Data("\(itemID)/\(speakerID)/voice".utf8))
            .combined!
    }

    private static func open(_ sealed: Data, key: SymmetricKey, itemID: String, speakerID: String) throws -> [Float] {
        let data = try AES.GCM.open(
            AES.GCM.SealedBox(combined: sealed), using: key, authenticating: Data("\(itemID)/\(speakerID)/voice".utf8))
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
