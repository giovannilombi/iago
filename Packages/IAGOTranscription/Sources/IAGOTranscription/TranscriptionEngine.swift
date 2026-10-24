import Foundation

/// Sample rate of all transcription inputs.
public let transcriptionSampleRate: Double = 16_000

public struct SpeechRegion: Equatable, Sendable {
    public var start: Double
    public var end: Double

    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }

    public var duration: Double { end - start }
}

/// A word with its own timing. `text` keeps its leading space, so joining words rebuilds the text.
public struct TranscribedWord: Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var text: String

    public init(start: Double, end: Double, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}

public struct TranscribedSegment: Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var text: String
    public var confidence: Float?
    /// Whisper's "no speech" probability; nil for engines that do not provide it.
    public var noSpeechProbability: Float?
    /// Word timings, used to split segments at speaker changes; empty for engines that do not provide them.
    public var words: [TranscribedWord]

    public init(
        start: Double, end: Double, text: String, confidence: Float? = nil, noSpeechProbability: Float? = nil,
        words: [TranscribedWord] = []
    ) {
        self.start = start
        self.end = end
        self.text = text
        self.confidence = confidence
        self.noSpeechProbability = noSpeechProbability
        self.words = words
    }

    /// Moves the segment and its words by `offset`, clamped to `limit`.
    func shifted(by offset: Double, limit: Double) -> TranscribedSegment {
        var copy = self
        copy.start = min(limit, offset + start)
        copy.end = min(limit, offset + end)
        copy.words = words.map {
            .init(start: min(limit, offset + $0.start), end: min(limit, offset + $0.end), text: $0.text)
        }
        return copy
    }
}

public struct TranscriptionOptions: Sendable {
    /// ISO 639-1 code; nil = automatic detection. Default: Italian forced (spec 7.1).
    public var language: String?
    /// Names and terms to spell right (project, client, people, the user's glossary). Whisper reads them as its
    /// initial prompt; Parakeet does not use them yet.
    public var vocabulary: [String]

    public init(language: String? = "it", vocabulary: [String] = []) {
        self.language = language
        self.vocabulary = vocabulary
    }

    /// The vocabulary as a short prompt: unique terms, at most about 200 characters (a long prompt makes Whisper
    /// repeat it in silent passages).
    public var vocabularyPrompt: String? {
        var seen: Set<String> = []
        var terms: [String] = []
        var length = 0
        for term in vocabulary.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !term.isEmpty {
            guard seen.insert(term.lowercased()).inserted, length + term.count <= 200 else { continue }
            terms.append(term)
            length += term.count + 2
        }
        return terms.isEmpty ? nil : terms.joined(separator: ", ") + "."
    }
}

/// Interchangeable ASR engine (ADR-0005). Input: 16 kHz mono samples. Output times are relative
/// to the start of `samples`.
public protocol TranscriptionEngine: Sendable {
    var asrName: String { get }
    var modelName: String { get }
    func transcribe(_ samples: [Float], options: TranscriptionOptions) async throws -> [TranscribedSegment]
}

public enum TranscriptionError: Error, Sendable, CustomStringConvertible {
    case modelNotFound(String)
    case engineFailure(String)
    case audio(String)

    public var description: String {
        switch self {
        case .modelNotFound(let path): "Model not found: \(path)"
        case .engineFailure(let message): "Engine failure: \(message)"
        case .audio(let message): "Audio error: \(message)"
        }
    }
}
