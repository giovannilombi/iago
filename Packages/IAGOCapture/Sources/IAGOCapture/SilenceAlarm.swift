import IAGOCore

/// FR-16: warn when one track stays silent for more than 30 s while the other has signal (a line in the menu), and,
/// within seconds, when no audio arrives from the microphone at all (the yellow dot, ADR-0093).
public enum SilenceAlarm {
    public static let window: Double = 30
    /// Seconds without any buffer from the microphone before it counts as absent.
    public static let absentWindow: Double = 2
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

    /// The microphone delivers nothing: no device, or no buffer for `absentWindow` seconds (unplugged, stopped).
    /// Silence is not absence: a listener who does not speak still delivers buffers.
    public static func micAbsent(now: Double, lastBuffer: Double?, hasDevice: Bool) -> Bool {
        guard now >= absentWindow else { return false }
        return !hasDevice || now - (lastBuffer ?? 0) > absentWindow
    }

    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sum / Float(samples.count)).squareRoot()
    }
}
