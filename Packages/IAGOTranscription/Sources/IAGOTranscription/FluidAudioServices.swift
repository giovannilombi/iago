import FluidAudio
import Foundation

/// VAD and diarization via FluidAudio (ADR-0006).
public enum FluidAudioServices {
    /// When false (default for the app), FluidAudio refuses every network fetch (spec 4.2):
    /// models must already be in its cache. The benchmark enables downloads explicitly.
    public static func setDownloadsAllowed(_ allowed: Bool) {
        ModelHub.offlineMode = !allowed
    }

    public final class VoiceActivityDetector: @unchecked Sendable {
        private let manager: VadManager

        private init(manager: VadManager) { self.manager = manager }

        /// `base` holds `Models/silero-vad`; nil = FluidAudio's own cache (benchmark only).
        public static func load(from base: URL? = nil) async throws -> VoiceActivityDetector {
            if let base {
                return VoiceActivityDetector(manager: try await VadManager(config: .default, modelDirectory: base))
            }
            return VoiceActivityDetector(manager: try await VadManager(config: .default))
        }

        public func speechRegions(_ samples: [Float]) async throws -> [SpeechRegion] {
            try await manager.segmentSpeech(samples).map { SpeechRegion(start: $0.startTime, end: $0.endTime) }
        }
    }

    public final class Diarizer: @unchecked Sendable {
        private let manager: OfflineDiarizerManager

        private init(manager: OfflineDiarizerManager) { self.manager = manager }

        /// `base` holds `Models/speaker-diarization`; nil = FluidAudio's own cache (benchmark only).
        public static func load(from base: URL? = nil) async throws -> Diarizer {
            let manager = OfflineDiarizerManager(config: .default)
            try await manager.prepareModels(directory: base?.appendingPathComponent("Models", isDirectory: true))
            return Diarizer(manager: manager)
        }

        public func speakerTurns(_ samples: [Float]) async throws -> [TranscriptPostProcessing.SpeakerTurn] {
            try await manager.process(audio: samples).segments.map {
                .init(speaker: $0.speakerId, start: Double($0.startTimeSeconds), end: Double($0.endTimeSeconds))
            }
        }
    }
}
