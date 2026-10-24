import IAGOCore

/// FR-16: warn when one track stays silent for more than 30 s while the other has signal.
public enum SilenceAlarm {
    public static let window: Double = 30
    /// RMS above which a buffer counts as signal (about -50 dBFS).
    public static let signalThreshold: Float = 0.003

    /// - Parameters:
    ///   - now: current timeline position, seconds.
    ///   - lastSignal: timeline position of the last buffer with signal, per track.
    /// - Returns: the silent track, if the alarm should fire.
    public static func silentTrack(now: Double, lastSignal: [TrackKind: Double]) -> TrackKind? {
        guard now >= window else { return nil }
        let mic = lastSignal[.mic].map { now - $0 } ?? now
        let system = lastSignal[.system].map { now - $0 } ?? now
        if mic > window, system <= window { return .mic }
        if system > window, mic <= window { return .system }
        return nil
    }

    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sum / Float(samples.count)).squareRoot()
    }
}
