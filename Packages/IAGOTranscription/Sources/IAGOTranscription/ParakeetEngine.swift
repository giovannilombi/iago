import FluidAudio
import Foundation

/// Parakeet TDT engine via FluidAudio (alternative, spec 7.1), on the Neural Engine.
public final class ParakeetEngine: TranscriptionEngine, @unchecked Sendable {
    public enum Variant: String, Sendable {
        case v3
        case ultra

        var modelVersion: AsrModelVersion {
            switch self {
            case .v3: .v3
            case .ultra: .ultra
            }
        }
    }

    public let asrName = "parakeet"
    public let modelName: String
    private let manager: AsrManager

    private init(manager: AsrManager, modelName: String) {
        self.manager = manager
        self.modelName = modelName
    }

    /// Loads the models from `directory` (FluidAudio's cache when nil); downloads them only when
    /// `ModelHub.offlineMode` is off.
    public static func load(variant: Variant = .v3, directory: URL? = nil) async throws -> ParakeetEngine {
        let models = try await AsrModels.downloadAndLoad(to: directory, version: variant.modelVersion)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        return ParakeetEngine(manager: manager, modelName: "parakeet-tdt-\(variant.rawValue)")
    }

    public func transcribe(_ samples: [Float], options: TranscriptionOptions) async throws -> [TranscribedSegment] {
        var state = TdtDecoderState.make()
        let language = options.language.flatMap(Language.init(rawValue:))
        let result = try await manager.transcribe(samples, decoderState: &state, language: language)
        let tokens = (result.tokenTimings ?? []).map {
            ParakeetSegmenter.Token(text: $0.token, start: $0.startTime, end: $0.endTime, confidence: $0.confidence)
        }
        if tokens.isEmpty, !result.text.isEmpty {
            return [
                TranscribedSegment(start: 0, end: result.duration, text: result.text, confidence: result.confidence)
            ]
        }
        return ParakeetSegmenter.segments(from: tokens)
    }
}

/// Groups Parakeet token timings into segments: on sentence-ending punctuation, on pauses, or at a
/// maximum length.
public enum ParakeetSegmenter {
    public struct Token: Sendable {
        public var text: String
        public var start: Double
        public var end: Double
        public var confidence: Float

        public init(text: String, start: Double, end: Double, confidence: Float) {
            self.text = text
            self.start = start
            self.end = end
            self.confidence = confidence
        }
    }

    public static func segments(from tokens: [Token], pause: Double = 0.8, maxDuration: Double = 20)
        -> [TranscribedSegment]
    {
        var segments: [TranscribedSegment] = []
        var current: [Token] = []

        func flush() {
            guard let first = current.first, let last = current.last else { return }
            let text = current.map(\.text).joined().trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                let confidence = current.map(\.confidence).reduce(0, +) / Float(current.count)
                segments.append(
                    TranscribedSegment(start: first.start, end: last.end, text: text, confidence: confidence))
            }
            current.removeAll()
        }

        // A sentence ends at . ? ! only if the next token starts a new word: "512.000" stays together.
        var sentenceEnded = false
        for token in tokens {
            if let last = current.last, let first = current.first, token.text.hasPrefix(" ") {
                if sentenceEnded || token.start - last.end > pause || token.end - first.start > maxDuration {
                    flush()
                }
            }
            current.append(token)
            sentenceEnded = token.text.trimmingCharacters(in: .whitespaces).last.map { ".?!".contains($0) } ?? false
        }
        flush()
        return segments
    }
}
