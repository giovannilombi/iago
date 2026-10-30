import Accelerate
import Foundation
import IAGOCore
import IAGOStore

/// A piece of text ready to be embedded (spec 10.1): calls by turns of speech, 200-400 words with one turn of
/// overlap, with times and speakers; emails, documents and notes by paragraphs.
public struct ChunkDraft: Sendable, Equatable {
    public var text: String
    public var startSec: Double?
    public var endSec: Double?
    public var speakers: [String]

    public init(text: String, startSec: Double? = nil, endSec: Double? = nil, speakers: [String] = []) {
        self.text = text
        self.startSec = startSec
        self.endSec = endSec
        self.speakers = speakers
    }
}

public enum Chunker {
    static let minWords = 200
    static let maxWords = 400

    struct Turn {
        var speaker: String
        var start: Double
        var end: Double
        var text: String
        var words: Int { text.split(whereSeparator: \.isWhitespace).count }
    }

    /// A transcript in chunks; `labels` are the speaker names chosen by the user.
    public static func transcript(_ transcript: Transcript, labels: [String: String] = [:]) -> [ChunkDraft] {
        let names = Dictionary(uniqueKeysWithValues: transcript.speakers.map { ($0.id, $0.label) })
            .merging(labels) { $1 }
        // Consecutive segments of the same speaker are one turn; a very long turn is cut between sentences.
        var turns: [Turn] = []
        for segment in transcript.segments where !segment.text.trimmingCharacters(in: .whitespaces).isEmpty {
            let speaker = names[segment.speaker] ?? segment.speaker
            if var last = turns.last, last.speaker == speaker, last.words < maxWords {
                last.text += " " + segment.text
                last.end = segment.end
                turns[turns.count - 1] = last
            } else {
                turns.append(Turn(speaker: speaker, start: segment.start, end: segment.end, text: segment.text))
            }
        }
        var chunks: [ChunkDraft] = []
        var current: [Turn] = []
        func flush() {
            guard !current.isEmpty else { return }
            chunks.append(
                ChunkDraft(
                    text: current.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n"),
                    startSec: current.first?.start, endSec: current.last?.end,
                    speakers: current.map(\.speaker).reduce(into: []) { if !$0.contains($1) { $0.append($1) } }))
        }
        for turn in turns {
            let words = current.reduce(0) { $0 + $1.words }
            if words >= minWords, words + turn.words > maxWords {
                flush()
                // One turn of overlap keeps the context of an answer.
                current = current.last.map { [$0] } ?? []
            }
            current.append(turn)
        }
        flush()
        return chunks
    }

    /// Plain text or Markdown in chunks of paragraphs.
    public static func text(_ text: String) -> [ChunkDraft] {
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var chunks: [ChunkDraft] = []
        var current: [String] = []
        var words = 0
        for paragraph in paragraphs {
            let count = paragraph.split(whereSeparator: \.isWhitespace).count
            if words >= minWords || (words > 0 && words + count > maxWords) {
                chunks.append(ChunkDraft(text: current.joined(separator: "\n\n")))
                current = []
                words = 0
            }
            current.append(paragraph)
            words += count
        }
        if !current.isEmpty { chunks.append(ChunkDraft(text: current.joined(separator: "\n\n"))) }
        return chunks
    }
}

/// Embeds drafts in small batches and stores them as the chunks of an item or a note.
public enum SemanticIndexer {
    static let batch = 8

    public static func index(
        _ drafts: [ChunkDraft], itemID: String?, noteID: String?, source: Chunk.Source, archive: Archive,
        embedder: any TextEmbedder
    ) async throws {
        var chunks: [Chunk] = []
        for start in stride(from: 0, to: drafts.count, by: batch) {
            try Task.checkCancellation()
            let slice = Array(drafts[start..<min(start + batch, drafts.count)])
            let vectors = try await embedder.embed(slice.map(\.text), query: false)
            for (offset, (draft, vector)) in zip(slice, vectors).enumerated() {
                chunks.append(
                    Chunk(
                        id: "\(noteID ?? itemID ?? "x")#\(start + offset)", itemId: itemID, noteId: noteID,
                        source: source, startSec: draft.startSec, endSec: draft.endSec,
                        speakers: draft.speakers.isEmpty ? nil : draft.speakers.joined(separator: ", "),
                        text: draft.text, model: embedder.modelID, vector: VectorMath.normalized(vector)))
            }
        }
        try archive.replaceChunks(itemID: itemID, noteID: noteID, with: chunks)
    }
}

enum VectorMath {
    static func normalized(_ vector: [Float]) -> [Float] {
        var norm: Float = 0
        vDSP_svesq(vector, 1, &norm, vDSP_Length(vector.count))
        norm = norm.squareRoot()
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }

    /// Cosine of the query with every row of a row-major matrix of normalised vectors.
    static func scores(_ query: [Float], _ matrix: [Float], rows: Int) -> [Float] {
        guard rows > 0, !query.isEmpty else { return [] }
        var result = [Float](repeating: 0, count: rows)
        vDSP_mmul(matrix, 1, query, 1, &result, 1, vDSP_Length(rows), 1, vDSP_Length(query.count))
        return result
    }
}

/// The vectors of one scope, read once and kept until the index changes.
public final class VectorCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: (chunks: [Chunk], matrix: [Float], dimension: Int)] = [:]

    public init() {}

    public func invalidate() { lock.withLock { entries.removeAll() } }

    func load(_ scope: SearchScope, model: String, archive: Archive) throws -> (
        chunks: [Chunk], matrix: [Float], dimension: Int
    ) {
        let key = "\(model)|\(scope)"
        if let cached = lock.withLock({ entries[key] }) { return cached }
        let chunks = try archive.chunks(scope, model: model)
        let dimension = chunks.first?.values.count ?? 0
        var matrix: [Float] = []
        matrix.reserveCapacity(chunks.count * dimension)
        var kept: [Chunk] = []
        for chunk in chunks {
            let values = chunk.values
            guard values.count == dimension else { continue }
            matrix += values
            kept.append(chunk)
        }
        let entry = (kept, matrix, dimension)
        lock.withLock { entries[key] = entry }
        return entry
    }
}

/// Words and meaning together (spec 10.2): FTS5 ranks and cosine ranks merged with Reciprocal Rank Fusion. Filters
/// apply before the fusion; without an embedder it is the search by words.
public enum HybridSearch {
    static let rrfK = 60.0
    /// Below this cosine a passage is not about the question.
    static let minimumScore: Float = 0.45
    static let meaningLimit = 30

    public static func search(
        _ text: String, scope: SearchScope, sources: Set<SearchHit.Source> = [], archive: Archive,
        embedder: (any TextEmbedder)?, cache: VectorCache, limit: Int = 200
    ) async throws -> [SearchHit] {
        let words = try archive.search(text, scope: scope, sources: sources, limit: limit)
        guard let embedder, text.split(whereSeparator: \.isWhitespace).count >= 1,
            let query = try await embedder.embed([text], query: true).first
        else { return words }
        let loaded = try cache.load(scope, model: embedder.modelID, archive: archive)
        let normalized = VectorMath.normalized(query)
        guard loaded.dimension == normalized.count else { return words }
        let scores = VectorMath.scores(normalized, loaded.matrix, rows: loaded.chunks.count)
        let ranked = scores.enumerated().filter { $0.element >= minimumScore }
            .sorted { $0.element > $1.element }.prefix(meaningLimit)
            .map { loaded.chunks[$0.offset] }
            .filter { sources.isEmpty || sources.contains(source(of: $0)) }
        return fuse(
            words: words, meaning: ranked, chunksByItem: Dictionary(grouping: loaded.chunks) { $0.itemId ?? "" })
    }

    static func source(of chunk: Chunk) -> SearchHit.Source {
        switch chunk.source {
        case .transcript: .transcript
        case .note: .note
        case .email, .document: .document
        }
    }

    /// The passage a hit belongs to: the chunk that contains its minute, or the hit itself.
    static func key(_ hit: SearchHit, _ chunksByItem: [String: [Chunk]]) -> String {
        // The chunks are of the main transcript: a passage of the other one keeps its own key (ADR-0078).
        if hit.source == .transcript, hit.alternate == nil, let itemID = hit.itemID, let at = hit.atSec,
            let chunk = chunksByItem[itemID]?.first(where: { ($0.startSec ?? 0) <= at && at <= ($0.endSec ?? 0) })
        {
            return chunk.id
        }
        if hit.source == .note { return hit.sourceID }
        return "\(hit.source.rawValue)/\(hit.sourceID)/\(hit.atSec ?? -1)"
    }

    static func fuse(words: [SearchHit], meaning: [Chunk], chunksByItem: [String: [Chunk]]) -> [SearchHit] {
        var score: [String: Double] = [:]
        var hits: [String: SearchHit] = [:]
        var order: [String] = []
        for (rank, hit) in words.enumerated() {
            let key = key(hit, chunksByItem)
            score[key, default: 0] += 1 / (rrfK + Double(rank + 1))
            if hits[key] == nil {
                hits[key] = hit
                order.append(key)
            }
        }
        for (rank, chunk) in meaning.enumerated() {
            let key = chunk.noteId ?? chunk.id
            score[key, default: 0] += 1 / (rrfK + Double(rank + 1))
            if hits[key] == nil {
                hits[key] = SearchHit(
                    itemID: chunk.itemId, projectID: nil, source: source(of: chunk),
                    sourceID: chunk.noteId ?? chunk.itemId ?? chunk.id, atSec: chunk.startSec,
                    snippet: excerpt(chunk.text), byMeaning: true)
                order.append(key)
            }
        }
        return order.sorted { score[$0, default: 0] > score[$1, default: 0] }.compactMap { hits[$0] }
    }

    static func excerpt(_ text: String) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return flat.count > 220 ? String(flat.prefix(220)) + "…" : flat
    }
}
