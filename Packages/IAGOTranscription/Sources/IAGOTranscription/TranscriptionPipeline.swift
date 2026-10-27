import Foundation
import IAGOCore

/// Transcription pipeline (spec 7.2). Receives audio files, returns a `Transcript`; knows nothing of
/// the database (spec 5.1).
public struct TranscriptionPipeline: Sendable {
    public enum Input: Sendable {
        /// A recording: mic track is "Io", only the system track is diarized. With `roomMode` ("più
        /// persone nella stanza", ADR-0031) the mic track is diarized too: its main voice is "Io".
        case recording(mic: URL, system: URL, roomMode: Bool = false)
        /// An imported file: one track, diarized as a whole.
        case imported(URL)
    }

    public struct Metrics: Sendable {
        public var audioDuration: Double = 0
        public var decode: Double = 0
        public var vad: Double = 0
        public var asr: Double = 0
        public var diarization: Double = 0
        public var droppedHallucinations = 0
        public var droppedEcho = 0

        public var total: Double { decode + vad + asr + diarization }
        /// Audio seconds processed per wall-clock second.
        public var speedFactor: Double { total > 0 ? audioDuration / total : 0 }
    }

    public struct Output: Sendable {
        public var transcript: Transcript
        public var metrics: Metrics
        /// The voices of the diarized speakers of the other side (or of an import), with their seconds of speech:
        /// what recognises them in later calls (ADR-0073). The user's own track has none.
        public var voices: [Voice] = []
    }

    public struct Voice: Sendable, Equatable {
        public var speakerID: String
        public var embedding: [Float]
        public var seconds: Double
    }

    public let engine: any TranscriptionEngine
    public let vad: FluidAudioServices.VoiceActivityDetector
    public let diarizer: FluidAudioServices.Diarizer?
    public var meLabel = "Io"
    /// Shortest speaker run kept when splitting segments at speaker changes (seconds).
    public var minSpeakerRun: Double = 1.5

    public init(
        engine: any TranscriptionEngine, vad: FluidAudioServices.VoiceActivityDetector,
        diarizer: FluidAudioServices.Diarizer?
    ) {
        self.engine = engine
        self.vad = vad
        self.diarizer = diarizer
    }

    /// `progress` receives 0…1, driven by the ASR chunks (the slow part).
    public func run(
        itemId: String, input: Input, options: TranscriptionOptions = .init(),
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Output {
        var metrics = Metrics()
        var speakers: [Transcript.Speaker] = []
        var labeled: [(speaker: String, segment: TranscribedSegment)] = []
        var voiceTrack: TrackResult?

        switch input {
        case .recording(let micURL, let systemURL, let roomMode):
            let mic = try await transcribeTrack(
                micURL, options: options, diarize: roomMode, metrics: &metrics, progress: scaled(progress, 0, 0.5))
            let system = try await transcribeTrack(
                systemURL, options: options, diarize: true, metrics: &metrics, progress: scaled(progress, 0.5, 1))
            let echo = TranscriptPostProcessing.removeEcho(mic: mic.segments, system: system.segments)
            metrics.droppedEcho = echo.dropped
            metrics.audioDuration = max(mic.duration, system.duration)
            voiceTrack = system
            speakers =
                [.me(label: meLabel)]
                + system.speakerIDs.enumerated().map { index, id in
                    Transcript.Speaker(id: id, label: "Speaker \(index + 1)", source: .system)
                }
            if roomMode {
                // Echo filter on the speaker-split mic segments (spec 7.2 step 7).
                let roomEcho = TranscriptPostProcessing.removeEcho(
                    mic: mic.labeled.map(\.segment), system: system.segments)
                metrics.droppedEcho = roomEcho.dropped
                let echoFree = mic.labeled.filter { entry in roomEcho.kept.contains(entry.segment) }
                let room = TranscriptPostProcessing.roomSpeakers(echoFree)
                speakers.insert(
                    contentsOf: room.others.enumerated().map { index, id in
                        Transcript.Speaker(id: id, label: "Stanza \(index + 2)", source: .mic)
                    }, at: 1)
                labeled = room.labeled + system.labeled
            } else {
                labeled = echo.kept.map { ("me", $0) } + system.labeled
            }
            if system.speakerIDs.isEmpty, !system.segments.isEmpty {
                speakers.append(.init(id: "s1", label: "Speaker 1", source: .system))
            }
        case .imported(let url):
            let track = try await transcribeTrack(
                url, options: options, diarize: true, metrics: &metrics, progress: progress)
            metrics.audioDuration = track.duration
            voiceTrack = track
            let ids = track.speakerIDs.isEmpty ? ["s1"] : track.speakerIDs
            speakers = ids.enumerated().map { Transcript.Speaker(id: $1, label: "Speaker \($0 + 1)", source: .import) }
            labeled = track.labeled
        }

        let segments = labeled.sorted { $0.segment.start < $1.segment.start }.enumerated().map { index, entry in
            Transcript.Segment(
                id: index + 1, speaker: entry.speaker, start: entry.segment.start, end: entry.segment.end,
                text: entry.segment.text, confidence: entry.segment.confidence.map(Double.init))
        }
        let transcript = Transcript(
            itemId: itemId,
            engine: .init(
                asr: engine.asrName, model: engine.modelName, diarization: diarizer == nil ? nil : "fluidaudio"),
            language: options.language, speakers: speakers, segments: segments)
        return Output(transcript: transcript, metrics: metrics, voices: voiceTrack.map(Self.voices) ?? [])
    }

    private static func voices(_ track: TrackResult) -> [Voice] {
        var seconds: [String: Double] = [:]
        for entry in track.labeled { seconds[entry.speaker, default: 0] += entry.segment.end - entry.segment.start }
        return track.voices.keys.sorted().compactMap { id in
            track.voices[id].map { Voice(speakerID: id, embedding: $0, seconds: seconds[id] ?? 0) }
        }
    }

    /// Voice note (FR-211, spec 7.7): one mic track, no diarization nor echo filter; the text of the segments.
    public func dictate(_ url: URL, options: TranscriptionOptions = .init()) async throws -> String {
        var metrics = Metrics()
        let track = try await transcribeTrack(url, options: options, diarize: false, metrics: &metrics)
        return track.segments.map { $0.text.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private struct TrackResult {
        var duration: Double
        var segments: [TranscribedSegment]
        /// Segments split at speaker changes, with their speaker.
        var labeled: [(speaker: String, segment: TranscribedSegment)]
        var speakerIDs: [String]
        /// Normalized speaker ID → embedding of its voice.
        var voices: [String: [Float]] = [:]
    }

    private func scaled(_ progress: (@Sendable (Double) -> Void)?, _ from: Double, _ to: Double) -> (
        @Sendable (Double) -> Void
    )? {
        guard let progress else { return nil }
        return { progress(from + (to - from) * $0) }
    }

    private func transcribeTrack(
        _ url: URL, options: TranscriptionOptions, diarize: Bool, metrics: inout Metrics,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> TrackResult {
        var clock = ContinuousClock.now
        func lap() -> Double {
            let now = ContinuousClock.now
            defer { clock = now }
            let elapsed = clock.duration(to: now)
            return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        }

        let samples = try AudioLoader.load16kMono(url)
        let duration = Double(samples.count) / transcriptionSampleRate
        metrics.decode += lap()

        let regions = try await vad.speechRegions(samples)
        metrics.vad += lap()

        var segments: [TranscribedSegment] = []
        let chunks = TranscriptPostProcessing.chunks(from: regions, totalDuration: duration)
        let speech = max(0.001, chunks.reduce(0) { $0 + $1.duration })
        var done = 0.0
        for chunk in chunks {
            try Task.checkCancellation()
            defer {
                done += chunk.duration
                progress?(0.95 * done / speech)
            }
            let start = Int(chunk.start * transcriptionSampleRate)
            let end = min(samples.count, Int(chunk.end * transcriptionSampleRate))
            guard end - start > Int(0.3 * transcriptionSampleRate) else { continue }
            let result = try await engine.transcribe(Array(samples[start..<end]), options: options)
            segments += result.map { $0.shifted(by: chunk.start, limit: chunk.end) }
        }
        let filtered = TranscriptPostProcessing.filterHallucinations(segments)
        metrics.droppedHallucinations += filtered.dropped
        metrics.asr += lap()

        guard diarize, let diarizer, !filtered.kept.isEmpty else {
            return TrackResult(
                duration: duration, segments: filtered.kept,
                labeled: TranscriptPostProcessing.joinSentences(filtered.kept.map { ("s1", $0) }), speakerIDs: [])
        }
        // Diarization can refuse short or quiet audio ("no speech detected"): the transcript is still
        // valid, with a single speaker.
        let turns: [TranscriptPostProcessing.SpeakerTurn]
        let voices: [String: [Float]]
        do {
            (turns, voices) = try await diarizer.speakers(samples)
        } catch {
            try Task.checkCancellation()
            (turns, voices) = ([], [:])
        }
        let normalized = TranscriptPostProcessing.normalizeSpeakerIDs(turns)
        metrics.diarization += lap()
        return TrackResult(
            duration: duration, segments: filtered.kept,
            labeled: TranscriptPostProcessing.joinSentences(
                TranscriptPostProcessing.splitBySpeaker(
                    filtered.kept, turns: normalized.turns, fallback: "s1", minRun: minSpeakerRun)),
            speakerIDs: normalized.ids, voices: TranscriptPostProcessing.normalizeVoices(voices, turns: turns))
    }
}

/// Plain-text rendering used by the benchmark (the full TXT/MD renderers live in IAGOExport, phase 1).
public enum TranscriptText {
    public static func lines(_ transcript: Transcript) -> [String] {
        let labels = Dictionary(uniqueKeysWithValues: transcript.speakers.map { ($0.id, $0.label) })
        return transcript.segments.map { "[\(timestamp($0.start))] \(labels[$0.speaker] ?? $0.speaker): \($0.text)" }
    }

    public static func timestamp(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
}
