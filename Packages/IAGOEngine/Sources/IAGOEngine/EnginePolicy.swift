import Foundation

/// How the local engine behaves on a Mac, by its memory (ADR-0069). On Apple Silicon the GPU shares the RAM: a model
/// of 6 GB, a transcription and the user's own apps must fit together. Kept apart from the generated catalog.
public enum EnginePolicy {
    /// From this much RAM the Mac has room for automatic work in the background and for a chat during a transcription.
    public static let roomyRAMGB = 32

    /// The RAM of this Mac in GB (16 GB Macs report exactly 16).
    public static var ramGB: Int { Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) }

    /// Automatic proposals and summaries when the user never chose: on only with room to spare. Below, they start
    /// from their buttons ("Cerca proposte", "Genera sintesi"), and the user can turn them on.
    public static func automaticWorkByDefault(ramGB: Int) -> Bool { ramGB >= roomyRAMGB }

    /// A chat answer may run while a transcription is in progress (the transcription cannot be paused).
    public static func chatDuringTranscription(ramGB: Int) -> Bool { ramGB >= roomyRAMGB }

    /// The model is freed as soon as the background work is done, instead of after 10 minutes idle.
    public static func freesModelAfterBackgroundWork(ramGB: Int) -> Bool { ramGB < roomyRAMGB }

    /// Memory MLX keeps for buffers it no longer uses (by default as much as it may use at all).
    public static func cacheLimitBytes(ramGB: Int) -> Int {
        (ramGB >= roomyRAMGB ? 1_024 : 256) * 1_048_576
    }

    /// RAM below which a model cannot work and is not offered: Gemma 4 12B needs ~12.4 GB, beyond what macOS gives
    /// the GPU on a 16 GB Mac (trial 2026-10-21).
    public static let minimumRAMGB: [String: Int] = ["gemma-4-12b": 24]

    public static func fits(_ model: EngineModel, ramGB: Int) -> Bool { ramGB >= (minimumRAMGB[model.id] ?? 0) }

    /// What to use when the active model does not fit this Mac: the biggest installed model that fits, if any.
    public static func replacement(
        for active: EngineModel, installed: [EngineModel], ramGB: Int
    ) -> EngineModel? {
        guard !fits(active, ramGB: ramGB) else { return nil }
        return installed.filter { $0.role == .chat && fits($0, ramGB: ramGB) }.max { $0.billions < $1.billions }
    }
}
