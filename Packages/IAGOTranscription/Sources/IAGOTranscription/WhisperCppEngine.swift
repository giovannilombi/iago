import Foundation
import whisper

/// whisper.cpp engine (default candidate, spec 7.1), Metal accelerated.
public final class WhisperCppEngine: TranscriptionEngine, @unchecked Sendable {
    public let asrName = "whisper.cpp"
    public let modelName: String
    private let context: OpaquePointer
    private let lock = NSLock()
    private let beamSize: Int32
    private let alignedWords: Bool

    /// `alignedWords` uses DTW on the alignment heads for word timings (more accurate, slower: flash
    /// attention is not available with DTW); otherwise word timings come from timestamp-token heuristics.
    public init(modelURL: URL, beamSize: Int = 5, alignedWords: Bool = false) throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw TranscriptionError.modelNotFound(modelURL.path)
        }
        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = !alignedWords
        if alignedWords {
            params.dtw_token_timestamps = true
            params.dtw_aheads_preset = WHISPER_AHEADS_LARGE_V3_TURBO
        }
        guard let context = whisper_init_from_file_with_params(modelURL.path, params) else {
            throw TranscriptionError.engineFailure("Cannot load \(modelURL.lastPathComponent)")
        }
        self.context = context
        self.beamSize = Int32(beamSize)
        self.alignedWords = alignedWords
        self.modelName = modelURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "ggml-", with: "")
    }

    deinit {
        whisper_free(context)
    }

    public func transcribe(_ samples: [Float], options: TranscriptionOptions) async throws -> [TranscribedSegment] {
        try lock.withLock { try run(samples, options: options) }
    }

    private func run(_ samples: [Float], options: TranscriptionOptions) throws -> [TranscribedSegment] {
        var params = whisper_full_default_params(beamSize > 1 ? WHISPER_SAMPLING_BEAM_SEARCH : WHISPER_SAMPLING_GREEDY)
        params.beam_search.beam_size = beamSize
        params.n_threads = Int32(min(8, ProcessInfo.processInfo.activeProcessorCount))
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_context = true  // chunks are independent: avoids repetition loops carried across chunks
        params.suppress_blank = true
        params.suppress_nst = true
        params.token_timestamps = true  // word timings, used to split segments at speaker changes

        let language = options.language ?? "auto"
        let prompt = options.vocabularyPrompt ?? ""
        let status = language.withCString { languagePointer in
            prompt.withCString { promptPointer in
                params.language = languagePointer
                params.detect_language = false
                // Names and terms the user works with: Whisper spells them as given.
                params.initial_prompt = prompt.isEmpty ? nil : promptPointer
                return samples.withUnsafeBufferPointer { buffer in
                    whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
                }
            }
        }
        guard status == 0 else { throw TranscriptionError.engineFailure("whisper_full returned \(status)") }

        return (0..<whisper_full_n_segments(context)).map { index in
            let tokens = whisper_full_n_tokens(context, index)
            let probabilities = (0..<tokens).map { whisper_full_get_token_p(context, index, $0) }
            return TranscribedSegment(
                start: Double(whisper_full_get_segment_t0(context, index)) / 100,
                end: Double(whisper_full_get_segment_t1(context, index)) / 100,
                text: String(cString: whisper_full_get_segment_text(context, index)).trimmingCharacters(
                    in: .whitespaces),
                confidence: probabilities.isEmpty ? nil : probabilities.reduce(0, +) / Float(probabilities.count),
                noSpeechProbability: whisper_full_get_segment_no_speech_prob(context, index),
                words: words(inSegment: index))
        }
    }

    /// Groups the segment's text tokens into words: a token starting with a space opens a new word.
    /// Bytes are collected per word because a token can hold part of a UTF-8 character.
    private func words(inSegment segment: Int32) -> [TranscribedWord] {
        let endOfText = whisper_token_eot(context)
        var words: [(start: Double, end: Double, bytes: [UInt8])] = []
        for token in 0..<whisper_full_n_tokens(context, segment) {
            let data = whisper_full_get_token_data(context, segment, token)
            guard data.id < endOfText, let cText = whisper_full_get_token_text(context, segment, token) else {
                continue
            }
            let bytes = Array(
                UnsafeBufferPointer(
                    start: UnsafeRawPointer(cText).assumingMemoryBound(to: UInt8.self), count: strlen(cText)))
            guard !bytes.isEmpty else { continue }
            // DTW gives one time per token (where it is spoken): it is used as the token start.
            let start = Double(alignedWords ? data.t_dtw : data.t0) / 100
            let end = alignedWords ? start : Double(data.t1) / 100
            if bytes.first == UInt8(ascii: " ") || words.isEmpty {
                words.append((start, end, bytes))
            } else {
                words[words.count - 1].end = max(words[words.count - 1].end, end)
                words[words.count - 1].bytes += bytes
            }
        }
        return words.map {
            TranscribedWord(
                start: $0.start, end: max($0.start, $0.end), text: String(decoding: $0.bytes, as: UTF8.self))
        }
    }
}
