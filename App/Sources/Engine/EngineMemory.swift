import Dispatch
import Foundation
import IAGOEngine
import MLX
import os

/// The memory side of the engine lane (ADR-0069):
/// - MLX keeps freed buffers for reuse, by default up to everything it may use: the cache gets a ceiling;
/// - when macOS reports memory pressure, MLX's cache is emptied and background work stops for a while (the chat
///   is not touched); under critical pressure the models are freed too.
/// The memory limit of MLX is left as it is: a lower one makes allocations wait, and a request could hang.
@MainActor
final class EngineMemory {
    private let lane: EngineLane
    private let freeModels: @MainActor () async -> Void
    private var source: DispatchSourceMemoryPressure?
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "engine")

    init(lane: EngineLane, freeModels: @escaping @MainActor () async -> Void) {
        self.lane = lane
        self.freeModels = freeModels
    }

    func start(ramGB: Int = EnginePolicy.ramGB) {
        Memory.cacheLimit = EnginePolicy.cacheLimitBytes(ramGB: ramGB)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            let event = source.data
            MainActor.assumeIsolated { self?.pressure(critical: event.contains(.critical)) }
        }
        source.resume()
        self.source = source
    }

    private func pressure(critical: Bool) {
        logger.notice(
            "Memory pressure (\(critical ? "critical" : "warning", privacy: .public)): background work paused")
        Memory.clearCache()
        let lane = lane
        Task {
            await lane.pauseBackground(for: .seconds(critical ? 300 : 90))
            if critical { await freeModels() }
        }
    }
}
